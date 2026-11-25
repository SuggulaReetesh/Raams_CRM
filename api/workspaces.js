const { randomUUID } = require('node:crypto');
const { authenticateRequest } = require('./_lib/auth');
const { withUserTransaction } = require('./_lib/database');
const { attachRequestId } = require('./_lib/request_id');
const {
  enforceUserRateLimit,
  respondToRateLimit,
} = require('./_lib/rate_limit');

const maximumRequestBytes = 4096;

class HttpError extends Error {
  constructor(statusCode, code) {
    super(code);
    this.name = 'HttpError';
    this.statusCode = statusCode;
    this.code = code;
  }
}

function isRecord(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function createWorkspacesHandler({
  authenticate = authenticateRequest,
  withTransaction = withUserTransaction,
  rateLimit = null,
  logger = console.error,
} = {}) {
  return async function workspacesHandler(req, res) {
    const requestId = attachRequestId(res);
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Vary', 'Authorization');
    if (!['GET', 'POST'].includes(req.method)) {
      res.setHeader('Allow', 'GET, POST');
      return res.status(405).json({ error: 'method_not_allowed' });
    }

    try {
      const { userId, profile } = await authenticate(req);
      if (rateLimit) {
        await rateLimit(
          userId,
          req.method === 'GET' ? 'workspaces_read' : 'workspaces_create',
          { limit: req.method === 'GET' ? 60 : 5, windowSeconds: 60 },
        );
      }

      if (req.method === 'GET') {
        const workspaces = await withTransaction(userId, async (client) => {
          const memberships = await client.query(
            `SELECT workspace_id, user_id, role_id, display_name, email
             FROM workspace_memberships
             WHERE user_id = $1 AND status = 'active'
             ORDER BY joined_at, workspace_id`,
            [userId],
          );
          const result = [];
          for (const membership of memberships.rows) {
            await client.query('SELECT set_config($1, $2, true)', [
              'app.workspace_id',
              membership.workspace_id,
            ]);
            const workspace = await client.query(
              `SELECT w.id, w.name, r.id AS role_id, r.name AS role_name,
                      r.scope AS role_scope, r.permission_keys
               FROM workspaces w
               JOIN workspace_roles r
                 ON r.workspace_id = w.id AND r.id = $2
               WHERE w.id = $1`,
              [membership.workspace_id, membership.role_id],
            );
            const projectRoles = await client.query(
              `SELECT r.permission_keys
               FROM workspace_project_memberships pm
               JOIN workspace_roles r
                 ON r.workspace_id = pm.workspace_id AND r.id = pm.role_id
               WHERE pm.workspace_id = $1 AND pm.user_id = $2
               ORDER BY pm.project_id`,
              [membership.workspace_id, userId],
            );
            if (workspace.rowCount !== 1) {
              throw new Error('Workspace membership has no valid role.');
            }
            result.push({
              id: workspace.rows[0].id,
              name: workspace.rows[0].name,
              userId: membership.user_id,
              role: {
                id: workspace.rows[0].role_id,
                name: workspace.rows[0].role_name,
                scope: workspace.rows[0].role_scope,
                permissions: workspace.rows[0].permission_keys,
              },
              projectPermissions: projectRoles.rows.map(
                (row) => row.permission_keys,
              ),
              displayName: membership.display_name,
              email: membership.email,
            });
          }
          return result;
        });
        return res.status(200).json({ workspaces });
      }

      if (!isRecord(req.body) ||
          Buffer.byteLength(JSON.stringify(req.body)) > maximumRequestBytes ||
          typeof req.body.name !== 'string' ||
          req.body.name.trim().length < 1 ||
          req.body.name.trim().length > 80) {
        throw new HttpError(400, 'invalid_workspace_name');
      }

      const workspaceId = randomUUID();
      const workspace = await withTransaction(userId, async (client) => {
        await client.query('SELECT set_config($1, $2, true)', [
          'app.workspace_id',
          workspaceId,
        ]);
        await client.query(
          `INSERT INTO workspaces (id, owner_user_id, name)
           VALUES ($1, $2, $3)`,
          [workspaceId, userId, req.body.name.trim()],
        );
        const role = await client.query(
          `INSERT INTO workspace_roles
             (workspace_id, scope, name, permission_keys, is_system, created_by)
           VALUES ($1, 'organization', 'Owner', ARRAY['*']::text[], true, $2)
           RETURNING id`,
          [workspaceId, userId],
        );
        await client.query(
          `INSERT INTO workspace_memberships
             (workspace_id, user_id, role_id, display_name, email)
           VALUES ($1, $2, $3, $4, $5)`,
          [
            workspaceId,
            userId,
            role.rows[0].id,
            profile.displayName,
            profile.email,
          ],
        );
        await client.query(
          `INSERT INTO workspace_owner_profiles
             (workspace_id, owner_user_id, display_name, email)
           VALUES ($1, $2, $3, $4)`,
          [workspaceId, userId, profile.displayName, profile.email],
        );
        return {
          id: workspaceId,
          name: req.body.name.trim(),
          userId,
          role: {
            id: role.rows[0].id,
            name: 'Owner',
            scope: 'organization',
            permissions: ['*'],
          },
          projectPermissions: [],
        };
      });
      return res.status(201).json({ workspace });
    } catch (error) {
      if (respondToRateLimit(error, res)) return;
      if (error instanceof HttpError ||
          (Number.isInteger(error?.statusCode) && error.statusCode === 401)) {
        return res.status(error.statusCode).json({
          error: error instanceof HttpError ? error.code : 'unauthorized',
        });
      }
      logger('Workspace selection request failed.', {
        requestId,
        errorName: error instanceof Error ? error.name : 'UnknownError',
        ...(typeof error?.code === 'string' ? { errorCode: error.code } : {}),
      });
      return res.status(500).json({ error: 'internal_server_error' });
    }
  };
}

const handler = createWorkspacesHandler({
  rateLimit: enforceUserRateLimit,
});
Object.assign(handler, { createWorkspacesHandler });
module.exports = handler;
