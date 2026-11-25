const assert = require('node:assert/strict');
const test = require('node:test');

const workspaceHandler = require('../../api/workspace');
const { getSupabaseUrl } = require('../../api/_lib/auth');
const { RateLimitError } = require('../../api/_lib/rate_limit');
const {
  assertWorkspaceChangePermissions,
  flattenSnapshot,
  loadCollection,
  mergeSnapshotChanges,
  unflattenSnapshot,
  validateSnapshot,
} = workspaceHandler;
const { WorkspaceAccessError } = require('../../api/_lib/database');

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
    schemaVersion: 5,
    customers: [{ id: 'customer-1', name: 'Client' }],
    pipelineStages: ['Inquiry', 'Discovery'],
    activities: [],
    personas: [],
    preferences: { studioName: 'Studio' },
    delivery: {
      projects: [{ id: 'project-1' }],
      phases: [],
      tasks: [],
      milestones: [],
      materials: [],
      vendors: [],
      requisitions: [],
      rfqs: [],
      vendorQuotes: [],
      purchaseOrders: [],
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

function planningSnapshot() {
  return {
    schemaVersion: 5,
    customers: [],
    pipelineStages: ['Inquiry', 'Client'],
    activities: [],
    personas: [],
    preferences: {
      studioName: 'Studio',
      defaultPipelineStage: 'Inquiry',
      activePersonaId: 'owner',
    },
    delivery: {
      projects: [{
        id: 'project-1',
        name: 'Site',
        location: 'North site',
        status: 'Planning',
        customerId: null,
        targetDate: null,
        startDate: null,
        budget: null,
      }],
      phases: [],
      tasks: [],
      milestones: [],
      materials: [],
      vendors: [],
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
      settings: {},
    },
    communications: [],
  };
}

function procurementSnapshot() {
  const snapshot = planningSnapshot();
  snapshot.delivery.materials = [{
    id: 'material-1',
    name: 'Concrete',
    category: 'Cement & concrete',
    unit: 'm3',
    specification: 'M25',
    description: '',
    isActive: true,
  }];
  snapshot.delivery.vendors = [{
    id: 'vendor-1',
    name: 'North Supply',
    kind: 'Supplier',
    email: 'orders@example.test',
    phone: '',
    address: '',
    taxId: '',
    paymentTerms: '',
    notes: '',
    isActive: true,
    documents: [],
  }];
  snapshot.delivery.rfqs = [];
  snapshot.delivery.vendorQuotes = [];
  snapshot.delivery.purchaseOrders = [];
  snapshot.delivery.requisitions = [{
    id: 'requisition-1',
    projectId: 'project-1',
    title: 'Foundation concrete',
    requiredBy: null,
    notes: '',
    status: 'Draft',
    items: [{
      id: 'line-1',
      materialId: 'material-1',
      name: 'Concrete',
      unit: 'm3',
      quantityMilli: 2500,
      specification: 'M25',
    }],
    approvalSteps: [],
    createdAt: '2026-10-01T00:00:00.000Z',
  }];
  snapshot.preferences.procurementApprovalPolicy = {
    requisitionPermissions: ['procurement.approve'],
    purchaseOrderPermissions: ['procurement.approve', 'manageFinancials'],
  };
  return snapshot;
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

test('site execution rejects receipts above PO quantities and negative stock', () => {
  const snapshot = planningSnapshot();
  snapshot.delivery.purchaseOrders = [{
    id: 'po-1',
    projectId: 'project-1',
    requisitionId: 'req-1',
    rfqId: 'rfq-1',
    quoteId: 'quote-1',
    vendorId: 'vendor-1',
    currency: 'USD',
    items: [{
      requisitionLineId: 'line-1',
      description: 'Cement',
      unit: 'bag',
      quantityMilli: 1000,
      unitPriceMinor: 100,
      lineTotalMinor: 100,
    }],
    totalMinor: 100,
    notes: '',
    status: 'Issued',
    approvalSteps: [],
    createdAt: '2026-01-01T00:00:00.000Z',
    issuedAt: '2026-01-02T00:00:00.000Z',
  }];
  snapshot.delivery.goodsReceipts = [{
    id: 'receipt-1',
    projectId: 'project-1',
    purchaseOrderId: 'po-1',
    location: 'Site',
    notes: '',
    status: 'Complete',
    lines: [{
      purchaseOrderLineId: 'line-1',
      quantityMilli: 1001,
      acceptedQuantityMilli: 1001,
    }],
    receivedAt: '2026-01-03T00:00:00.000Z',
  }];
  assert.throws(
    () => validateSnapshot(snapshot),
    /goods_receipt_exceeds_purchase_order/,
  );

  const negativeStock = planningSnapshot();
  negativeStock.delivery.stockBalances = [{
    id: 'balance-1',
    projectId: 'project-1',
    materialId: 'material-1',
    location: 'Site',
    quantityMilli: -1,
  }];
  assert.throws(() => validateSnapshot(negativeStock), /invalid_stock_balance/);
});

test('vendor bills require issued PO and matching receipt project', () => {
  const snapshot = planningSnapshot();
  snapshot.delivery.purchaseOrders = [{
    id: 'po-1',
    projectId: 'project-1',
    requisitionId: 'req-1',
    rfqId: 'rfq-1',
    quoteId: 'quote-1',
    vendorId: 'vendor-1',
    currency: 'USD',
    items: [],
    totalMinor: 1000,
    notes: '',
    status: 'Issued',
    approvalSteps: [],
    createdAt: '2026-01-01T00:00:00.000Z',
    issuedAt: '2026-01-02T00:00:00.000Z',
  }];
  snapshot.delivery.goodsReceipts = [{
    id: 'receipt-1',
    projectId: 'project-1',
    purchaseOrderId: 'po-1',
    location: 'Site',
    notes: '',
    status: 'Complete',
    lines: [],
    receivedAt: '2026-01-03T00:00:00.000Z',
  }];
  snapshot.financials.vendorBills = [{
    id: 'bill-1',
    projectId: 'project-2',
    vendorId: 'vendor-1',
    purchaseOrderId: 'po-1',
    receiptIds: ['receipt-1'],
    billNumber: 'BILL-1',
    amountMinor: 500,
    currency: 'USD',
    status: 'Open',
    dueAt: null,
  }];
  assert.throws(() => validateSnapshot(snapshot), /invalid_vendor_bill/);
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

test('workspace validation rejects cyclic task dependencies', () => {
  const snapshot = planningSnapshot();
  snapshot.delivery.tasks = [
    {
      id: 'task-1',
      projectId: 'project-1',
      title: 'First task',
      assignee: 'Owner',
      dueDate: null,
      isComplete: false,
      priority: 'Normal',
      dependsOnTaskIds: ['task-2'],
    },
    {
      id: 'task-2',
      projectId: 'project-1',
      title: 'Second task',
      assignee: 'Owner',
      dueDate: null,
      isComplete: false,
      priority: 'Normal',
      dependsOnTaskIds: ['task-1'],
    },
  ];

  assert.throws(() => validateSnapshot(snapshot), /task_dependency_cycle/);
});

test('workspace validation requires supported material units', () => {
  const snapshot = planningSnapshot();
  snapshot.delivery.materials.push({
    id: 'material-1',
    name: 'Concrete',
    category: 'Structural',
    unit: 'unknown',
    specification: '',
    description: '',
    isActive: true,
  });

  assert.throws(() => validateSnapshot(snapshot), /invalid_material/);
});

test('workspace validation rejects cross-project task dependencies', () => {
  const snapshot = planningSnapshot();
  snapshot.delivery.projects.push({
    id: 'project-2',
    name: 'South site',
    location: 'South site',
    status: 'Planning',
    customerId: null,
    targetDate: null,
  });
  snapshot.delivery.tasks = [
    {
      id: 'task-1',
      projectId: 'project-1',
      title: 'Prepare site',
      assignee: 'Owner',
      dueDate: null,
      isComplete: false,
      priority: 'Normal',
      dependsOnTaskIds: [],
    },
    {
      id: 'task-2',
      projectId: 'project-2',
      title: 'Build site',
      assignee: 'Owner',
      dueDate: null,
      isComplete: false,
      priority: 'Normal',
      dependsOnTaskIds: ['task-1'],
    },
  ];

  assert.throws(() => validateSnapshot(snapshot), /invalid_task_dependency/);
});

test('procurement requests require active catalogue references and valid approval policy', () => {
  const valid = procurementSnapshot();
  assert.doesNotThrow(() =>
    workspaceHandler.validateProcurementSnapshot(
      valid,
      workspaceHandler.HttpError,
    ));
  assert.equal(valid.delivery.requisitions[0].status, 'Draft');

  const invalidMaterial = structuredClone(valid);
  invalidMaterial.delivery.requisitions[0].items[0].materialId = 'missing';
  assert.throws(
    () => workspaceHandler.validateProcurementSnapshot(
      invalidMaterial,
      workspaceHandler.HttpError,
    ),
    /invalid_requisition/,
  );

  const invalidPolicy = structuredClone(valid);
  invalidPolicy.preferences.procurementApprovalPolicy.requisitionPermissions =
    ['unknown.permission'];
  assert.throws(
    () => workspaceHandler.validateProcurementSnapshot(
      invalidPolicy,
      workspaceHandler.HttpError,
    ),
    /invalid_procurement_approval_policy/,
  );
});

test('procurement approval transitions enforce project scope and create audit events', () => {
  const current = procurementSnapshot();
  const submitted = structuredClone(current);
  submitted.delivery.requisitions[0].status = 'Pending approval';
  submitted.delivery.requisitions[0].approvalSteps =
    current.preferences.procurementApprovalPolicy.requisitionPermissions.map(
      (permission) => ({
        permission,
        status: 'Pending',
        decisionNote: '',
        decidedAt: null,
      }),
    );
  const hasPermission = (access, permission) =>
    access.permissions.includes('*') ||
    access.permissions.includes(permission);
  const events = workspaceHandler.validateProcurementTransitions(
    current,
    submitted,
    {
      permissions: ['procurement.manage'],
      projectPermissions: new Map(),
    },
    hasPermission,
    workspaceHandler.HttpError,
    WorkspaceAccessError,
  );
  assert.equal(events[0].action, 'submitted_for_approval');

  const approved = structuredClone(submitted);
  approved.delivery.requisitions[0].status = 'Approved';
  approved.delivery.requisitions[0].approvalSteps[0] = {
    permission: 'procurement.approve',
    status: 'Approved',
    decisionNote: 'Approved for this project.',
    decidedAt: '2026-10-02T00:00:00.000Z',
  };
  assert.throws(
    () => workspaceHandler.validateProcurementTransitions(
      submitted,
      approved,
      {
        permissions: [],
        projectPermissions: new Map([
          ['another-project', ['procurement.approve']],
        ]),
      },
      hasPermission,
      workspaceHandler.HttpError,
      WorkspaceAccessError,
    ),
    { code: 'permission_denied' },
  );

  const approvalEvents = workspaceHandler.validateProcurementTransitions(
    submitted,
    approved,
    {
      permissions: [],
      projectPermissions: new Map([
        ['project-1', ['procurement.approve']],
      ]),
    },
    hasPermission,
    workspaceHandler.HttpError,
    WorkspaceAccessError,
  );
  assert.equal(approvalEvents[0].action, 'approval_granted');
});

test('project-only permissions cannot modify organization master data', () => {
  const current = planningSnapshot();
  const next = structuredClone(current);
  next.delivery.materials.push({
    id: 'material-1',
    name: 'Cement',
    category: 'Cement & concrete',
    unit: 'bag',
    specification: '',
    description: '',
    isActive: true,
  });

  assert.throws(
    () => assertWorkspaceChangePermissions({
      permissions: ['manageProjects'],
      projectPermissions: new Map([['project-1', ['manageTasks']]]),
    }, current, {
      snapshot: next,
      changedSettings: new Set(),
      changedCollections: new Set(['materials']),
    }),
    { code: 'permission_denied' },
  );
  assert.doesNotThrow(
    () => assertWorkspaceChangePermissions({
      permissions: ['inventory.manage'],
      projectPermissions: new Map(),
    }, current, {
      snapshot: next,
      changedSettings: new Set(),
      changedCollections: new Set(['materials']),
    }),
  );
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

  await handler({
    method: 'GET',
    headers: {
      'x-workspace-id': '00000000-0000-4000-8000-000000000002',
    },
  }, response);

  assert.equal(response.statusCode, 429);
  assert.equal(response.headers['Retry-After'], '30');
  assert.deepEqual(response.body, { error: 'rate_limit_exceeded' });
});

test('workspace API rejects stale or malformed revisions before database access', async () => {
  const handler = workspaceHandler.createWorkspaceHandler({
    authenticate: async () => ({ userId: '00000000-0000-4000-8000-000000000001' }),
    withWorkspace: async () => {
      throw new Error('must not access database');
    },
  });
  const response = createResponse();

  await handler(
    {
      method: 'PUT',
      headers: {
        'x-workspace-id': '00000000-0000-4000-8000-000000000002',
      },
      body: { revision: -1, snapshot: sampleSnapshot() },
    },
    response,
  );

  assert.equal(response.statusCode, 400);
  assert.deepEqual(response.body, { error: 'invalid_workspace_revision' });
});

test('workspace API enforces collection permissions for partial updates', async () => {
  const handler = workspaceHandler.createWorkspaceHandler({
    authenticate: async () => ({
      userId: '00000000-0000-4000-8000-000000000001',
    }),
    withWorkspace: async (_userId, _workspaceId, operation) =>
      operation({
        query: async (sql) => sql.includes('LEFT JOIN workspace_settings')
          ? {
            rows: [{
              id: '00000000-0000-4000-8000-000000000002',
              data: {
                preferences: { studioName: 'Studio' },
                financialSettings: {},
              },
              revision: 1,
            }],
          }
          : { rows: [] },
      }, { permissions: [], projectPermissions: new Map() }),
  });
  const response = createResponse();

  await handler({
    method: 'PATCH',
    headers: {
      'x-workspace-id': '00000000-0000-4000-8000-000000000002',
    },
    body: { revision: 1, changes: { customers: [] } },
  }, response);

  assert.equal(response.statusCode, 403);
  assert.deepEqual(response.body, { error: 'permission_denied' });
});

test('project-scoped updates preserve records from other projects', () => {
  const projectOneTask = {
    id: 'task-1',
    projectId: 'project-1',
    title: 'Updated task',
  };
  const projectTwoTask = {
    id: 'task-2',
    projectId: 'project-2',
    title: 'Unchanged task',
  };
  const snapshot = {
    schemaVersion: 4,
    delivery: {
      tasks: [
        { ...projectOneTask, title: 'Old task' },
        projectTwoTask,
      ],
    },
  };
  const access = {
    permissions: [],
    projectPermissions: new Map([['project-1', ['manageTasks']]]),
  };
  const changes = mergeSnapshotChanges(
    snapshot,
    { 'delivery.tasks': [projectOneTask] },
    access,
  );

  assert.deepEqual(changes.snapshot.delivery.tasks, [
    projectTwoTask,
    projectOneTask,
  ]);
  assert.doesNotThrow(() =>
    assertWorkspaceChangePermissions(access, snapshot, changes),
  );
  assert.throws(
    () => mergeSnapshotChanges(
      snapshot,
      {
        'delivery.tasks': [
          projectOneTask,
          { ...projectTwoTask, title: 'Tampered task' },
        ],
      },
      access,
    ),
    { code: 'permission_denied' },
  );
  assert.throws(
    () => mergeSnapshotChanges(
      snapshot,
      {
        'delivery.tasks': [
          projectOneTask,
          { ...projectTwoTask, projectId: 'project-1' },
        ],
      },
      access,
    ),
    { code: 'permission_denied' },
  );
});

test('project-scoped reads query only records assigned to the user', async () => {
  const statements = [];
  const client = {
    query: async (sql, values = []) => {
      statements.push({ sql, values });
      if (sql.includes('LEFT JOIN workspace_settings')) {
        return {
          rows: [{
            id: '00000000-0000-4000-8000-000000000002',
            revision: 4,
          }],
        };
      }
      if (sql.includes('count(*)')) return { rows: [{ total: 1 }] };
      return {
        rows: [{ data: { id: 'task-1', projectId: 'project-1' } }],
      };
    },
  };
  const page = await loadCollection(
    client,
    'member-1',
    { url: '/api/workspace?collection=tasks&limit=10&offset=0' },
    {
      permissions: [],
      projectPermissions: new Map([['project-1', ['manageTasks']]]),
    },
  );

  assert.equal(page.total, 1);
  assert.deepEqual(page.records, [{ id: 'task-1', projectId: 'project-1' }]);
  assert.match(statements[2].sql, /data->>'projectId' = ANY\(\$4::text\[\]\)/);
  assert.deepEqual(statements[2].values, [
    '00000000-0000-4000-8000-000000000002',
    'tasks',
    null,
    ['project-1'],
    10,
    0,
  ]);
});

test('project reads hide budget data without financial permission', async () => {
  const statements = [];
  const client = {
    query: async (sql, values = []) => {
      statements.push({ sql, values });
      if (sql.includes('LEFT JOIN workspace_settings')) {
        return {
          rows: [{
            id: '00000000-0000-4000-8000-000000000002',
            revision: 4,
          }],
        };
      }
      if (sql.includes('count(*)')) return { rows: [{ total: 1 }] };
      return {
        rows: [{ data: { id: 'project-1', budget: null } }],
      };
    },
  };
  const page = await loadCollection(
    client,
    'member-1',
    { url: '/api/workspace?collection=projects&limit=10&offset=0' },
    { permissions: ['viewProjects'], projectPermissions: new Map() },
  );

  assert.equal(page.records[0].budget, null);
  assert.match(statements[2].sql, /jsonb_set\(data, '\{budget\}', 'null'::jsonb\)/);
});

test('project edits preserve budgets unless the editor can manage finance', () => {
  const snapshot = planningSnapshot();
  snapshot.delivery.projects[0].budget = 250000;
  const changes = {
    'delivery.projects': [{
      ...snapshot.delivery.projects[0],
      name: 'Renovation',
      budget: null,
    }],
  };

  const merged = mergeSnapshotChanges(snapshot, changes, {
    permissions: ['manageProjects'],
    projectPermissions: new Map(),
  });
  assert.equal(merged.snapshot.delivery.projects[0].budget, 250000);
  assert.throws(
    () => mergeSnapshotChanges(snapshot, {
      'delivery.projects': [{
        ...snapshot.delivery.projects[0],
        budget: 1,
      }],
    }, {
      permissions: ['manageProjects'],
      projectPermissions: new Map(),
    }),
    { code: 'permission_denied' },
  );
});

test('project-scoped customer reads omit sensitive client details', async () => {
  const statements = [];
  const client = {
    query: async (sql, values = []) => {
      statements.push({ sql, values });
      if (sql.includes('LEFT JOIN workspace_settings')) {
        return {
          rows: [{
            id: '00000000-0000-4000-8000-000000000002',
            revision: 4,
          }],
        };
      }
      if (sql.includes('SELECT DISTINCT data->>')) {
        return { rows: [{ customer_id: 'customer-1' }] };
      }
      if (sql.includes('count(*)')) return { rows: [{ total: 1 }] };
      return {
        rows: [{
          data: {
            id: 'customer-1',
            name: 'Client',
            value: 'Restricted',
            email: '',
            phone: '',
            notes: '',
          },
        }],
      };
    },
  };
  const page = await loadCollection(
    client,
    'member-1',
    { url: '/api/workspace?collection=customers&limit=10&offset=0' },
    {
      permissions: [],
      projectPermissions: new Map([['project-1', ['manageTasks']]]),
    },
  );

  assert.deepEqual(page.records, [{
    id: 'customer-1',
    name: 'Client',
    value: 'Restricted',
    email: '',
    phone: '',
    notes: '',
  }]);
  assert.match(statements[2].sql, /position\(lower\(\$3\) in lower\(jsonb_set/);
  assert.match(statements[3].sql, /data - 'requirement'/);
  assert.match(statements[3].sql, /'\{email\}', '""'::jsonb/);
  assert.match(statements[3].sql, /data->>'id' = ANY\(\$5::text\[\]\)/);
  assert.deepEqual(statements[3].values, [
    '00000000-0000-4000-8000-000000000002',
    'customers',
    null,
    ['project-1'],
    ['customer-1'],
    10,
    0,
  ]);
});
