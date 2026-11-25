const assert = require('node:assert/strict');
const test = require('node:test');

const communicationsHandler = require('../../api/communications');
const integrationsHandler =
  require('../../api/integrations');
const { encryptSecrets, decryptSecrets } =
  require('../../api/_lib/integration_secrets');
const { isValidSignature } =
  require('../../api/webhooks/whatsapp');

const encryptionKey = Buffer.alloc(32, 7).toString('base64');

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

test('integration secrets are encrypted and bound to their workspace provider', () => {
  const env = { INTEGRATION_ENCRYPTION_KEY: encryptionKey };
  const secrets = { smtpUser: 'workspace-user', smtpPassword: 'top-secret' };
  const encrypted = encryptSecrets(secrets, 'owner:postal', env);

  assert.notEqual(encrypted.ciphertext.toString(), JSON.stringify(secrets));
  assert.deepEqual(
    decryptSecrets({
      secret_ciphertext: encrypted.ciphertext,
      secret_iv: encrypted.iv,
      secret_auth_tag: encrypted.authTag,
    }, 'owner:postal', env),
    secrets,
  );
  assert.throws(
    () => decryptSecrets({
      secret_ciphertext: encrypted.ciphertext,
      secret_iv: encrypted.iv,
      secret_auth_tag: encrypted.authTag,
    }, 'another-owner:postal', env),
    /could not be decrypted/,
  );
});

test('integration settings endpoint stores encrypted values without returning credentials', async () => {
  const statements = [];
  const handler = integrationsHandler.createIntegrationsHandler({
    authenticate: async () => ({ userId: 'owner-1' }),
    env: { INTEGRATION_ENCRYPTION_KEY: encryptionKey },
    withWorkspace: async (_userId, _workspaceId, operation) => operation({
      query: async (sql, parameters = []) => {
        statements.push({ sql, parameters });
        if (sql.includes('SELECT owner_user_id FROM workspaces')) {
          return {
            rowCount: 1,
            rows: [{ owner_user_id: 'owner-1' }],
          };
        }
        return { rowCount: 1, rows: [] };
      },
    }, { permissions: ['*'] }),
    logger: () => assert.fail('Unexpected integration error log.'),
  });
  const response = createResponse();

  await handler({
    method: 'PUT',
    headers: {
      'x-workspace-id': '00000000-0000-4000-8000-000000000002',
    },
    body: {
      provider: 'postal',
      workspaceName: 'Studio',
      settings: {
        smtpUser: 'workspace-user',
        smtpPassword: 'top-secret',
        fromAddress: 'studio@example.com',
        fromName: 'Studio',
      },
    },
  }, response);

  assert.equal(response.statusCode, 200);
  assert.deepEqual(response.body, {
    provider: 'postal',
    configured: true,
    accountHint: 'studio@example.com',
  });
  assert.equal(JSON.stringify(response.body).includes('top-secret'), false);
  const insert = statements.find(({ sql }) =>
    sql.includes('INSERT INTO workspace_integrations'));
  assert.ok(insert);
  const storedSecrets = decryptSecrets({
    secret_ciphertext: insert.parameters[5],
    secret_iv: insert.parameters[6],
    secret_auth_tag: insert.parameters[7],
  }, '00000000-0000-4000-8000-000000000002:postal', {
    INTEGRATION_ENCRYPTION_KEY: encryptionKey,
  });
  assert.equal(storedSecrets.smtpPassword, 'top-secret');
});

test('WhatsApp signature verification accepts only the matching raw-body HMAC', () => {
  const secret = 'meta-app-secret';
  const body = Buffer.from('{"object":"whatsapp_business_account"}');
  const signature = `sha256=${require('node:crypto')
    .createHmac('sha256', secret)
    .update(body)
    .digest('hex')}`;

  assert.equal(isValidSignature(body, signature, secret), true);
  assert.equal(isValidSignature(body, signature, 'wrong-secret'), false);
  assert.equal(isValidSignature(body, 'sha256=invalid', secret), false);
});

test('outbound API rejects malformed idempotency requests before database access', async () => {
  const handler = communicationsHandler.createCommunicationsHandler({
    authenticate: async () => ({ userId: 'owner-1' }),
    withTransaction: async () => {
      throw new Error('Malformed requests must not access the database.');
    },
    logger: () => assert.fail('Unexpected communications error log.'),
  });
  const response = createResponse();

  await handler({
    method: 'POST',
    headers: {
      'x-workspace-id': '00000000-0000-4000-8000-000000000002',
    },
    body: {
      revision: 1,
      message: {
        id: 'message-1',
        channel: 'Email',
        recipient: 'client@example.com',
        subject: 'Hello',
      },
    },
  }, response);

  assert.equal(response.statusCode, 400);
  assert.deepEqual(response.body, { error: 'invalid_outbound_message' });
});

test('outbound API returns an existing matching message without sending twice', async () => {
  const existing = {
    id: 'message-1',
    channel: 'Email',
    recipient: 'client@example.com',
    subject: 'Hello',
    body: 'Message body',
    status: 'Sent',
  };
  const handler = communicationsHandler.createCommunicationsHandler({
    authenticate: async () => ({ userId: 'owner-1' }),
    withWorkspace: async (_userId, _workspaceId, operation) =>
      operation({}, { permissions: ['*'] }),
    loadWorkspaceFn: async () => ({
      snapshot: { communications: [existing] },
      revision: 4,
    }),
    logger: () => assert.fail('Unexpected communications error log.'),
  });
  const response = createResponse();
  await handler({
    method: 'POST',
    headers: {
      'x-workspace-id': '00000000-0000-4000-8000-000000000002',
    },
    body: {
      revision: 3,
      message: { ...existing },
    },
  }, response);

  assert.equal(response.statusCode, 200);
  assert.equal(response.body.communication.id, 'message-1');
  assert.equal(response.body.communication.status, 'Sent');
  assert.equal(response.body.revision, 4);
});
