const { Pool } = require('pg');
const { getDatabaseUrl } = require('./config');

let pool;
const workspaceIdPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

class WorkspaceAccessError extends Error {
  constructor(statusCode = 403, code = 'workspace_access_denied') {
    super(code);
    this.name = 'WorkspaceAccessError';
    this.statusCode = statusCode;
    this.code = code;
  }
}

function getPool(env = process.env) {
  if (!pool) {
    const databaseUrl = getDatabaseUrl(env);
    const databaseHost = new URL(databaseUrl).hostname.toLowerCase();
    const isLocalHost = ['localhost', '127.0.0.1', '[::1]'].includes(
      databaseHost,
    );
    pool = new Pool({
      connectionString: databaseUrl,
      connectionTimeoutMillis: 10000,
      idleTimeoutMillis: 10000,
      max: 5,
      ssl: env.APP_ENV === 'development' && isLocalHost
        ? false
        : { rejectUnauthorized: true },
    });
    pool.on('error', (error) => {
      console.error('Unexpected idle database client error.', {
        errorName: error.name,
        ...(typeof error.code === 'string' ? { errorCode: error.code } : {}),
      });
    });
  }
  return pool;
}

async function withUserTransaction(userId, operation, poolFactory = getPool) {
  const client = await poolFactory().connect();
  try {
    await client.query('BEGIN');
    await client.query('SELECT set_config($1, $2, true)', [
      'app.user_id',
      userId,
    ]);
    const result = await operation(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch (rollbackError) {
      throw new AggregateError(
        [error, rollbackError],
        'Database operation failed and could not be rolled back.',
      );
    }
    throw error;
  } finally {
    client.release();
  }
}

async function withWorkspaceTransaction(
  userId,
  workspaceId,
  operation,
  poolFactory = getPool,
) {
  if (typeof workspaceId !== 'string' ||
      !workspaceIdPattern.test(workspaceId)) {
    throw new WorkspaceAccessError(400, 'invalid_workspace_id');
  }
  const client = await poolFactory().connect();
  try {
    await client.query('BEGIN');
    await client.query('SELECT set_config($1, $2, true)', [
      'app.user_id',
      userId,
    ]);
    const membership = await client.query(
      `SELECT role_id
       FROM workspace_memberships
       WHERE workspace_id = $1 AND user_id = $2 AND status = 'active'`,
      [workspaceId, userId],
    );
    if (membership.rowCount !== 1) {
      throw new WorkspaceAccessError();
    }
    await client.query('SELECT set_config($1, $2, true)', [
      'app.workspace_id',
      workspaceId,
    ]);
    const roleResult = await client.query(
      `SELECT permission_keys
       FROM workspace_roles
       WHERE workspace_id = $1 AND id = $2 AND scope = 'organization'`,
      [workspaceId, membership.rows[0].role_id],
    );
    if (roleResult.rowCount !== 1) {
      throw new WorkspaceAccessError();
    }
    const projectRoles = await client.query(
      `SELECT pm.project_id, r.permission_keys
       FROM workspace_project_memberships pm
       JOIN workspace_roles r
         ON r.workspace_id = pm.workspace_id AND r.id = pm.role_id
       WHERE pm.workspace_id = $1 AND pm.user_id = $2
         AND r.scope = 'project' AND r.project_id = pm.project_id`,
      [workspaceId, userId],
    );
    const context = {
      workspaceId,
      roleId: membership.rows[0].role_id,
      permissions: roleResult.rows[0].permission_keys,
      projectPermissions: new Map(
        projectRoles.rows.map((row) => [row.project_id, row.permission_keys]),
      ),
    };
    const result = await operation(client, context);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch (rollbackError) {
      throw new AggregateError(
        [error, rollbackError],
        'Database operation failed and could not be rolled back.',
      );
    }
    throw error;
  } finally {
    client.release();
  }
}

function hasPermission(context, permission) {
  return context.permissions.includes('*') ||
    context.permissions.includes(permission);
}

function requirePermission(context, permission) {
  if (!hasPermission(context, permission)) {
    throw new WorkspaceAccessError(403, 'permission_denied');
  }
}

module.exports = {
  WorkspaceAccessError,
  getPool,
  hasPermission,
  requirePermission,
  withUserTransaction,
  withWorkspaceTransaction,
};
