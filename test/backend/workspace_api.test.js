const assert = require('node:assert/strict');
const test = require('node:test');

const workspaceHandler = require('../../api/workspace');
const { getSupabaseUrl } = require('../../api/_lib/auth');
const { RateLimitError } = require('../../api/_lib/rate_limit');
const {
  flattenSnapshot,
  unflattenSnapshot,
  validateSnapshot,
} = workspaceHandler;

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

function sampleSnapshot() {
  return {
    schemaVersion: 4,
    customers: [{ id: 'customer-1', name: 'Client' }],
    pipelineStages: ['Inquiry', 'Discovery'],
    activities: [],
    personas: [],
    preferences: { studioName: 'Studio' },
    delivery: {
      projects: [{ id: 'project-1' }],
      tasks: [],
      milestones: [],
      punchItems: [],
      assets: [],
      workLogs: [],
      attendance: [],
      approvals: [],
    },
    financials: {
      quotations: [],
      templates: [],
      proposals: [],
      invoices: [],
      settings: { currencySymbol: '$' },
    },
    communications: [],
  };
}

test('Supabase URL accepts HTTPS origins and local development HTTP only', () => {
  assert.equal(
    getSupabaseUrl({ SUPABASE_URL: 'https://project.supabase.co/' }),
    'https://project.supabase.co',
  );
  assert.equal(
    getSupabaseUrl({
      APP_ENV: 'development',
      SUPABASE_URL: 'http://localhost:54321',
    }),
    'http://localhost:54321',
  );
  assert.throws(
    () => getSupabaseUrl({ SUPABASE_URL: 'http://project.example' }),
    /HTTPS/,
  );
});

test('workspace record serialization keeps stages ordered and collections separate', () => {
  const snapshot = sampleSnapshot();
  const records = flattenSnapshot(snapshot);
  const restored = unflattenSnapshot(
    {
      preferences: snapshot.preferences,
      financialSettings: snapshot.financials.settings,
    },
    records.map(({ collection, data }) => ({ collection, data })),
  );

  assert.deepEqual(restored, snapshot);
});

test('workspace validation rejects duplicate record IDs and invalid stages', () => {
  const duplicate = sampleSnapshot();
  duplicate.customers.push({ id: 'customer-1' });
  assert.throws(() => validateSnapshot(duplicate), /duplicate_customers_id/);

  const invalidStage = sampleSnapshot();
  invalidStage.pipelineStages[0] = ' ';
  assert.throws(() => validateSnapshot(invalidStage), /invalid_pipeline_stages/);
});

test('workspace API requires authorization and returns no-store responses', async () => {
  const handler = workspaceHandler.createWorkspaceHandler({
    authenticate: async () => {
      const error = new Error('unauthorized');
      error.statusCode = 401;
      throw error;
    },
  });
  const response = createResponse();

  await handler({ method: 'GET' }, response);

  assert.equal(response.statusCode, 401);
  assert.deepEqual(response.body, { error: 'unauthorized' });
  assert.equal(response.headers['Cache-Control'], 'no-store');
});

test('workspace API rejects requests over the authenticated owner limit', async () => {
  const handler = workspaceHandler.createWorkspaceHandler({
    authenticate: async () => ({
      userId: '00000000-0000-4000-8000-000000000001',
    }),
    rateLimit: async () => {
      throw new RateLimitError(30);
    },
  });
  const response = createResponse();

  await handler({ method: 'GET' }, response);

  assert.equal(response.statusCode, 429);
  assert.equal(response.headers['Retry-After'], '30');
  assert.deepEqual(response.body, { error: 'rate_limit_exceeded' });
});

test('workspace API rejects stale or malformed revisions before database access', async () => {
  const handler = workspaceHandler.createWorkspaceHandler({
    authenticate: async () => ({ userId: '00000000-0000-4000-8000-000000000001' }),
    withTransaction: async () => {
      throw new Error('must not access database');
    },
  });
  const response = createResponse();

  await handler(
    { method: 'PUT', body: { revision: -1, snapshot: sampleSnapshot() } },
    response,
  );

  assert.equal(response.statusCode, 400);
  assert.deepEqual(response.body, { error: 'invalid_workspace_revision' });
});
