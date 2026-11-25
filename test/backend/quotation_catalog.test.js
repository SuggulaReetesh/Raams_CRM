const assert = require('node:assert/strict');
const test = require('node:test');
const {
  createQuotationCatalogHandler,
  upsertRecord,
  validateRecord,
} = require('../../api/quotation-catalog');

function mockResponse() {
  return {
    statusCode: 200,
    headers: {},
    body: null,
    setHeader(name, value) {
      this.headers[name] = value;
    },
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(body) {
      this.body = body;
      return this;
    },
  };
}

test('quotation catalog validates package records', () => {
  const packageRecord = validateRecord('packages', {
    id: 'basic',
    code: 'basic',
    name: 'Basic',
    description: 'Essential interior package',
  });
  assert.equal(packageRecord.code, 'BASIC');
  assert.equal(packageRecord.active, true);
  assert.equal(packageRecord.version, 1);
  assert.throws(
    () => validateRecord('packages', { id: '', code: '', name: '' }),
    /invalid_id/,
  );
});

test('quotation catalog validates dimensional pricing rules', () => {
  const rule = validateRecord('pricingRules', {
    id: 'woodwork-area',
    code: 'WOODWORK_AREA',
    name: 'Woodwork area',
    pricingModel: 'area',
    unit: 'Sq. Ft',
    unitRate: 1600,
    inputUnit: 'mm',
    conversionFactor: 0.0000107639,
  });
  assert.equal(rule.conversionFactor, 0.0000107639);
  assert.equal(rule.roundingDecimals, 2);

  assert.throws(
    () => validateRecord('pricingRules', {
      id: 'bad',
      code: 'BAD',
      name: 'Bad',
      pricingModel: 'unknown',
      unit: 'No',
      unitRate: 10,
    }),
    /invalid_pricing_rule/,
  );
});

test('quotation catalog validates unpriced tiered line items', () => {
  const entry = validateRecord('lineItems', {
    id: 'starter-wardrobe',
    name: 'Wardrobe',
    basicRatePerSqft: null,
    mediumRatePerSqft: 1250,
    luxuryRatePerSqft: 2100,
  });
  assert.equal(entry.basicRatePerSqft, null);
  assert.equal(entry.mediumRatePerSqft, 1250);
  assert.equal(entry.active, true);

  assert.throws(
    () => validateRecord('lineItems', {
      id: 'invalid-rate',
      name: 'Invalid rate',
      basicRatePerSqft: -1,
    }),
    /invalid_basic_rate_per_sqft/,
  );
});

test('quotation catalog saves workspace-scoped tier rates', async () => {
  const queries = [];
  const entry = await upsertRecord({
    query: async (sql, values) => {
      queries.push({ sql: String(sql), values });
      return { rows: [] };
    },
  }, 'workspace-1', 'lineItems', {
    id: 'wardrobe',
    name: 'Wardrobe',
    basicRatePerSqft: 100,
    mediumRatePerSqft: null,
    luxuryRatePerSqft: 200,
    version: 2,
  });

  assert.equal(entry.name, 'Wardrobe');
  assert.equal(queries.length, 2);
  assert.match(queries[1].sql, /INSERT INTO quotation_line_item_catalog/);
  assert.deepEqual(queries[1].values, [
    'workspace-1',
    'wardrobe',
    'Wardrobe',
    100,
    null,
    200,
    true,
    2,
  ]);
  await assert.rejects(
    () => upsertRecord({
      query: async () => ({ rows: [{ id: 'existing-item' }] }),
    }, 'workspace-1', 'lineItems', {
      id: 'different-id',
      name: 'Wardrobe',
      basicRatePerSqft: 100,
    }),
    /duplicate_line_item_name/,
  );
});

test('quotation catalog rejects unauthorized catalog writes', async () => {
  const res = mockResponse();
  const handler = createQuotationCatalogHandler({
    authenticate: async () => ({ userId: 'user-1' }),
    withWorkspace: async (_userId, _workspaceId, operation) =>
      operation({}, {
        workspaceId: '11111111-1111-4111-8111-111111111111',
        permissions: [],
      }),
  });

  await handler({
    method: 'PUT',
    headers: {
      'x-workspace-id': '11111111-1111-4111-8111-111111111111',
    },
    body: {
      type: 'packages',
      record: { id: 'basic', code: 'basic', name: 'Basic' },
    },
  }, res);

  assert.equal(res.statusCode, 403);
  assert.equal(res.body.error, 'permission_denied');
});

test('quotation catalog reads all catalog collections', async () => {
  const res = mockResponse();
  const handler = createQuotationCatalogHandler({
    authenticate: async () => ({ userId: 'user-1' }),
    withWorkspace: async (_userId, _workspaceId, operation) =>
      operation({
        query: async (sql) => {
          if (String(sql).includes('quotation_packages')) {
            return { rows: [{ id: 'basic', name: 'Basic' }] };
          }
          return { rows: [] };
        },
      }, {
        workspaceId: '11111111-1111-4111-8111-111111111111',
        permissions: ['viewFinancials'],
      }),
  });

  await handler({
    method: 'GET',
    headers: {
      'x-workspace-id': '11111111-1111-4111-8111-111111111111',
    },
  }, res);

  assert.equal(res.statusCode, 200);
  assert.ok(res.body.catalog);
  assert.equal(res.body.catalog.packages[0].name, 'Basic');
});

test('quotation catalog seeds starter line items for an empty workspace', async () => {
  const res = mockResponse();
  const executedQueries = [];
  const handler = createQuotationCatalogHandler({
    authenticate: async () => ({ userId: 'user-1' }),
    withWorkspace: async (_userId, _workspaceId, operation) =>
      operation({
        query: async (sql) => {
          executedQueries.push(String(sql));
          if (String(sql).includes('FROM quotation_line_item_catalog')) {
            return {
              rows: [{
                id: 'starter-wardrobe',
                name: 'Wardrobe',
                basicRatePerSqft: null,
                mediumRatePerSqft: null,
                luxuryRatePerSqft: null,
                active: true,
                version: 1,
              }],
            };
          }
          return { rows: [] };
        },
      }, {
        workspaceId: '11111111-1111-4111-8111-111111111111',
        permissions: ['viewFinancials'],
      }),
  });

  await handler({
    method: 'GET',
    headers: {
      'x-workspace-id': '11111111-1111-4111-8111-111111111111',
    },
  }, res);

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.catalog.lineItems[0].name, 'Wardrobe');
  assert.ok(executedQueries.some((sql) =>
    sql.includes("('starter-wardrobe','Wardrobe')")));
});
