const assert = require('node:assert/strict');
const test = require('node:test');

const accessHandler = require('../../api/workspace-access');

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

test('workspace access API creates custom organization roles for role managers', async () => {
  const statements = [];
  const handler = accessHandler.createWorkspaceAccessHandler({
    authenticate: async () => ({ userId: 'owner-1' }),
    withWorkspace: async (_userId, _workspaceId, operation) =>
      operation({
        query: async (sql, values) => {
          statements.push({ sql, values });
          return {
            rowCount: 1,
            rows: [{
              id: 'role-1',
              scope: 'organization',
              projectId: null,
              name: 'Project team',
              permissions: ['viewProjects'],
            }],
          };
        },
      }, { permissions: ['roles.manage', 'viewProjects'] }),
  });
  const response = createResponse();

  await handler({
    method: 'POST',
    headers: {
      'x-workspace-id': '00000000-0000-4000-8000-000000000002',
    },
    body: {
      action: 'create_role',
      scope: 'organization',
      name: 'Project team',
      permissions: ['viewProjects'],
    },
  }, response);

  assert.equal(response.statusCode, 200);
  assert.equal(response.body.role.id, 'role-1');
  assert.deepEqual(statements[0].values[3], 'Project team');
  assert.deepEqual(statements[0].values[4], ['viewProjects']);
});

test('workspace role managers cannot grant permissions they do not have', async () => {
  let queried = false;
  const handler = accessHandler.createWorkspaceAccessHandler({
    authenticate: async () => ({ userId: 'role-manager-1' }),
    withWorkspace: async (_userId, _workspaceId, operation) =>
      operation({
        query: async () => {
          queried = true;
          return { rowCount: 1, rows: [] };
        },
      }, { permissions: ['roles.manage'], projectPermissions: new Map() }),
  });
  const response = createResponse();

  await handler({
    method: 'POST',
    headers: {
      'x-workspace-id': '00000000-0000-4000-8000-000000000002',
    },
    body: {
      action: 'create_role',
      scope: 'organization',
      name: 'Finance administrator',
      permissions: ['manageFinancials'],
    },
  }, response);

  assert.equal(response.statusCode, 403);
  assert.deepEqual(response.body, { error: 'permission_denied' });
  assert.equal(queried, false);
});

test('workspace access API denies role creation without roles.manage', async () => {
  let queried = false;
  const handler = accessHandler.createWorkspaceAccessHandler({
    authenticate: async () => ({ userId: 'member-1' }),
    withWorkspace: async (_userId, _workspaceId, operation) =>
      operation({
        query: async () => {
          queried = true;
          return { rowCount: 1, rows: [] };
        },
      }, { permissions: ['members.view'] }),
  });
  const response = createResponse();

  await handler({
    method: 'POST',
    headers: {
      'x-workspace-id': '00000000-0000-4000-8000-000000000002',
    },
    body: {
      action: 'create_role',
      scope: 'organization',
      name: 'Unauthorized',
      permissions: ['viewProjects'],
    },
  }, response);

  assert.equal(response.statusCode, 403);
  assert.deepEqual(response.body, { error: 'permission_denied' });
  assert.equal(queried, false);
});

test('project task assignee lookup is limited to accessible project members', async () => {
  const statements = [];
  const handler = accessHandler.createWorkspaceAccessHandler({
    authenticate: async () => ({ userId: 'member-1' }),
    withWorkspace: async (_userId, _workspaceId, operation) =>
      operation({
        query: async (sql, values) => {
          statements.push({ sql, values });
          return { rows: [{ name: 'Site lead (12345678)' }] };
        },
      }, {
        permissions: [],
        projectPermissions: new Map([['project-1', ['manageTasks']]]),
      }),
  });
  const response = createResponse();

  await handler({
    method: 'GET',
    url: '/api/workspace-access?projectId=project-1',
    headers: {
      'x-workspace-id': '00000000-0000-4000-8000-000000000002',
    },
  }, response);

  assert.equal(response.statusCode, 200);
  assert.deepEqual(response.body, {
    assignees: ['Site lead (12345678)'],
  });
  assert.deepEqual(statements[0].values, [
    '00000000-0000-4000-8000-000000000002',
    'project-1',
  ]);
});

test('project task assignee lookup rejects inaccessible projects', async () => {
  let queried = false;
  const handler = accessHandler.createWorkspaceAccessHandler({
    authenticate: async () => ({ userId: 'member-1' }),
    withWorkspace: async (_userId, _workspaceId, operation) =>
      operation({
        query: async () => {
          queried = true;
          return { rows: [] };
        },
      }, { permissions: [], projectPermissions: new Map() }),
  });
  const response = createResponse();

  await handler({
    method: 'GET',
    url: '/api/workspace-access?projectId=project-1',
    headers: {
      'x-workspace-id': '00000000-0000-4000-8000-000000000002',
    },
  }, response);

  assert.equal(response.statusCode, 403);
  assert.deepEqual(response.body, { error: 'permission_denied' });
  assert.equal(queried, false);
});

test('workspace access API rejects unverified invitation acceptance', async () => {
  let accessedDatabase = false;
  const handler = accessHandler.createWorkspaceAccessHandler({
    authenticate: async () => ({
      userId: 'member-1',
      emailVerified: false,
      profile: { email: 'member@example.test' },
    }),
    withTransaction: async () => {
      accessedDatabase = true;
      return null;
    },
  });
  const response = createResponse();

  await handler({
    method: 'POST',
    headers: {},
    body: {
      action: 'accept_invitation',
      invitationId: '00000000-0000-4000-8000-000000000002',
    },
  }, response);

  assert.equal(response.statusCode, 403);
  assert.deepEqual(response.body, {
    error: 'verified_invitation_email_required',
  });
  assert.equal(accessedDatabase, false);
});
