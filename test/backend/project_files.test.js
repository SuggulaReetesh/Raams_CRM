const assert = require('node:assert/strict');
const test = require('node:test');

const projectFilesHandler = require('../../api/project-files');

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

test('project file upload URLs require project membership and file permission', async () => {
  let providerCalled = false;
  const handler = projectFilesHandler.createProjectFilesHandler({
    authenticate: async () => ({ userId: 'member-1' }),
    withWorkspace: async (_userId, _workspaceId, operation) =>
      operation({
        query: async () => ({
          rowCount: 1,
          rows: [{ id: 'project-1' }],
        }),
      }, {
        permissions: [],
        projectPermissions: new Map([['project-1', ['manageFiles']]]),
      }),
    rateLimit: null,
    env: {
      SUPABASE_URL: 'https://project.supabase.co',
      SUPABASE_SERVICE_ROLE_KEY: 'server-only-key',
    },
    providerFetch: async (url, options) => {
      providerCalled = true;
      assert.equal(
        new URL(url).pathname,
        '/storage/v1/object/upload/sign/project-files/' +
          '00000000-0000-4000-8000-000000000002/project-1/asset-1',
      );
      assert.equal(options.headers.Authorization, 'Bearer server-only-key');
      return new Response('{"token":"signed-token"}', { status: 200 });
    },
  });
  const response = createResponse();

  await handler({
    method: 'POST',
    headers: {
      'x-workspace-id': '00000000-0000-4000-8000-000000000002',
    },
    body: {
      action: 'create_upload',
      projectId: 'project-1',
      assetId: 'asset-1',
      mimeType: 'image/png',
    },
  }, response);

  assert.equal(response.statusCode, 200);
  assert.equal(providerCalled, true);
  assert.equal(
    response.body.storagePath,
    '00000000-0000-4000-8000-000000000002/project-1/asset-1',
  );
  assert.match(response.body.uploadUrl, /token=signed-token/);
});

test('project file API rejects unauthorized projects before contacting storage', async () => {
  let providerCalled = false;
  const handler = projectFilesHandler.createProjectFilesHandler({
    authenticate: async () => ({ userId: 'member-1' }),
    withWorkspace: async (_userId, _workspaceId, operation) =>
      operation({ query: async () => ({ rowCount: 1, rows: [{}] }) }, {
        permissions: [],
        projectPermissions: new Map(),
      }),
    rateLimit: null,
    env: {
      SUPABASE_URL: 'https://project.supabase.co',
      SUPABASE_SERVICE_ROLE_KEY: 'server-only-key',
    },
    providerFetch: async () => {
      providerCalled = true;
      return new Response('{}', { status: 200 });
    },
  });
  const response = createResponse();

  await handler({
    method: 'POST',
    headers: {
      'x-workspace-id': '00000000-0000-4000-8000-000000000002',
    },
    body: {
      action: 'create_upload',
      projectId: 'project-1',
      assetId: 'asset-1',
      mimeType: 'image/png',
    },
  }, response);

  assert.equal(response.statusCode, 403);
  assert.deepEqual(response.body, { error: 'permission_denied' });
  assert.equal(providerCalled, false);
});
