const assert = require('node:assert/strict');
const test = require('node:test');

const health = require('../../api/health');
const { getDatabaseUrl, getRuntimeEnvironment } = require('../../api/_lib/config');
const {
  enforceUserRateLimit,
  RateLimitError,
  respondToRateLimit,
} = require('../../api/_lib/rate_limit');
const { attachRequestId } = require('../../api/_lib/request_id');
const { createReadinessHandler } = require('../../api/ready');
const { validateMigrationNames } = require('../../scripts/check-migrations');

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

test('health endpoint only permits GET and does not cache the response', () => {
  const response = createResponse();
  health({ method: 'POST' }, response);
  assert.equal(response.statusCode, 405);
  assert.equal(response.headers.Allow, 'GET');
  assert.equal(response.headers['Cache-Control'], 'no-store');
});

test('request IDs are generated and returned as response headers', () => {
  const firstResponse = createResponse();
  const secondResponse = createResponse();
  const firstId = attachRequestId(firstResponse);
  const secondId = attachRequestId(secondResponse);

  assert.match(firstId, /^[0-9a-f-]{36}$/);
  assert.equal(firstResponse.headers['X-Request-Id'], firstId);
  assert.notEqual(firstId, secondId);
});

test('authenticated API rate limits reject excess requests with retry guidance', async () => {
  const statements = [];
  const withTransaction = async (_userId, operation) => operation({
    async query(statement) {
      statements.push(statement);
      if (statement.includes('INSERT INTO api_rate_limit_windows')) {
        return {
          rows: [{ request_count: 4, retry_after_seconds: 18 }],
        };
      }
      return { rows: [] };
    },
  });
  const response = createResponse();

  await assert.rejects(
    enforceUserRateLimit(
      'owner-id',
      'workspace_write',
      { limit: 3, windowSeconds: 60 },
      withTransaction,
    ),
    RateLimitError,
  );
  const error = new RateLimitError(18);

  assert.equal(statements.length, 2);
  assert.equal(respondToRateLimit(error, response), true);
  assert.equal(response.statusCode, 429);
  assert.equal(response.headers['Retry-After'], '18');
  assert.deepEqual(response.body, { error: 'rate_limit_exceeded' });
});

test('health endpoint reports the deployment environment without secrets', () => {
  const originalAppEnv = process.env.APP_ENV;
  const originalVercelEnv = process.env.VERCEL_ENV;
  process.env.APP_ENV = 'staging';
  delete process.env.VERCEL_ENV;
  try {
    const response = createResponse();
    health({ method: 'GET' }, response);
    assert.equal(response.statusCode, 200);
    assert.deepEqual(response.body, {
      status: 'ok',
      environment: 'staging',
    });
  } finally {
    if (originalAppEnv === undefined) delete process.env.APP_ENV;
    else process.env.APP_ENV = originalAppEnv;
    if (originalVercelEnv === undefined) delete process.env.VERCEL_ENV;
    else process.env.VERCEL_ENV = originalVercelEnv;
  }
});

test('preview deployments map to the staging environment', () => {
  assert.equal(getRuntimeEnvironment({ VERCEL_ENV: 'preview' }), 'staging');
});

test('database configuration rejects missing and non-PostgreSQL URLs', () => {
  assert.throws(() => getDatabaseUrl({}), /DATABASE_URL is not configured/);
  assert.throws(
    () => getDatabaseUrl({ DATABASE_URL: 'https://example.test' }),
    /valid PostgreSQL connection URL/,
  );
  assert.equal(
    getDatabaseUrl({
      DATABASE_URL: 'postgresql://crm:password@db.example.test/crm?sslmode=require',
    }),
    'postgresql://crm:password@db.example.test/crm?sslmode=require',
  );
});

test('unsupported deployment environments fail explicitly', () => {
  assert.throws(
    () => getRuntimeEnvironment({ APP_ENV: 'test' }),
    /Unsupported APP_ENV/,
  );
});

test('readiness endpoint reports database failures and logs the cause', async () => {
  let logged = false;
  const handler = createReadinessHandler(
    async () => {
      throw new Error('connection refused');
    },
    () => {
      logged = true;
    },
  );
  const response = createResponse();

  await handler({ method: 'GET' }, response);

  assert.equal(response.statusCode, 503);
  assert.deepEqual(response.body, {
    status: 'not_ready',
    database: 'unavailable',
  });
  assert.equal(logged, true);
});

test('readiness endpoint returns success only after the database probe succeeds', async () => {
  const handler = createReadinessHandler(async () => {});
  const response = createResponse();

  await handler({ method: 'GET' }, response);

  assert.equal(response.statusCode, 200);
  assert.deepEqual(response.body, {
    status: 'ready',
    database: 'connected',
  });
});

test('migration filenames must be sequential and descriptive', () => {
  assert.deepEqual(
    validateMigrationNames([
      '0002_add_projects.sql',
      'README.md',
      '0001_create_workspaces.sql',
    ]),
    ['0001_create_workspaces.sql', '0002_add_projects.sql'],
  );
  assert.throws(
    () => validateMigrationNames(['0001_create_workspaces.sql', '0003_gap.sql']),
    /next version prefix 0002_/,
  );
});
