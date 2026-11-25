const { authenticateRequest, getSupabaseUrl } = require('./_lib/auth');
const {
  hasPermission,
  requirePermission,
  WorkspaceAccessError,
  withUserTransaction,
  withWorkspaceTransaction,
} = require('./_lib/database');
const { getWorkspaceId } = require('./_lib/workspace_context');
const { attachRequestId } = require('./_lib/request_id');

const permissionKeys = new Set([
  'workspace.read',
  'members.view',
  'members.manage',
  'roles.view',
  'roles.manage',
  'projects.view',
  'projects.manage',
  'manageClients',
  'managePipeline',
  'manageRequirements',
  'viewFinancials',
  'configureWorkspace',
  'viewProjects',
  'manageProjects',
  'manageTasks',
  'manageFiles',
  'viewFiles',
  'manageMilestones',
  'managePunchList',
  'viewWorkLogs',
  'manageWorkLogs',
  'manageAttendance',
  'manageApprovals',
  'approveApprovals',
  'manageFinancials',
  'viewCommunications',
  'manageCommunications',
  'procurement.view',
  'procurement.manage',
  'procurement.approve',
  'inventory.view',
  'inventory.manage',
  'finance.view',
  'finance.manage',
  'documents.view',
  'documents.manage',
  'reports.view',
]);
const projectPermissionKeys = new Set([
  'projects.view',
  'projects.manage',
  'viewFinancials',
  'viewProjects',
  'manageProjects',
  'manageTasks',
  'manageFiles',
  'viewFiles',
  'manageMilestones',
  'managePunchList',
  'viewWorkLogs',
  'manageWorkLogs',
  'manageAttendance',
  'manageApprovals',
  'approveApprovals',
  'manageFinancials',
  'viewCommunications',
  'manageCommunications',
  'procurement.view',
  'procurement.manage',
  'procurement.approve',
  'inventory.view',
  'inventory.manage',
  'finance.view',
  'finance.manage',
  'documents.view',
  'documents.manage',
  'reports.view',
]);
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

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

function validatePermissions(value) {
  if (!Array.isArray(value) ||
      value.some((permission) =>
        typeof permission !== 'string' || !permissionKeys.has(permission)) ||
      new Set(value).size !== value.length) {
    throw new HttpError(400, 'invalid_role_permissions');
  }
  return value;
}

async function sendInvitationEmail(email, env) {
  const serviceKey = env.SUPABASE_SERVICE_ROLE_KEY;
  if (typeof serviceKey !== 'string' || serviceKey.trim().length === 0) {
    throw new HttpError(503, 'invitation_service_not_configured');
  }
  const supabaseUrl = getSupabaseUrl(env);
  const redirectUrl = env.SUPABASE_INVITE_REDIRECT_URL?.trim();
  if (!redirectUrl) {
    throw new HttpError(503, 'invitation_redirect_not_configured');
  }
  let parsedRedirect;
  try {
    parsedRedirect = new URL(redirectUrl);
  } catch {
    throw new HttpError(503, 'invitation_redirect_not_configured');
  }
  if (!['https:', 'raamscrm:'].includes(parsedRedirect.protocol)) {
    throw new HttpError(503, 'invitation_redirect_not_configured');
  }
  let response;
  try {
    const url = new URL('/auth/v1/invite', supabaseUrl);
    url.searchParams.set('redirect_to', redirectUrl);
    response = await fetch(url, {
      method: 'POST',
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ email }),
      signal: AbortSignal.timeout(10000),
    });
  } catch {
    throw new HttpError(502, 'invitation_email_failed');
  }
  if (response.ok) return;

  let providerError;
  try {
    providerError = await response.json();
  } catch {
    providerError = null;
  }
  const message = [
    providerError?.code,
    providerError?.error_code,
    providerError?.msg,
    providerError?.message,
  ].filter((value) => typeof value === 'string').join(' ').toLowerCase();
  if (!/(already|exists|registered)/.test(message)) {
    throw new HttpError(502, 'invitation_email_failed');
  }

  let otpResponse;
  try {
    const url = new URL('/auth/v1/otp', supabaseUrl);
    url.searchParams.set('redirect_to', redirectUrl);
    otpResponse = await fetch(url, {
      method: 'POST',
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ email, create_user: false }),
      signal: AbortSignal.timeout(10000),
    });
  } catch {
    throw new HttpError(502, 'invitation_email_failed');
  }
  if (!otpResponse.ok) {
    throw new HttpError(502, 'invitation_email_failed');
  }
}

