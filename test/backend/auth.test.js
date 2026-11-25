const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');

const { authenticateRequest } = require('../../api/_lib/auth');

test('Supabase authentication verifies signature, issuer, audience, and subject', async () => {
  const { exportJWK, generateKeyPair, SignJWT } = await import('jose');
  const { privateKey, publicKey } = await generateKeyPair('ES256');
  const jwk = await exportJWK(publicKey);
  jwk.kid = 'test-key';
  jwk.alg = 'ES256';
  jwk.use = 'sig';

  const server = http.createServer((request, response) => {
    if (request.url === '/auth/v1/.well-known/jwks.json') {
      response.writeHead(200, { 'Content-Type': 'application/json' });
      response.end(JSON.stringify({ keys: [jwk] }));
      return;
    }
    response.writeHead(404);
    response.end();
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const address = server.address();
  const supabaseUrl = `http://127.0.0.1:${address.port}`;
  const issuer = `${supabaseUrl}/auth/v1`;
  const userId = '00000000-0000-4000-8000-000000000001';
  const token = (tokenIssuer = issuer) =>
    new SignJWT({})
      .setProtectedHeader({ alg: 'ES256', kid: 'test-key' })
      .setSubject(userId)
      .setIssuer(tokenIssuer)
      .setAudience('authenticated')
      .setExpirationTime('1h')
      .sign(privateKey);

  try {
    const request = {
      headers: { authorization: `Bearer ${await token()}` },
    };
    const result = await authenticateRequest(request, {
      APP_ENV: 'development',
      SUPABASE_URL: supabaseUrl,
    });
    assert.deepEqual(result, {
      userId,
      email: null,
      emailVerified: false,
      profile: { displayName: 'Studio owner', email: null },
    });

    await assert.rejects(
      authenticateRequest({
        headers: { authorization: `Bearer ${await token('https://wrong.test')}` },
      }, {
        APP_ENV: 'development',
        SUPABASE_URL: supabaseUrl,
      }),
      { statusCode: 401 },
    );
  } finally {
    await new Promise((resolve, reject) =>
      server.close((error) => error ? reject(error) : resolve()),
    );
  }
});
