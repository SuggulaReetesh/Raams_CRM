const assert = require('node:assert/strict');
const test = require('node:test');

const workspacesHandler = require('../../api/workspaces');

function createResponse() {
  return {
    headers: {},
    statusCode: null,
    body: null,
    setHeader(name, value) {
      this.headers[name] = value;
    },
    status(statusCode) {
      this.statusCode = statusCode;
      return this;
    },
    json(body) {
      this.body = body;
      return this;
    },
  };
}

test('workspace selection returns active organizations and project permissions', async () => {
  const handler = workspacesHandler.createWorkspacesHandler({
    authenticate: async () => ({ userId: 'member-1' }),
    withTransaction: async (_userId, operation) => operation({
      query: async (sql) => {
        if (sql.includes('SELECT workspace_id, user_id, role_id')) {
          return {
            rows: [{
              workspace_id: 'workspace-1',
              user_id: 'member-1',
              role_id: 'role-1',
              display_name: 'Member',
              email: 'member@example.test',
            }],
          };
        }
        if (sql.includes('SELECT w.id, w.name')) {
          return {
            rowCount: 1,
            rows: [{
              id: 'workspace-1',
              name: 'Build Co',
              role_id: 'role-1',
              role_name: 'Project manager',
              role_scope: 'organization',
              permission_keys: ['workspace.read'],
            }],
          };
        }
        return { rows: [{ permission_keys: ['manageTasks'] }] };
      },
    }),
  });
  const response = createResponse();

  await handler({ method: 'GET' }, response);

  assert.equal(response.statusCode, 200);
  assert.deepEqual(response.body.workspaces[0], {
    id: 'workspace-1',
    name: 'Build Co',
    userId: 'member-1',
    role: {
      id: 'role-1',
      name: 'Project manager',
      scope: 'organization',
      permissions: ['workspace.read'],
    },
    projectPermissions: [['manageTasks']],
    displayName: 'Member',
    email: 'member@example.test',
  });
});

test('workspace creation initializes an owner membership and role', async () => {
  const statements = [];
  const handler = workspacesHandler.createWorkspacesHandler({
    authenticate: async () => ({
      userId: 'owner-1',
      profile: { displayName: 'Owner', email: 'owner@example.test' },
    }),
    withTransaction: async (_userId, operation) => operation({
      query: async (sql, values) => {
        statements.push({ sql, values });
        return sql.includes('RETURNING id')
          ? { rows: [{ id: 'owner-role-1' }] }
          : { rows: [] };
      },
    }),
  });
  const response = createResponse();

  await handler(
    { method: 'POST', body: { name: 'Build Co' } },
    response,
  );

  assert.equal(response.statusCode, 201);
  assert.equal(response.body.workspace.name, 'Build Co');
  assert.equal(response.body.workspace.userId, 'owner-1');
  assert.deepEqual(response.body.workspace.role.permissions, ['*']);
  assert.equal(statements.filter(({ sql }) =>
    sql.includes('INSERT INTO workspaces')).length, 1);
  assert.equal(statements.filter(({ sql }) =>
    sql.includes('INSERT INTO workspace_memberships')).length, 1);
});