function createWorkspaceAccessHandler({
  authenticate = authenticateRequest,
  withTransaction = withUserTransaction,
  withWorkspace = withWorkspaceTransaction,
  env = process.env,
  logger = console.error,
} = {}) {
  return async function workspaceAccessHandler(req, res) {
    const requestId = attachRequestId(res);
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Vary', 'Authorization');
    if (!['GET', 'POST'].includes(req.method)) {
      res.setHeader('Allow', 'GET, POST');
      return res.status(405).json({ error: 'method_not_allowed' });
    }

    try {
      const user = await authenticate(req);
      if (req.method === 'GET' && !req.headers?.['x-workspace-id']) {
        return await listPendingInvitations(user, withTransaction, res);
      }
      if (req.method === 'POST' &&
          req.body?.action === 'accept_invitation') {
        return await acceptInvitation(
          user,
          req.body,
          withTransaction,
          res,
        );
      }

      const workspaceId = getWorkspaceId(req);
      if (req.method === 'GET') {
        const requestUrl = new URL(req.url || '/', 'http://localhost');
        const projectId = req.query?.projectId ??
          requestUrl.searchParams.get('projectId');
        if (projectId !== null && projectId !== undefined) {
          if (typeof projectId !== 'string' ||
              projectId.trim().length === 0 ||
              projectId.length > 160) {
            throw new HttpError(400, 'invalid_project');
          }
          const assignees = await withWorkspace(
            user.userId,
            workspaceId,
            async (client, access) => {
              const organizationCanViewProjects = [
                'workspace.read',
                'viewProjects',
                'manageProjects',
                'manageTasks',
                'projects.view',
                'projects.manage',
              ].some((permission) => hasPermission(access, permission));
              const projectPermissions = access.projectPermissions ??
                new Map();
              if (!organizationCanViewProjects &&
                  !projectPermissions.has(projectId)) {
                throw new WorkspaceAccessError(403, 'permission_denied');
              }
              const result = await client.query(
                `SELECT
                   COALESCE(NULLIF(btrim(m.display_name), ''),
                            'Workspace member') || ' (' ||
                     left(m.user_id::text, 8) || ')' AS name
                 FROM workspace_project_memberships pm
                 JOIN workspace_memberships m
                   ON m.workspace_id = pm.workspace_id
                  AND m.user_id = pm.user_id
                 WHERE pm.workspace_id = $1 AND pm.project_id = $2
                   AND m.status = 'active'
                 ORDER BY lower(m.display_name), m.user_id`,
                [workspaceId, projectId],
              );
              return result.rows.map((row) => row.name);
            },
          );
          return res.status(200).json({ assignees });
        }
        const data = await withWorkspace(
          user.userId,
          workspaceId,
          async (client, access) => {
            if (!hasPermission(access, 'members.view') &&
                !hasPermission(access, 'members.manage') &&
                !hasPermission(access, 'roles.view') &&
                !hasPermission(access, 'roles.manage')) {
              throw new WorkspaceAccessError(403, 'permission_denied');
            }
            const [members, roles, invitations, projectMemberships] =
              await Promise.all([
                client.query(
                  `SELECT m.user_id AS id, m.display_name AS "displayName",
                          m.email, m.status, m.joined_at AS "joinedAt",
                          r.id AS "roleId", r.name AS "roleName",
                          r.permission_keys AS permissions
                   FROM workspace_memberships m
                   JOIN workspace_roles r
                     ON r.workspace_id = m.workspace_id AND r.id = m.role_id
                   WHERE m.workspace_id = $1
                   ORDER BY m.joined_at, lower(m.email)`,
                  [workspaceId],
                ),
                client.query(
                  `SELECT id, scope, project_id AS "projectId", name,
                          permission_keys AS permissions, is_system AS "isSystem"
                   FROM workspace_roles
                   WHERE workspace_id = $1
                   ORDER BY scope, lower(name)`,
                  [workspaceId],
                ),
                hasPermission(access, 'members.manage')
                  ? client.query(
                      `SELECT id, email, role_id AS "roleId", status,
                              expires_at AS "expiresAt", created_at AS "createdAt"
                       FROM workspace_invitations
                       WHERE workspace_id = $1
                       ORDER BY created_at DESC`,
                      [workspaceId],
                    )
                  : Promise.resolve({ rows: [] }),
                client.query(
                  `SELECT pm.project_id AS "projectId", pm.user_id AS "userId",
                          r.id AS "roleId", r.name AS "roleName"
                   FROM workspace_project_memberships pm
                   JOIN workspace_roles r
                     ON r.workspace_id = pm.workspace_id AND r.id = pm.role_id
                   WHERE pm.workspace_id = $1
                   ORDER BY pm.project_id, pm.user_id`,
                  [workspaceId],
                ),
              ]);
            return {
              members: members.rows,
              roles: roles.rows,
              invitations: invitations.rows,
              projectMemberships: projectMemberships.rows,
            };
          },
        );
        return res.status(200).json(data);
      }

      if (!isRecord(req.body) ||
          Buffer.byteLength(JSON.stringify(req.body)) > 8192) {
        throw new HttpError(400, 'invalid_workspace_access_request');
      }
      if (req.body.action === 'invite_member') {
        const invitation = await withWorkspace(
          user.userId,
          workspaceId,
          async (client, access) => {
            requirePermission(access, 'members.manage');
            const email = typeof req.body.email === 'string'
              ? req.body.email.trim().toLowerCase()
              : '';
            if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) ||
                email.length > 320 ||
                !uuidPattern.test(req.body.roleId || '')) {
              throw new HttpError(400, 'invalid_invitation');
            }
            const role = await client.query(
              `SELECT id, permission_keys FROM workspace_roles
               WHERE workspace_id = $1 AND id = $2
                 AND scope = 'organization'`,
              [workspaceId, req.body.roleId],
            );
            if (role.rowCount !== 1) {
              throw new HttpError(400, 'invalid_invitation_role');
            }
            assertCanGrantPermissions(access, role.rows[0].permission_keys);
            const member = await client.query(
              `SELECT 1 FROM workspace_memberships
               WHERE workspace_id = $1 AND lower(email) = $2`,
              [workspaceId, email],
            );
            if (member.rowCount > 0) {
              throw new HttpError(409, 'member_already_exists');
            }
            const result = await client.query(
              `INSERT INTO workspace_invitations
                 (workspace_id, email, role_id, invited_by)
               VALUES ($1, $2, $3, $4)
               ON CONFLICT (workspace_id, lower(email))
                 WHERE status = 'pending'
               DO UPDATE SET role_id = EXCLUDED.role_id,
                 invited_by = EXCLUDED.invited_by,
                 expires_at = now() + interval '7 days',
                 created_at = now()
               RETURNING id, email`,
              [workspaceId, email, req.body.roleId, user.userId],
            );
            return result.rows[0];
          },
        );
        try {
          await sendInvitationEmail(invitation.email, env);
        } catch (error) {
          await withWorkspace(user.userId, workspaceId, async (client) => {
            await client.query(
              `UPDATE workspace_invitations SET status = 'revoked'
               WHERE workspace_id = $1 AND id = $2 AND status = 'pending'`,
              [workspaceId, invitation.id],
            );
          });
          throw error;
        }
        return res.status(201).json({
          invitation: { id: invitation.id, email: invitation.email },
        });
      }

      const result = await withWorkspace(
        user.userId,
        workspaceId,
        async (client, access) => {
          switch (req.body.action) {
            case 'create_role': {
              requirePermission(access, 'roles.manage');
              return createRole(
                client,
                workspaceId,
                user.userId,
                req.body,
                access,
              );
            }
            case 'update_role': {
              requirePermission(access, 'roles.manage');
              return updateRole(client, workspaceId, req.body, access);
            }
            case 'assign_member_role': {
              requirePermission(access, 'members.manage');
              return assignMemberRole(client, workspaceId, req.body, access);
            }
            case 'assign_project_role': {
              requirePermission(access, 'members.manage');
              return assignProjectRole(client, workspaceId, req.body, access);
            }
            case 'remove_member': {
              requirePermission(access, 'members.manage');
              return removeMember(client, workspaceId, req.body);
            }
            case 'set_member_status': {
              requirePermission(access, 'members.manage');
              return setMemberStatus(client, workspaceId, req.body);
            }
            case 'revoke_invitation': {
              requirePermission(access, 'members.manage');
              return revokeInvitation(client, workspaceId, req.body);
            }
            default:
              throw new HttpError(400, 'invalid_workspace_access_action');
          }
        },
      );
      return res.status(200).json(result);
    } catch (error) {
      if (error instanceof HttpError ||
          error instanceof WorkspaceAccessError ||
          (Number.isInteger(error?.statusCode) && error.statusCode === 401)) {
        return res.status(error.statusCode).json({
          error: error instanceof HttpError ||
              error instanceof WorkspaceAccessError
            ? error.code
            : 'unauthorized',
        });
      }
      logger('Workspace access request failed.', {
        requestId,
        errorName: error instanceof Error ? error.name : 'UnknownError',
        ...(typeof error?.code === 'string' ? { errorCode: error.code } : {}),
      });
      return res.status(500).json({ error: 'internal_server_error' });
    }
  };
}

async function createRole(client, workspaceId, userId, request, access) {
  const scope = request.scope;
  const projectId = request.projectId ?? null;
  const name = typeof request.name === 'string' ? request.name.trim() : '';
  const permissions = validatePermissions(request.permissions);
  if (!['organization', 'project'].includes(scope) ||
      name.length < 1 || name.length > 80 ||
      (scope === 'organization' && projectId !== null) ||
      (scope === 'project' &&
        (typeof projectId !== 'string' || projectId.length > 160))) {
    throw new HttpError(400, 'invalid_role');
  }
  if (scope === 'project' &&
      permissions.some((permission) => !projectPermissionKeys.has(permission))) {
    throw new HttpError(400, 'invalid_role_permissions');
  }
  assertCanGrantPermissions(
    access,
    permissions,
    scope === 'project' ? projectId : null,
  );
  const result = await client.query(
    `INSERT INTO workspace_roles
       (workspace_id, scope, project_id, name, permission_keys, created_by)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING id, scope, project_id AS "projectId", name,
               permission_keys AS permissions`,
    [workspaceId, scope, projectId, name, permissions, userId],
  );
  return { role: result.rows[0] };
}

async function updateRole(client, workspaceId, request, access) {
  if (!uuidPattern.test(request.roleId || '')) {
    throw new HttpError(400, 'invalid_role');
  }
  const name = typeof request.name === 'string' ? request.name.trim() : '';
  const permissions = validatePermissions(request.permissions);
  if (name.length < 1 || name.length > 80) {
    throw new HttpError(400, 'invalid_role');
  }
  const existing = await client.query(
    `SELECT scope, project_id AS "projectId"
     FROM workspace_roles
     WHERE workspace_id = $1 AND id = $2 AND is_system = false`,
    [workspaceId, request.roleId],
  );
  if (existing.rowCount !== 1) throw new HttpError(404, 'role_not_found');
  if (existing.rows[0].scope === 'project' &&
      permissions.some((permission) => !projectPermissionKeys.has(permission))) {
    throw new HttpError(400, 'invalid_role_permissions');
  }
  assertCanGrantPermissions(
    access,
    permissions,
    existing.rows[0].scope === 'project'
      ? existing.rows[0].projectId
      : null,
  );
  const result = await client.query(
    `UPDATE workspace_roles
     SET name = $3, permission_keys = $4
     WHERE workspace_id = $1 AND id = $2 AND is_system = false
     RETURNING id, scope, project_id AS "projectId", name,
               permission_keys AS permissions`,
    [workspaceId, request.roleId, name, permissions],
  );
  if (result.rowCount !== 1) throw new HttpError(404, 'role_not_found');
  return { role: result.rows[0] };
}

async function assignMemberRole(client, workspaceId, request, access) {
  if (!uuidPattern.test(request.userId || '') ||
      !uuidPattern.test(request.roleId || '')) {
    throw new HttpError(400, 'invalid_member_role');
  }
  const owner = await client.query(
    'SELECT owner_user_id FROM workspaces WHERE id = $1',
    [workspaceId],
  );
  if (owner.rows[0]?.owner_user_id === request.userId) {
    throw new HttpError(409, 'cannot_change_owner_role');
  }
  const result = await client.query(
    `UPDATE workspace_memberships m
     SET role_id = r.id, updated_at = now()
     FROM workspace_roles r
     WHERE m.workspace_id = $1 AND m.user_id = $2
       AND r.workspace_id = m.workspace_id AND r.id = $3
       AND r.scope = 'organization'
     RETURNING m.user_id, r.permission_keys`,
    [workspaceId, request.userId, request.roleId],
  );
  if (result.rowCount !== 1) throw new HttpError(404, 'member_or_role_not_found');
  assertCanGrantPermissions(access, result.rows[0].permission_keys);
  return { assigned: true };
}

async function assignProjectRole(client, workspaceId, request, access) {
  if (!uuidPattern.test(request.userId || '') ||
      !uuidPattern.test(request.roleId || '') ||
      typeof request.projectId !== 'string' ||
      request.projectId.length > 160) {
    throw new HttpError(400, 'invalid_project_role_assignment');
  }
  const result = await client.query(
    `INSERT INTO workspace_project_memberships
       (workspace_id, project_id, user_id, role_id)
     SELECT $1, $2, m.user_id, r.id
     FROM workspace_memberships m
     JOIN workspace_roles r
       ON r.workspace_id = m.workspace_id AND r.id = $4
     WHERE m.workspace_id = $1 AND m.user_id = $3 AND m.status = 'active'
       AND r.scope = 'project' AND r.project_id = $2
     ON CONFLICT (workspace_id, project_id, user_id)
     DO UPDATE SET role_id = EXCLUDED.role_id
     RETURNING user_id`,
    [workspaceId, request.projectId, request.userId, request.roleId],
  );
  if (result.rowCount !== 1) {
    throw new HttpError(404, 'member_project_or_role_not_found');
  }
  const role = await client.query(
    `SELECT permission_keys FROM workspace_roles
     WHERE workspace_id = $1 AND id = $2 AND scope = 'project'
       AND project_id = $3`,
    [workspaceId, request.roleId, request.projectId],
  );
  if (role.rowCount !== 1) {
    throw new HttpError(404, 'member_project_or_role_not_found');
  }
  assertCanGrantPermissions(access, role.rows[0].permission_keys, request.projectId);
  return { assigned: true };
}

function assertCanGrantPermissions(access, permissions, projectId = null) {
  if (access.permissions.includes('*')) return;
  const projectPermissions = projectId
    ? access.projectPermissions.get(projectId) || []
    : [];
  if (permissions.some((permission) =>
    !access.permissions.includes(permission) &&
    !projectPermissions.includes(permission))) {
    throw new WorkspaceAccessError(403, 'permission_denied');
  }
}

async function removeMember(client, workspaceId, request) {
  if (!uuidPattern.test(request.userId || '')) {
    throw new HttpError(400, 'invalid_member');
  }
  const owner = await client.query(
    'SELECT owner_user_id FROM workspaces WHERE id = $1',
    [workspaceId],
  );
  if (owner.rows[0]?.owner_user_id === request.userId) {
    throw new HttpError(409, 'cannot_remove_workspace_owner');
  }
  const result = await client.query(
    `DELETE FROM workspace_memberships
     WHERE workspace_id = $1 AND user_id = $2
     RETURNING user_id`,
    [workspaceId, request.userId],
  );
  if (result.rowCount !== 1) throw new HttpError(404, 'member_not_found');
  return { removed: true };
}

async function setMemberStatus(client, workspaceId, request) {
  if (!uuidPattern.test(request.userId || '') ||
      !['active', 'suspended'].includes(request.status)) {
    throw new HttpError(400, 'invalid_member_status');
  }
  const owner = await client.query(
    'SELECT owner_user_id FROM workspaces WHERE id = $1',
    [workspaceId],
  );
  if (owner.rows[0]?.owner_user_id === request.userId &&
      request.status !== 'active') {
    throw new HttpError(409, 'cannot_suspend_workspace_owner');
  }
  const result = await client.query(
    `UPDATE workspace_memberships
     SET status = $3, updated_at = now()
     WHERE workspace_id = $1 AND user_id = $2
     RETURNING user_id`,
    [workspaceId, request.userId, request.status],
  );
  if (result.rowCount !== 1) throw new HttpError(404, 'member_not_found');
  return { status: request.status };
}

async function revokeInvitation(client, workspaceId, request) {
  if (!uuidPattern.test(request.invitationId || '')) {
    throw new HttpError(400, 'invalid_invitation');
  }
  const result = await client.query(
    `UPDATE workspace_invitations
     SET status = 'revoked'
     WHERE workspace_id = $1 AND id = $2 AND status = 'pending'
     RETURNING id`,
    [workspaceId, request.invitationId],
  );
  if (result.rowCount !== 1) throw new HttpError(404, 'invitation_not_found');
  return { revoked: true };
}

async function listPendingInvitations(user, withTransaction, res) {
  const invitations = await withTransaction(user.userId, async (client) => {
    if (!user.emailVerified || !user.profile.email) return [];
    await client.query('SELECT set_config($1, $2, true)', [
      'app.user_email',
      user.profile.email,
    ]);
    const pending = await client.query(
      `SELECT id, workspace_id FROM workspace_invitations
       WHERE lower(email) = lower($1) AND status = 'pending'
         AND expires_at > now()
       ORDER BY created_at`,
      [user.profile.email],
    );
    const result = [];
    for (const invitation of pending.rows) {
      await client.query('SELECT set_config($1, $2, true)', [
        'app.workspace_id',
        invitation.workspace_id,
      ]);
      const workspace = await client.query(
        `SELECT w.name, i.email, r.name AS role_name
         FROM workspace_invitations i
         JOIN workspaces w ON w.id = i.workspace_id
         JOIN workspace_roles r
           ON r.workspace_id = i.workspace_id AND r.id = i.role_id
         WHERE i.id = $1`,
        [invitation.id],
      );
      if (workspace.rowCount === 1) {
        result.push({
          id: invitation.id,
          workspaceId: invitation.workspace_id,
          workspaceName: workspace.rows[0].name,
          email: workspace.rows[0].email,
          roleName: workspace.rows[0].role_name,
        });
      }
    }
    return result;
  });
  return res.status(200).json({ invitations });
}

async function acceptInvitation(user, request, withTransaction, res) {
  if (!isRecord(request) ||
      !uuidPattern.test(request.invitationId || '') ||
      !user.emailVerified ||
      !user.profile.email) {
    throw new HttpError(403, 'verified_invitation_email_required');
  }
  const membership = await withTransaction(user.userId, async (client) => {
    await client.query('SELECT set_config($1, $2, true)', [
      'app.user_email',
      user.profile.email,
    ]);
    const invitation = await client.query(
      `SELECT id, workspace_id, role_id, email
       FROM workspace_invitations
       WHERE id = $1 AND lower(email) = lower($2)
         AND status = 'pending' AND expires_at > now()
       FOR UPDATE`,
      [request.invitationId, user.profile.email],
    );
    if (invitation.rowCount !== 1) {
      throw new HttpError(404, 'invitation_not_found');
    }
    const pending = invitation.rows[0];
    await client.query('SELECT set_config($1, $2, true)', [
      'app.workspace_id',
      pending.workspace_id,
    ]);
    await client.query(
      `INSERT INTO workspace_memberships
         (workspace_id, user_id, role_id, display_name, email)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (workspace_id, user_id) DO UPDATE SET
         role_id = EXCLUDED.role_id,
         status = 'active',
         display_name = EXCLUDED.display_name,
         email = EXCLUDED.email,
         joined_at = now(),
         updated_at = now()`,
      [
        pending.workspace_id,
        user.userId,
        pending.role_id,
        user.profile.displayName,
        user.profile.email,
      ],
    );
    await client.query(
      `UPDATE workspace_invitations
       SET status = 'accepted', accepted_at = now()
       WHERE id = $1`,
      [pending.id],
    );
    return {
      workspaceId: pending.workspace_id,
      email: pending.email,
    };
  });
  return res.status(200).json({ accepted: true, membership });
}

const handler = createWorkspaceAccessHandler();
Object.assign(handler, {
  createWorkspaceAccessHandler,
  validatePermissions,
});
module.exports = handler;
