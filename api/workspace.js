const { authenticateRequest } = require('./_lib/auth');
const { withUserTransaction } = require('./_lib/database');
const {
  enforceUserRateLimit,
  respondToRateLimit,
} = require('./_lib/rate_limit');
const { attachRequestId } = require('./_lib/request_id');

const collectionFields = new Map([
  ['customers', ['customers', 'customers']],
  ['activities', ['activities', 'activities']],
  ['personas', ['personas', 'personas']],
  ['projects', ['delivery', 'projects']],
  ['tasks', ['delivery', 'tasks']],
  ['milestones', ['delivery', 'milestones']],
  ['punchItems', ['delivery', 'punchItems']],
  ['assets', ['delivery', 'assets']],
  ['workLogs', ['delivery', 'workLogs']],
  ['attendance', ['delivery', 'attendance']],
  ['approvals', ['delivery', 'approvals']],
  ['quotations', ['financials', 'quotations']],
  ['templates', ['financials', 'templates']],
  ['proposals', ['financials', 'proposals']],
  ['invoices', ['financials', 'invoices']],
  ['communications', ['communications', 'communications']],
]);
const collectionNames = new Set([
  ...collectionFields.keys(),
  'invoicePayments',
  'pipelineStages',
  'preferences',
  'financialSettings',
]);
const changePathCollections = new Map([
  ['customers', 'customers'],
  ['pipelineStages', 'pipelineStages'],
  ['activities', 'activities'],
  ['personas', 'personas'],
  ['preferences', null],
  ['delivery.projects', 'projects'],
  ['delivery.tasks', 'tasks'],
  ['delivery.milestones', 'milestones'],
  ['delivery.punchItems', 'punchItems'],
  ['delivery.assets', 'assets'],
  ['delivery.workLogs', 'workLogs'],
  ['delivery.attendance', 'attendance'],
  ['delivery.approvals', 'approvals'],
  ['financials.quotations', 'quotations'],
  ['financials.templates', 'templates'],
  ['financials.proposals', 'proposals'],
  ['financials.invoices', 'invoices'],
  ['financials.settings', null],
  ['communications', 'communications'],
]);
const maximumRequestBytes = 3 * 1024 * 1024;
const maximumRecordsPerCollection = 10000;
const allowedProjectFileTypes = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'application/pdf',
  'text/plain',
  'text/csv',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
]);

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

function roundMoney(value) {
  return Math.round((value + Number.EPSILON) * 100) / 100;
}

function hasPrecision(value, digits) {
  const scaled = value * (10 ** digits);
  return Math.abs(scaled - Math.round(scaled)) < 1e-8;
}

function isValidDateTime(value) {
  if (typeof value !== 'string') return false;
  const match = /^(\d{4})-(\d{2})-(\d{2})(?:T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})?)?$/
    .exec(value);
  if (!match || !Number.isFinite(Date.parse(value))) return false;
  const date = new Date(Date.UTC(
    Number(match[1]),
    Number(match[2]) - 1,
    Number(match[3]),
  ));
  return date.getUTCFullYear() === Number(match[1]) &&
    date.getUTCMonth() === Number(match[2]) - 1 &&
    date.getUTCDate() === Number(match[3]);
}

function formatCents(value) {
  const whole = value / 100n;
  const cents = (value % 100n).toString().padStart(2, '0');
  return `${whole}.${cents}`;
}

function calculateFinancialTotals(items, taxRate) {
  let subtotalCents = 0n;
  for (const item of items) {
    const quantityMilli = BigInt(Math.round(item.quantity * 1000));
    const unitRateCents = BigInt(Math.round(item.unitRate * 100));
    subtotalCents += (quantityMilli * unitRateCents + 500n) / 1000n;
  }
  const taxRateBasisPoints = BigInt(Math.round(taxRate * 100));
  const taxCents =
    (subtotalCents * taxRateBasisPoints + 5000n) / 10000n;
  return {
    subtotal: formatCents(subtotalCents),
    taxTotal: formatCents(taxCents),
    total: formatCents(subtotalCents + taxCents),
    subtotalCents,
    totalCents: subtotalCents + taxCents,
  };
}

function validateFinancialNumbering(snapshot, existingDocumentIds, previousSettings) {
  const settings = snapshot.financials.settings;
  const sequences = [
    ['quotations', 'quotationPrefix', 'nextQuotationNumber'],
    ['proposals', 'proposalPrefix', 'nextProposalNumber'],
    ['invoices', 'invoicePrefix', 'nextInvoiceNumber'],
  ];
  for (const [collection, prefixKey, nextKey] of sequences) {
    const prefix = settings[prefixKey];
    let maximumNumber = 0n;
    for (const document of snapshot.financials[collection]) {
      if (!document.number.startsWith(prefix)) {
        if (!existingDocumentIds.has(`${collection}:${document.id}`)) {
          throw new HttpError(400, 'invalid_financial_document_number');
        }
        continue;
      }
      const suffix = document.number.slice(prefix.length);
      if (!/^0*[1-9]\d*$/.test(suffix)) {
        if (!existingDocumentIds.has(`${collection}:${document.id}`)) {
          throw new HttpError(400, 'invalid_financial_document_number');
        }
        continue;
      }
      const sequence = BigInt(suffix);
      if (!existingDocumentIds.has(`${collection}:${document.id}`)) {
        const previousPrefix = previousSettings?.[prefixKey];
        const previousNext = previousSettings?.[nextKey];
        if (previousPrefix === prefix &&
            Number.isSafeInteger(previousNext) &&
            sequence < BigInt(previousNext)) {
          throw new HttpError(400, 'financial_document_number_reused');
        }
      }
      if (sequence > maximumNumber) maximumNumber = sequence;
    }

    const next = BigInt(settings[nextKey]);
    if (next <= maximumNumber) {
      throw new HttpError(400, 'invalid_financial_document_sequence');
    }
    if (previousSettings?.[prefixKey] === prefix &&
        Number.isSafeInteger(previousSettings[nextKey]) &&
        settings[nextKey] < previousSettings[nextKey]) {
      throw new HttpError(400, 'financial_document_sequence_cannot_decrease');
    }
  }
}

function validateSnapshot(snapshot, userId) {
  if (!isRecord(snapshot) || snapshot.schemaVersion !== 4) {
    throw new HttpError(400, 'invalid_workspace');
  }
  if (!Array.isArray(snapshot.customers) ||
      !Array.isArray(snapshot.pipelineStages) ||
      !Array.isArray(snapshot.activities) ||
      !Array.isArray(snapshot.personas) ||
      !Array.isArray(snapshot.communications) ||
      !isRecord(snapshot.preferences) ||
      !isRecord(snapshot.delivery) ||
      !isRecord(snapshot.financials)) {
    throw new HttpError(400, 'invalid_workspace');
  }

  for (const [collection, [parent, field]] of collectionFields) {
    const records = parent === 'customers' || parent === 'activities' ||
        parent === 'personas' || parent === 'communications'
      ? snapshot[parent]
      : snapshot[parent]?.[field];
    if (!Array.isArray(records) || records.length > maximumRecordsPerCollection) {
      throw new HttpError(400, `invalid_${collection}`);
    }
    if (records.some((record) =>
      !isRecord(record) ||
      typeof record.id !== 'string' ||
      record.id.trim().length === 0 ||
      record.id.length > 160)) {
      throw new HttpError(400, `invalid_${collection}`);
    }
    const ids = records.map((record) => record.id);
    if (new Set(ids).size !== ids.length) {
      throw new HttpError(400, `duplicate_${collection}_id`);
    }
  }

  if (snapshot.pipelineStages.some((stage) =>
    typeof stage !== 'string' || stage.trim().length === 0 || stage.length > 40)) {
    throw new HttpError(400, 'invalid_pipeline_stages');
  }
  if (new Set(snapshot.pipelineStages.map((stage) => stage.trim().toLowerCase())).size !==
      snapshot.pipelineStages.length) {
    throw new HttpError(400, 'duplicate_pipeline_stage');
  }
  if (typeof snapshot.preferences.studioName !== 'string' ||
      snapshot.preferences.studioName.trim().length < 1 ||
      snapshot.preferences.studioName.length > 80 ||
      !snapshot.pipelineStages.includes(snapshot.preferences.defaultPipelineStage)) {
    throw new HttpError(400, 'invalid_workspace_preferences');
  }

  const customerIds = new Set(snapshot.customers.map((customer) => customer.id));
  const personaIds = new Set(snapshot.personas.map((persona) => persona.id));
  const projects = snapshot.delivery.projects;
  const projectIds = new Set(projects.map((project) => project.id));
  if (projects.some((project) =>
    typeof project.name !== 'string' ||
    project.name.trim().length === 0 ||
    project.name.length > 200 ||
    typeof project.location !== 'string' ||
    project.location.length > 200 ||
    !['Planning', 'In progress', 'On hold', 'Complete']
      .includes(project.status) ||
    (project.targetDate != null && !isValidDateTime(project.targetDate)))) {
    throw new HttpError(400, 'invalid_project');
  }
  const taskIds = new Set(snapshot.delivery.tasks.map((task) => task.id));
  if (snapshot.delivery.tasks.some((task) =>
    typeof task.title !== 'string' ||
    task.title.trim().length === 0 ||
    task.title.length > 200 ||
    typeof task.assignee !== 'string' ||
    task.assignee.length > 120 ||
    (task.dueDate != null && !isValidDateTime(task.dueDate)) ||
    typeof task.isComplete !== 'boolean' ||
    !['Low', 'Normal', 'High'].includes(task.priority))) {
    throw new HttpError(400, 'invalid_task');
  }
  if (snapshot.delivery.milestones.some((item) =>
    typeof item.title !== 'string' ||
    item.title.trim().length === 0 ||
    item.title.length > 200 ||
    (item.dueDate != null && !isValidDateTime(item.dueDate)) ||
    !['Not started', 'In progress', 'Complete'].includes(item.status) ||
    typeof item.update !== 'string' ||
    item.update.length > 1000 ||
    !isValidDateTime(item.updatedAt))) {
    throw new HttpError(400, 'invalid_milestone');
  }
  if (snapshot.delivery.punchItems.some((item) =>
    typeof item.description !== 'string' ||
    item.description.trim().length === 0 ||
    item.description.length > 1000 ||
    typeof item.assignee !== 'string' ||
    item.assignee.length > 120 ||
    (item.dueDate != null && !isValidDateTime(item.dueDate)) ||
    !['Open', 'In progress', 'Resolved'].includes(item.status) ||
    !isValidDateTime(item.createdAt))) {
    throw new HttpError(400, 'invalid_punch_item');
  }
  if (snapshot.delivery.workLogs.some((log) =>
    typeof log.taskId !== 'undefined' &&
      log.taskId !== null && !taskIds.has(log.taskId) ||
    typeof log.author !== 'string' ||
    log.author.trim().length === 0 ||
    log.author.length > 120 ||
    !Number.isInteger(log.minutes) ||
    log.minutes < 1 ||
    log.minutes > 1440 ||
    typeof log.description !== 'string' ||
    log.description.trim().length === 0 ||
    log.description.length > 1000 ||
    !isValidDateTime(log.loggedAt) ||
    (log.taskId != null &&
      !snapshot.delivery.tasks.some((task) =>
        task.id === log.taskId && task.projectId === log.projectId)))) {
    throw new HttpError(400, 'invalid_work_log');
  }
  const attendanceKeys = snapshot.delivery.attendance.map((entry) =>
    `${entry.personaId}:${String(entry.date).slice(0, 10)}`);
  if (snapshot.delivery.attendance.some((entry) =>
    typeof entry.personaId !== 'string' ||
    entry.personaId.trim().length === 0 ||
    entry.personaId.length > 160 ||
    !personaIds.has(entry.personaId) ||
    typeof entry.personaName !== 'string' ||
    entry.personaName.trim().length === 0 ||
    entry.personaName.length > 120 ||
    !isValidDateTime(entry.date) ||
    !['Present', 'Remote', 'Late', 'Away'].includes(entry.status) ||
    typeof entry.note !== 'string' ||
    entry.note.length > 1000) ||
      new Set(attendanceKeys).size !== attendanceKeys.length) {
    throw new HttpError(400, 'invalid_attendance');
  }
  if (snapshot.delivery.approvals.some((approval) =>
    typeof approval.title !== 'string' ||
    approval.title.trim().length === 0 ||
    approval.title.length > 200 ||
    typeof approval.details !== 'string' ||
    approval.details.length > 3000 ||
    typeof approval.requestedBy !== 'string' ||
    approval.requestedBy.trim().length === 0 ||
    approval.requestedBy.length > 120 ||
    typeof approval.approverPersonaId !== 'string' ||
    approval.approverPersonaId.trim().length === 0 ||
    approval.approverPersonaId.length > 160 ||
    !personaIds.has(approval.approverPersonaId) ||
    typeof approval.approverName !== 'string' ||
    approval.approverName.trim().length === 0 ||
    approval.approverName.length > 120 ||
    !['Pending', 'Approved', 'Rejected'].includes(approval.status) ||
    typeof approval.decisionNote !== 'string' ||
    approval.decisionNote.length > 1000 ||
    !isValidDateTime(approval.requestedAt) ||
    (approval.decidedAt != null &&
      !isValidDateTime(approval.decidedAt)) ||
    (approval.status === 'Pending' && approval.decidedAt != null) ||
    (approval.status !== 'Pending' && approval.decidedAt == null))) {
    throw new HttpError(400, 'invalid_approval');
  }
  const validProject = (record) =>
    projectIds.has(record.projectId);
  if (projects.some((project) =>
    (project.customerId != null && !customerIds.has(project.customerId))) ||
      snapshot.activities.some((activity) =>
        activity.customerId != null && !customerIds.has(activity.customerId)) ||
      snapshot.communications.some((entry) =>
        entry.clientId != null && !customerIds.has(entry.clientId)) ||
      snapshot.delivery.tasks.some((task) => !validProject(task)) ||
      snapshot.delivery.milestones.some((item) => !validProject(item)) ||
      snapshot.delivery.punchItems.some((item) => !validProject(item)) ||
      snapshot.delivery.assets.some((asset) => !validProject(asset)) ||
      snapshot.delivery.workLogs.some((log) => !validProject(log)) ||
      snapshot.delivery.approvals.some((approval) => !validProject(approval))) {
    throw new HttpError(400, 'invalid_workspace_references');
  }
  const allowedCommunicationChannels = new Set([
    'Internal note',
    'Email',
    'WhatsApp',
    'Call',
    'Meeting',
    'Message',
    'Other',
  ]);
  const allowedCommunicationStatuses = new Set([
    'Logged',
    'Draft',
    'Ready to send',
    'Queued',
    'Sending',
    'Sent',
    'Delivered',
    'Read',
    'Failed',
    'Received',
  ]);
  if (snapshot.communications.some((entry) =>
    typeof entry.clientName !== 'string' ||
    entry.clientName.length > 120 ||
    typeof entry.projectName !== 'string' ||
    entry.projectName.length > 120 ||
    !allowedCommunicationChannels.has(entry.channel) ||
    typeof entry.subject !== 'string' ||
    entry.subject.length > 200 ||
    /[\r\n]/.test(entry.subject) ||
    typeof entry.body !== 'string' ||
    entry.body.trim().length === 0 ||
    entry.body.length > 5000 ||
    typeof entry.recipient !== 'string' ||
    entry.recipient.length > 254 ||
    !allowedCommunicationStatuses.has(entry.status) ||
    typeof entry.createdByPersonaId !== 'string' ||
    entry.createdByPersonaId.trim().length === 0 ||
    !personaIds.has(entry.createdByPersonaId) ||
    typeof entry.createdByName !== 'string' ||
    entry.createdByName.trim().length === 0 ||
    entry.createdByName.length > 120 ||
    !isValidDateTime(entry.createdAt) ||
    !isValidDateTime(entry.updatedAt) ||
    !Array.isArray(entry.mentionedPersonaIds) ||
    entry.mentionedPersonaIds.some((id) => !personaIds.has(id)) ||
    new Set(entry.mentionedPersonaIds).size !== entry.mentionedPersonaIds.length ||
    !Array.isArray(entry.readByPersonaIds) ||
    entry.readByPersonaIds.some((id) => !personaIds.has(id)) ||
    new Set(entry.readByPersonaIds).size !== entry.readByPersonaIds.length ||
    (entry.channel === 'Email' &&
      entry.status !== 'Logged' &&
      !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(entry.recipient)) ||
    (entry.channel === 'WhatsApp' &&
      entry.status !== 'Logged' &&
      !/^\+?[1-9]\d{7,14}$/.test(
        entry.recipient.replace(/[\s().-]/g, ''),
      )))) {
    throw new HttpError(400, 'invalid_communication');
  }
  if (snapshot.delivery.assets.some((asset) =>
    typeof asset.storagePath !== 'string' ||
    asset.storagePath !== `${userId}/${asset.projectId}/${asset.id}` ||
    !/^[A-Za-z0-9._-]{1,160}$/.test(asset.projectId) ||
    !/^[A-Za-z0-9._-]{1,160}$/.test(asset.id) ||
    typeof asset.dataBase64 === 'string' && asset.dataBase64.length > 0 ||
    !Number.isInteger(asset.byteLength) ||
    asset.byteLength < 1 ||
    asset.byteLength > 1048576 ||
    !allowedProjectFileTypes.has(asset.mimeType) ||
    !['document', 'photo'].includes(asset.kind) ||
    typeof asset.name !== 'string' ||
    asset.name.trim().length === 0 ||
    asset.name.length > 255 ||
    typeof asset.caption !== 'string' ||
    asset.caption.length > 1000 ||
    typeof asset.addedBy !== 'string' ||
    asset.addedBy.trim().length === 0 ||
    asset.addedBy.length > 120 ||
    !isValidDateTime(asset.addedAt))) {
    throw new HttpError(400, 'invalid_project_file');
  }
  if (snapshot.delivery.assets.reduce(
    (total, asset) => total + asset.byteLength,
    0,
  ) > 2 * 1048576) {
    throw new HttpError(400, 'project_storage_limit_exceeded');
  }

  const quotationIds = new Set(
    snapshot.financials.quotations.map((quotation) => quotation.id),
  );
  const proposalIds = new Set(
    snapshot.financials.proposals.map((proposal) => proposal.id),
  );
  const approvedProposalIds = new Set(
    snapshot.financials.proposals
      .filter((proposal) => proposal.status === 'Approved')
      .map((proposal) => proposal.id),
  );
  const financialDocumentIds = [
    ...snapshot.financials.quotations,
    ...snapshot.financials.proposals,
    ...snapshot.financials.invoices,
  ].map((document) => document.id);
  if (new Set(financialDocumentIds).size !== financialDocumentIds.length) {
    throw new HttpError(400, 'duplicate_financial_document_id');
  }
  const documentNumbers = [];
  const validateItems = (items, taxRate, currencySymbol) => {
    if (!Array.isArray(items) || items.length === 0 ||
        typeof taxRate !== 'number' || !Number.isFinite(taxRate) ||
        taxRate < 0 || taxRate > 100 ||
        typeof currencySymbol !== 'string' ||
        currencySymbol.trim().length === 0 || currencySymbol.length > 4) {
      return null;
    }
    let subtotalCents = 0n;
    const itemIds = new Set();
    for (const item of items) {
      if (!isRecord(item) ||
          typeof item.id !== 'string' ||
          item.id.trim().length === 0 ||
          item.id.length > 160 ||
          itemIds.has(item.id) ||
          typeof item.description !== 'string' ||
          item.description.trim().length === 0 ||
          item.description.length > 180 ||
          typeof item.quantity !== 'number' ||
          !Number.isFinite(item.quantity) ||
          item.quantity <= 0 ||
          item.quantity > 999999999.999 ||
          !hasPrecision(item.quantity, 3) ||
          typeof item.unit !== 'string' ||
          item.unit.trim().length === 0 ||
          item.unit.length > 20 ||
          typeof item.unitRate !== 'number' ||
          !Number.isFinite(item.unitRate) ||
          item.unitRate < 0 ||
          item.unitRate > 999999999999.99 ||
          !hasPrecision(item.unitRate, 2)) {
        return null;
      }
      itemIds.add(item.id);
      const quantityMilli = BigInt(Math.round(item.quantity * 1000));
      const unitRateCents = BigInt(Math.round(item.unitRate * 100));
      subtotalCents += (quantityMilli * unitRateCents + 500n) / 1000n;
    }
    if (subtotalCents <= 0n || subtotalCents > 99999999999999n ||
        !hasPrecision(taxRate, 2)) {
      return null;
    }
    const totals = calculateFinancialTotals(items, taxRate);
    return totals.totalCents <= 99999999999999n ? totals : null;
  };
  for (const quotation of snapshot.financials.quotations) {
    if (!customerIds.has(quotation.clientId) ||
        !projectIds.has(quotation.projectId) ||
        typeof quotation.number !== 'string' ||
        quotation.number.trim().length === 0 ||
        quotation.number !== quotation.number.trim() ||
        quotation.number.length > 40 ||
        typeof quotation.title !== 'string' ||
        quotation.title.trim().length === 0 ||
        quotation.title.length > 120 ||
        !projects.some((project) =>
          project.id === quotation.projectId &&
          project.customerId === quotation.clientId) ||
        !isValidDateTime(quotation.createdAt) ||
        !isValidDateTime(quotation.updatedAt) ||
        validateItems(
          quotation.items,
          quotation.taxRate,
          quotation.currencySymbol,
        ) === null) {
      throw new HttpError(400, 'invalid_quotation');
    }
    documentNumbers.push(`quotation:${quotation.number}`);
  }
  for (const proposal of snapshot.financials.proposals) {
    if (!quotationIds.has(proposal.quotationId) ||
        !projectIds.has(proposal.projectId) ||
        !customerIds.has(proposal.clientId) ||
        !['Draft', 'Pending approval', 'Approved', 'Rejected'].includes(
          proposal.status,
        ) ||
        !snapshot.financials.quotations.some((quotation) =>
          quotation.id === proposal.quotationId &&
          quotation.projectId === proposal.projectId &&
          quotation.clientId === proposal.clientId) ||
        typeof proposal.number !== 'string' ||
        proposal.number.trim().length === 0 ||
        proposal.number !== proposal.number.trim() ||
        proposal.number.length > 40 ||
        typeof proposal.title !== 'string' ||
        proposal.title.trim().length === 0 ||
        proposal.title.length > 120 ||
        typeof proposal.brandName !== 'string' ||
        proposal.brandName.length > 120 ||
        typeof proposal.introduction !== 'string' ||
        proposal.introduction.length > 1500 ||
        typeof proposal.terms !== 'string' ||
        proposal.terms.length > 3000 ||
        typeof proposal.footer !== 'string' ||
        proposal.footer.length > 400 ||
        !Number.isInteger(proposal.accentColor) ||
        proposal.accentColor < 0 ||
        proposal.accentColor > 0xffffffff ||
        !Array.isArray(proposal.requirementRooms) ||
        proposal.requirementRooms.some((room) =>
          typeof room !== 'string' || room.trim().length === 0 ||
          room.length > 60) ||
        new Set(proposal.requirementRooms).size !==
          proposal.requirementRooms.length ||
        typeof proposal.designStyle !== 'string' ||
        proposal.designStyle.length > 120 ||
        typeof proposal.projectBrief !== 'string' ||
        proposal.projectBrief.length > 2000 ||
        (proposal.budgetMin != null &&
          (typeof proposal.budgetMin !== 'number' ||
            !Number.isFinite(proposal.budgetMin) ||
            proposal.budgetMin < 0)) ||
        (proposal.budgetMax != null &&
          (typeof proposal.budgetMax !== 'number' ||
            !Number.isFinite(proposal.budgetMax) ||
            proposal.budgetMax < 0 ||
            (proposal.budgetMin != null &&
              proposal.budgetMax < proposal.budgetMin))) ||
        (proposal.startDate != null &&
          !isValidDateTime(proposal.startDate)) ||
        (proposal.targetDate != null &&
          !isValidDateTime(proposal.targetDate)) ||
        !Array.isArray(proposal.sectionOrder) ||
        proposal.sectionOrder.length !== 6 ||
        new Set(proposal.sectionOrder).size !== 6 ||
        proposal.sectionOrder.some((section) =>
          !['cover', 'overview', 'scope', 'investment', 'terms', 'footer']
            .includes(section)) ||
        !isValidDateTime(proposal.createdAt) ||
        !isValidDateTime(proposal.updatedAt) ||
        validateItems(
          proposal.items,
          proposal.taxRate,
          proposal.currencySymbol,
        ) === null) {
      throw new HttpError(400, 'invalid_proposal');
    }
    documentNumbers.push(`proposal:${proposal.number}`);
  }
  for (const invoice of snapshot.financials.invoices) {
    const total = validateItems(
      invoice.items,
      invoice.taxRate,
      invoice.currencySymbol,
    );
    if (!approvedProposalIds.has(invoice.proposalId) ||
        !proposalIds.has(invoice.proposalId) ||
        !projectIds.has(invoice.projectId) ||
        !customerIds.has(invoice.clientId) ||
        !snapshot.financials.proposals.some((proposal) =>
          proposal.id === invoice.proposalId &&
          proposal.projectId === invoice.projectId &&
          proposal.clientId === invoice.clientId) ||
        typeof invoice.number !== 'string' ||
        invoice.number.trim().length === 0 ||
        invoice.number !== invoice.number.trim() ||
        invoice.number.length > 40 ||
        typeof invoice.title !== 'string' ||
        invoice.title.trim().length === 0 ||
        invoice.title.length > 120 ||
        typeof invoice.memo !== 'string' ||
        invoice.memo.length > 3000 ||
        !isValidDateTime(invoice.issuedAt) ||
        !isValidDateTime(invoice.dueDate) ||
        total === null ||
        typeof invoice.paidAmount !== 'number' ||
        !Number.isFinite(invoice.paidAmount) ||
        invoice.paidAmount < 0 ||
        invoice.paidAmount > Number(total?.total) ||
        !Number.isInteger(invoice.paidAmount * 100) ||
        !['Draft', 'Sent', 'Partially paid', 'Paid'].includes(invoice.status) ||
        (['Draft', 'Sent'].includes(invoice.status) &&
          invoice.paidAmount !== 0) ||
        (invoice.status === 'Partially paid' &&
          (invoice.paidAmount <= 0 || invoice.paidAmount >= total)) ||
        (invoice.status === 'Paid' && invoice.paidAmount !== total)) {
      throw new HttpError(400, 'invalid_invoice');
    }
    documentNumbers.push(`invoice:${invoice.number}`);
  }
  if (new Set(documentNumbers).size !== documentNumbers.length) {
    throw new HttpError(400, 'duplicate_financial_document_number');
  }
  const financialSettings = snapshot.financials.settings;
  if (!isRecord(financialSettings) ||
      ['quotationPrefix', 'proposalPrefix', 'invoicePrefix'].some((key) =>
        typeof financialSettings[key] !== 'string' ||
        financialSettings[key].trim().length === 0 ||
        financialSettings[key].length > 12) ||
      ['nextQuotationNumber', 'nextProposalNumber', 'nextInvoiceNumber'].some(
        (key) => !Number.isSafeInteger(financialSettings[key]) ||
          financialSettings[key] < 1,
      ) ||
      typeof financialSettings.currencySymbol !== 'string' ||
      financialSettings.currencySymbol.trim().length === 0 ||
      financialSettings.currencySymbol.length > 4 ||
      typeof financialSettings.defaultTaxRate !== 'number' ||
      !Number.isFinite(financialSettings.defaultTaxRate) ||
      financialSettings.defaultTaxRate < 0 ||
      financialSettings.defaultTaxRate > 100 ||
      typeof financialSettings.defaultTerms !== 'string' ||
      financialSettings.defaultTerms.length > 3000) {
    throw new HttpError(400, 'invalid_financial_settings');
  }
  if (snapshot.financials.templates.length === 0 ||
      snapshot.financials.templates.some((template) =>
    typeof template.name !== 'string' ||
    template.name.trim().length === 0 ||
    template.name.length > 80 ||
    typeof template.brandName !== 'string' ||
    template.brandName.length > 120 ||
    typeof template.introduction !== 'string' ||
    template.introduction.length > 1500 ||
    typeof template.terms !== 'string' ||
    template.terms.length > 3000 ||
    typeof template.footer !== 'string' ||
    template.footer.length > 400 ||
    !Number.isInteger(template.accentColor) ||
    template.accentColor < 0 ||
    template.accentColor > 0xffffffff ||
    !Array.isArray(template.sectionOrder) ||
    template.sectionOrder.length !== 6 ||
    new Set(template.sectionOrder).size !== 6 ||
    template.sectionOrder.some((section) =>
      !['cover', 'overview', 'scope', 'investment', 'terms', 'footer']
        .includes(section))) ||
      new Set(snapshot.financials.templates.map((template) =>
        template.name.trim().toLowerCase())).size !==
        snapshot.financials.templates.length) {
    throw new HttpError(400, 'invalid_financial_templates');
  }
  return snapshot;
}

function flattenSnapshot(snapshot) {
  const records = [];
  for (const [collection, [parent, field]] of collectionFields) {
    const values = parent === 'customers' || parent === 'activities' ||
        parent === 'personas' || parent === 'communications'
      ? snapshot[parent]
      : snapshot[parent][field];
    for (const value of values) {
      records.push({ collection, recordId: value.id, data: value });
    }
  }
  snapshot.pipelineStages.forEach((stage, index) => {
    records.push({
      collection: 'pipelineStages',
      recordId: `stage-${String(index).padStart(5, '0')}`,
      data: { name: stage, position: index },
    });
  });
  return records;
}

function unflattenSnapshot(settings, records) {
  const snapshot = {
    schemaVersion: 4,
    customers: [],
    pipelineStages: [],
    activities: [],
    personas: [],
    preferences: settings.preferences,
    delivery: {
      projects: [],
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
      settings: settings.financialSettings,
    },
    communications: [],
  };
  for (const { collection, data } of records) {
    if (collection === 'pipelineStages') {
      snapshot.pipelineStages.push(data);
      continue;
    }
    const [parent, field] = collectionFields.get(collection);
    if (parent === 'customers' || parent === 'activities' ||
        parent === 'personas' || parent === 'communications') {
      snapshot[parent].push(data);
    } else {
      snapshot[parent][field].push(data);
    }
  }
  snapshot.pipelineStages.sort((a, b) => a.position - b.position);
  snapshot.pipelineStages = snapshot.pipelineStages.map((stage) => stage.name);
  return snapshot;
}

function mergeSnapshotChanges(snapshot, changes) {
  if (!isRecord(changes) || Object.keys(changes).length === 0) {
    throw new HttpError(400, 'invalid_workspace_changes');
  }
  const merged = JSON.parse(JSON.stringify(snapshot));
  const changedCollections = new Set();
  let settingsChanged = false;
  for (const [path, value] of Object.entries(changes)) {
    if (!changePathCollections.has(path)) {
      throw new HttpError(400, 'invalid_workspace_changes');
    }
    if (path === 'preferences') {
      merged.preferences = value;
      settingsChanged = true;
      continue;
    }
    if (path === 'financials.settings') {
      merged.financials.settings = value;
      settingsChanged = true;
      continue;
    }
    if (path === 'pipelineStages') {
      merged.pipelineStages = value;
    } else if (path.includes('.')) {
      const [parent, field] = path.split('.');
      merged[parent][field] = value;
    } else {
      merged[path] = value;
    }
    changedCollections.add(changePathCollections.get(path));
  }
  return { snapshot: merged, changedCollections, settingsChanged };
}

async function syncCoreTables(client, workspaceId, snapshot, collections) {
  if (collections.has('customers')) {
    for (const customer of snapshot.customers) {
      await client.query(
        `INSERT INTO crm_customers
           (workspace_id, id, name, project, stage, value, email, phone,
            notes, initials, tint, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, now())
         ON CONFLICT (workspace_id, id) DO UPDATE SET
           name = EXCLUDED.name,
           project = EXCLUDED.project,
           stage = EXCLUDED.stage,
           value = EXCLUDED.value,
           email = EXCLUDED.email,
           phone = EXCLUDED.phone,
           notes = EXCLUDED.notes,
           initials = EXCLUDED.initials,
           tint = EXCLUDED.tint,
           updated_at = now()`,
        [
          workspaceId,
          customer.id,
          customer.name,
          customer.project,
          customer.stage,
          customer.value,
          customer.email,
          customer.phone,
          customer.notes,
          customer.initials,
          customer.tint,
        ],
      );
      if (customer.requirement) {
        const requirement = customer.requirement;
        await client.query(
          `INSERT INTO customer_requirements
             (workspace_id, customer_id, rooms, style, budget_min, budget_max,
              start_date, target_date, brief)
           VALUES ($1, $2, $3, $4, $5, $6, $7::date, $8::date, $9)
           ON CONFLICT (workspace_id, customer_id) DO UPDATE SET
             rooms = EXCLUDED.rooms,
             style = EXCLUDED.style,
             budget_min = EXCLUDED.budget_min,
             budget_max = EXCLUDED.budget_max,
             start_date = EXCLUDED.start_date,
             target_date = EXCLUDED.target_date,
             brief = EXCLUDED.brief`,
          [
            workspaceId,
            customer.id,
            requirement.rooms,
            requirement.style,
            requirement.budgetMin,
            requirement.budgetMax,
            requirement.startDate,
            requirement.targetDate,
            requirement.brief,
          ],
        );
      } else {
        await client.query(
          'DELETE FROM customer_requirements WHERE workspace_id = $1 AND customer_id = $2',
          [workspaceId, customer.id],
        );
      }
    }
    const customerIds = snapshot.customers.map((customer) => customer.id);
    await client.query(
      `DELETE FROM customer_requirements
       WHERE workspace_id = $1 AND NOT (customer_id = ANY($2::text[]))`,
      [workspaceId, customerIds],
    );
    await client.query(
      `DELETE FROM crm_customers
       WHERE workspace_id = $1 AND NOT (id = ANY($2::text[]))`,
      [workspaceId, customerIds],
    );
  }

  if (collections.has('projects')) {
    const projects = snapshot.delivery.projects;
    for (const project of projects) {
      await client.query(
        `INSERT INTO studio_projects
           (workspace_id, id, name, location, status, customer_id,
            target_date, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7::date, now())
         ON CONFLICT (workspace_id, id) DO UPDATE SET
           name = EXCLUDED.name,
           location = EXCLUDED.location,
           status = EXCLUDED.status,
           customer_id = EXCLUDED.customer_id,
           target_date = EXCLUDED.target_date,
           updated_at = now()`,
        [
          workspaceId,
          project.id,
          project.name,
          project.location,
          project.status,
          project.customerId,
          project.targetDate,
        ],
      );
    }
    await client.query(
      `DELETE FROM studio_projects
       WHERE workspace_id = $1 AND NOT (id = ANY($2::text[]))`,
      [workspaceId, projects.map((project) => project.id)],
    );
  }

  if (collections.has('activities')) {
    for (const activity of snapshot.activities) {
      await client.query(
        `INSERT INTO workspace_activities
           (workspace_id, id, customer_id, customer_name, kind, title, details,
            actor, occurred_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9::timestamptz)
         ON CONFLICT (workspace_id, id) DO UPDATE SET
           customer_id = EXCLUDED.customer_id,
           customer_name = EXCLUDED.customer_name,
           kind = EXCLUDED.kind,
           title = EXCLUDED.title,
           details = EXCLUDED.details,
           actor = EXCLUDED.actor,
           occurred_at = EXCLUDED.occurred_at`,
        [
          workspaceId,
          activity.id,
          activity.customerId,
          activity.customerName,
          activity.kind,
          activity.title,
          activity.details,
          activity.actor,
          activity.occurredAt,
        ],
      );
    }
    await client.query(
      `DELETE FROM workspace_activities
       WHERE workspace_id = $1 AND NOT (id = ANY($2::text[]))`,
      [workspaceId, snapshot.activities.map((activity) => activity.id)],
    );
  }

  if (collections.has('assets')) {
    for (const asset of snapshot.delivery.assets) {
      await client.query(
        `INSERT INTO project_assets
           (workspace_id, id, project_id, storage_path, name, mime_type,
            kind, caption, byte_length, added_by, added_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11::timestamptz)
         ON CONFLICT (workspace_id, id) DO UPDATE SET
           project_id = EXCLUDED.project_id,
           storage_path = EXCLUDED.storage_path,
           name = EXCLUDED.name,
           mime_type = EXCLUDED.mime_type,
           kind = EXCLUDED.kind,
           caption = EXCLUDED.caption,
           byte_length = EXCLUDED.byte_length,
           added_by = EXCLUDED.added_by,
           added_at = EXCLUDED.added_at`,
        [
          workspaceId,
          asset.id,
          asset.projectId,
          asset.storagePath,
          asset.name,
          asset.mimeType,
          asset.kind,
          asset.caption,
          asset.byteLength,
          asset.addedBy,
          asset.addedAt,
        ],
      );
    }
    await client.query(
      `DELETE FROM project_assets
       WHERE workspace_id = $1 AND NOT (id = ANY($2::text[]))`,
      [workspaceId, snapshot.delivery.assets.map((asset) => asset.id)],
    );
  }

  if (collections.has('pipelineStages')) {
    await client.query(
      'DELETE FROM workspace_pipeline_stages WHERE workspace_id = $1',
      [workspaceId],
    );
    for (const [position, name] of snapshot.pipelineStages.entries()) {
      await client.query(
        `INSERT INTO workspace_pipeline_stages (workspace_id, position, name)
         VALUES ($1, $2, $3)`,
        [workspaceId, position, name],
      );
    }
  }
  if (collections.has('preferences')) {
    await client.query(
      `INSERT INTO workspace_preferences
         (workspace_id, studio_name, default_pipeline_stage,
          active_persona_id, updated_at)
       VALUES ($1, $2, $3, $4, now())
       ON CONFLICT (workspace_id) DO UPDATE SET
         studio_name = EXCLUDED.studio_name,
         default_pipeline_stage = EXCLUDED.default_pipeline_stage,
         active_persona_id = EXCLUDED.active_persona_id,
         updated_at = now()`,
      [
        workspaceId,
        snapshot.preferences.studioName,
        snapshot.preferences.defaultPipelineStage,
        snapshot.preferences.activePersonaId,
      ],
    );
  }
}

async function syncDeliveryTables(client, workspaceId, snapshot, collections) {
  const operations = [
    {
      collection: 'tasks',
      records: snapshot.delivery.tasks,
      table: 'project_tasks',
      insert: `INSERT INTO project_tasks
        (workspace_id, id, project_id, title, assignee, due_date,
         is_complete, priority, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6::date, $7, $8, now())
       ON CONFLICT (workspace_id, id) DO UPDATE SET
         project_id = EXCLUDED.project_id,
         title = EXCLUDED.title,
         assignee = EXCLUDED.assignee,
         due_date = EXCLUDED.due_date,
         is_complete = EXCLUDED.is_complete,
         priority = EXCLUDED.priority,
         updated_at = now()`,
      values: (task) => [
        workspaceId,
        task.id,
        task.projectId,
        task.title,
        task.assignee,
        task.dueDate,
        task.isComplete,
        task.priority,
      ],
    },
    {
      collection: 'milestones',
      records: snapshot.delivery.milestones,
      table: 'project_milestones',
      insert: `INSERT INTO project_milestones
        (workspace_id, id, project_id, title, due_date, status, update_note,
         updated_at)
       VALUES ($1, $2, $3, $4, $5::date, $6, $7, $8::timestamptz)
       ON CONFLICT (workspace_id, id) DO UPDATE SET
         project_id = EXCLUDED.project_id,
         title = EXCLUDED.title,
         due_date = EXCLUDED.due_date,
         status = EXCLUDED.status,
         update_note = EXCLUDED.update_note,
         updated_at = EXCLUDED.updated_at`,
      values: (item) => [
        workspaceId,
        item.id,
        item.projectId,
        item.title,
        item.dueDate,
        item.status,
        item.update,
        item.updatedAt,
      ],
    },
    {
      collection: 'punchItems',
      records: snapshot.delivery.punchItems,
      table: 'project_punch_items',
      insert: `INSERT INTO project_punch_items
        (workspace_id, id, project_id, description, assignee, due_date,
         status, created_at)
       VALUES ($1, $2, $3, $4, $5, $6::date, $7, $8::timestamptz)
       ON CONFLICT (workspace_id, id) DO UPDATE SET
         project_id = EXCLUDED.project_id,
         description = EXCLUDED.description,
         assignee = EXCLUDED.assignee,
         due_date = EXCLUDED.due_date,
         status = EXCLUDED.status,
         created_at = EXCLUDED.created_at`,
      values: (item) => [
        workspaceId,
        item.id,
        item.projectId,
        item.description,
        item.assignee,
        item.dueDate,
        item.status,
        item.createdAt,
      ],
    },
    {
      collection: 'workLogs',
      records: snapshot.delivery.workLogs,
      table: 'project_work_logs',
      insert: `INSERT INTO project_work_logs
        (workspace_id, id, project_id, task_id, author, minutes, description,
         logged_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8::timestamptz)
       ON CONFLICT (workspace_id, id) DO UPDATE SET
         project_id = EXCLUDED.project_id,
         task_id = EXCLUDED.task_id,
         author = EXCLUDED.author,
         minutes = EXCLUDED.minutes,
         description = EXCLUDED.description,
         logged_at = EXCLUDED.logged_at`,
      values: (log) => [
        workspaceId,
        log.id,
        log.projectId,
        log.taskId,
        log.author,
        log.minutes,
        log.description,
        log.loggedAt,
      ],
    },
    {
      collection: 'attendance',
      records: snapshot.delivery.attendance,
      table: 'project_attendance',
      insert: `INSERT INTO project_attendance
        (workspace_id, id, persona_id, persona_name, attendance_date, status,
         note)
       VALUES ($1, $2, $3, $4, $5::timestamptz::date, $6, $7)
       ON CONFLICT (workspace_id, id) DO UPDATE SET
         persona_id = EXCLUDED.persona_id,
         persona_name = EXCLUDED.persona_name,
         attendance_date = EXCLUDED.attendance_date,
         status = EXCLUDED.status,
         note = EXCLUDED.note`,
      values: (entry) => [
        workspaceId,
        entry.id,
        entry.personaId,
        entry.personaName,
        entry.date,
        entry.status,
        entry.note,
      ],
    },
    {
      collection: 'approvals',
      records: snapshot.delivery.approvals,
      table: 'project_approval_requests',
      insert: `INSERT INTO project_approval_requests
        (workspace_id, id, project_id, related_proposal_id, title, details,
         requested_by, approver_persona_id, approver_name, status,
         decision_note, requested_at, decided_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11,
               $12::timestamptz, $13::timestamptz)
       ON CONFLICT (workspace_id, id) DO UPDATE SET
         project_id = EXCLUDED.project_id,
         related_proposal_id = EXCLUDED.related_proposal_id,
         title = EXCLUDED.title,
         details = EXCLUDED.details,
         requested_by = EXCLUDED.requested_by,
         approver_persona_id = EXCLUDED.approver_persona_id,
         approver_name = EXCLUDED.approver_name,
         status = EXCLUDED.status,
         decision_note = EXCLUDED.decision_note,
         requested_at = EXCLUDED.requested_at,
         decided_at = EXCLUDED.decided_at`,
      values: (approval) => [
        workspaceId,
        approval.id,
        approval.projectId,
        approval.relatedProposalId,
        approval.title,
        approval.details,
        approval.requestedBy,
        approval.approverPersonaId,
        approval.approverName,
        approval.status,
        approval.decisionNote,
        approval.requestedAt,
        approval.decidedAt,
      ],
    },
  ];

  for (const operation of operations) {
    if (!collections.has(operation.collection)) continue;
    for (const record of operation.records) {
      await client.query(operation.insert, operation.values(record));
    }
    await client.query(
      `DELETE FROM ${operation.table}
       WHERE workspace_id = $1 AND NOT (id = ANY($2::text[]))`,
      [workspaceId, operation.records.map((record) => record.id)],
    );
  }
}

async function syncCommunicationTables(
  client,
  workspaceId,
  snapshot,
  collections,
) {
  if (!collections.has('communications')) return;
  for (const entry of snapshot.communications) {
    const direction = entry.status === 'Received'
      ? 'inbound'
      : ['Email', 'WhatsApp'].includes(entry.channel)
        ? 'outbound'
        : 'internal';
    await client.query(
      `INSERT INTO communication_messages
         (workspace_id, id, idempotency_key, channel, direction, status,
          recipient, subject, body, data, created_at, updated_at)
       VALUES ($1, $2, $2, $3, $4, $5, $6, $7, $8, $9::jsonb,
               $10::timestamptz, $11::timestamptz)
       ON CONFLICT (workspace_id, id) DO UPDATE SET
         channel = EXCLUDED.channel,
         direction = EXCLUDED.direction,
         status = EXCLUDED.status,
         recipient = EXCLUDED.recipient,
         subject = EXCLUDED.subject,
         body = EXCLUDED.body,
         data = EXCLUDED.data,
         updated_at = EXCLUDED.updated_at`,
      [
        workspaceId,
        entry.id,
        entry.channel,
        direction,
        entry.status,
        entry.recipient,
        entry.subject,
        entry.body,
        JSON.stringify(entry),
        entry.createdAt,
        entry.updatedAt,
      ],
    );
  }
  await client.query(
    `DELETE FROM communication_messages
     WHERE workspace_id = $1 AND NOT (id = ANY($2::text[]))`,
    [workspaceId, snapshot.communications.map((entry) => entry.id)],
  );
}

async function syncFinanceTables(
  client,
  workspaceId,
  userId,
  snapshot,
  collections,
  previousInvoices,
  revision,
  fullSave,
) {
  const financialCollections = new Set([
    'quotations',
    'templates',
    'proposals',
    'invoices',
  ]);
  if (![...financialCollections].some((collection) =>
    collections.has(collection))) {
    return;
  }

  const documents = [
    ...snapshot.financials.quotations.map((document) => ({
      ...document,
      type: 'quotation',
      status: 'Draft',
      documentDate: document.createdAt,
      dueDate: null,
      memo: '',
    })),
    ...snapshot.financials.proposals.map((document) => ({
      ...document,
      type: 'proposal',
      documentDate: document.createdAt,
      dueDate: null,
      memo: '',
    })),
    ...snapshot.financials.invoices.map((document) => ({
      ...document,
      type: 'invoice',
      documentDate: document.issuedAt,
    })),
  ];
  const documentIds = documents.map((document) => document.id);

  for (const document of documents) {
    const previousInvoice = document.type === 'invoice'
      ? previousInvoices.get(document.id)
      : null;
    if (previousInvoice) {
      const lockedFields = [
        'number',
        'proposalId',
        'projectId',
        'projectName',
        'clientId',
        'clientName',
        'clientEmail',
        'title',
        'items',
        'taxRate',
        'currencySymbol',
        'issuedAt',
        'dueDate',
        'memo',
      ];
      const changedLockedField = lockedFields.some((field) =>
        JSON.stringify(previousInvoice[field]) !== JSON.stringify(document[field]));
      const statuses = ['Draft', 'Sent', 'Partially paid', 'Paid'];
      if (((previousInvoice.status !== 'Draft' ||
            Number(previousInvoice.paidAmount) > 0) && changedLockedField) ||
          statuses.indexOf(document.status) <
            statuses.indexOf(previousInvoice.status)) {
        throw new HttpError(409, 'issued_invoice_is_immutable');
      }
    }

    const items = document.items;
    const totals = calculateFinancialTotals(items, document.taxRate);
    await client.query(
      `INSERT INTO finance_documents
         (workspace_id, id, document_type, number, project_id, customer_id,
          title, status, currency_symbol, tax_rate, subtotal, tax_total, total,
          document_date, due_date, memo, data, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13,
               $14::timestamptz::date, $15::date, $16, $17::jsonb, now())
       ON CONFLICT (workspace_id, id) DO UPDATE SET
         document_type = EXCLUDED.document_type,
         number = EXCLUDED.number,
         project_id = EXCLUDED.project_id,
         customer_id = EXCLUDED.customer_id,
         title = EXCLUDED.title,
         status = EXCLUDED.status,
         currency_symbol = EXCLUDED.currency_symbol,
         tax_rate = EXCLUDED.tax_rate,
         subtotal = EXCLUDED.subtotal,
         tax_total = EXCLUDED.tax_total,
         total = EXCLUDED.total,
         document_date = EXCLUDED.document_date,
         due_date = EXCLUDED.due_date,
         memo = EXCLUDED.memo,
         data = EXCLUDED.data,
         updated_at = now()`,
      [
        workspaceId,
        document.id,
        document.type,
        document.number,
        document.projectId,
        document.clientId,
        document.title,
        document.status,
        document.currencySymbol,
        document.taxRate,
        totals.subtotal,
        totals.taxTotal,
        totals.total,
        document.documentDate,
        document.dueDate,
        document.memo,
        JSON.stringify(document),
      ],
    );
    await client.query(
      `DELETE FROM finance_line_items
       WHERE workspace_id = $1 AND document_id = $2`,
      [workspaceId, document.id],
    );
    for (const item of items) {
      await client.query(
        `INSERT INTO finance_line_items
           (workspace_id, document_id, id, description, quantity, unit, unit_rate)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [
          workspaceId,
          document.id,
          item.id,
          item.description,
          item.quantity,
          item.unit,
          item.unitRate,
        ],
      );
    }

    if (document.type === 'invoice') {
      const previousPaidAmount = previousInvoice
        ? Number(previousInvoice.paidAmount)
        : 0;
      const paymentDelta = roundMoney(document.paidAmount - previousPaidAmount);
      if (paymentDelta < 0 ||
          (!previousInvoice && document.paidAmount > 0 && !fullSave)) {
        throw new HttpError(409, 'invoice_payment_history_conflict');
      }
      if (paymentDelta > 0) {
        await client.query(
          `INSERT INTO invoice_payments
             (workspace_id, id, invoice_id, amount, recorded_by)
           VALUES ($1, $2, $3, $4, $5)`,
          [
            workspaceId,
            `payment-${document.id}-${revision}`,
            document.id,
            paymentDelta,
            userId,
          ],
        );
      }
    }
  }

  const stalePayments = await client.query(
    `SELECT d.id
     FROM finance_documents d
     JOIN invoice_payments p
       ON p.workspace_id = d.workspace_id AND p.invoice_id = d.id
     WHERE d.workspace_id = $1
       AND d.document_type = 'invoice'
       AND NOT (d.id = ANY($2::text[]))
     LIMIT 1`,
    [workspaceId, documentIds],
  );
  if (stalePayments.rows.length > 0) {
    throw new HttpError(409, 'invoice_with_payments_cannot_be_deleted');
  }
  await client.query(
    `DELETE FROM finance_documents
     WHERE workspace_id = $1 AND NOT (id = ANY($2::text[]))`,
    [workspaceId, documentIds],
  );

  for (const template of snapshot.financials.templates) {
    await client.query(
      `INSERT INTO finance_document_templates
         (workspace_id, id, name, data, updated_at)
       VALUES ($1, $2, $3, $4::jsonb, now())
       ON CONFLICT (workspace_id, id) DO UPDATE SET
         name = EXCLUDED.name,
         data = EXCLUDED.data,
         updated_at = now()`,
      [workspaceId, template.id, template.name, JSON.stringify(template)],
    );
  }
  await client.query(
    `DELETE FROM finance_document_templates
     WHERE workspace_id = $1 AND NOT (id = ANY($2::text[]))`,
    [workspaceId, snapshot.financials.templates.map((template) => template.id)],
  );
}

async function saveWorkspace(
  client,
  userId,
  expectedRevision,
  snapshot,
  profile = {},
  changedCollections = null,
  settingsChanged = true,
) {
  const workspace = await client.query(
    `INSERT INTO workspaces (owner_user_id, name)
     VALUES ($1, $2)
     ON CONFLICT (owner_user_id) DO UPDATE
       SET name = EXCLUDED.name, updated_at = now()
     RETURNING id`,
    [userId, snapshot.preferences.studioName],
  );
  const workspaceId = workspace.rows[0].id;
  await client.query(
    `INSERT INTO workspace_owner_profiles
       (workspace_id, owner_user_id, display_name, email)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (workspace_id) DO UPDATE
       SET display_name = EXCLUDED.display_name,
           email = EXCLUDED.email,
           updated_at = now()`,
    [
      workspaceId,
      userId,
      profile.displayName || 'Studio owner',
      profile.email || null,
    ],
  );
  const current = await client.query(
    `SELECT revision, data FROM workspace_settings
     WHERE workspace_id = $1 FOR UPDATE`,
    [workspaceId],
  );
  const currentRevision = current.rows.length === 0
    ? 0
    : Number(current.rows[0].revision);
  if (currentRevision !== expectedRevision) {
    throw new HttpError(409, 'workspace_revision_conflict');
  }

  const previousSettings = current.rows[0]?.data?.financialSettings ?? null;
  const previousFinanceRecords = await client.query(
    `SELECT collection, record_id
     FROM workspace_records
     WHERE workspace_id = $1
       AND collection = ANY($2::text[])`,
    [workspaceId, ['quotations', 'proposals', 'invoices']],
  );
  const existingDocumentIds = new Set(previousFinanceRecords.rows.map(
    (row) => `${row.collection}:${row.record_id}`,
  ));
  validateFinancialNumbering(
    snapshot,
    existingDocumentIds,
    previousSettings,
  );

  const nextRevision = currentRevision + 1;
  await client.query(
    `INSERT INTO workspace_settings (workspace_id, data, revision, updated_at)
     VALUES ($1, $2::jsonb, $3, now())
     ON CONFLICT (workspace_id) DO UPDATE
       SET data = EXCLUDED.data,
           revision = EXCLUDED.revision,
           updated_at = now()`,
    [
      workspaceId,
      JSON.stringify({
        preferences: snapshot.preferences,
        financialSettings: snapshot.financials.settings,
      }),
      nextRevision,
    ],
  );
  const fullSave = changedCollections === null;
  const collections = changedCollections
    ? [...changedCollections]
    : [...new Set(flattenSnapshot(snapshot).map((record) => record.collection))];
  const previousInvoiceRows = await client.query(
    `SELECT record_id, data
     FROM workspace_records
     WHERE workspace_id = $1 AND collection = 'invoices'`,
    [workspaceId],
  );
  const previousInvoices = new Map(
    previousInvoiceRows.rows.map((row) => [row.record_id, row.data]),
  );
  if (collections.length > 0) {
    await client.query(
      `DELETE FROM workspace_records
       WHERE workspace_id = $1 AND collection = ANY($2::text[])`,
      [workspaceId, collections],
    );
    for (const record of flattenSnapshot(snapshot)) {
      if (!collections.includes(record.collection)) continue;
      await client.query(
        `INSERT INTO workspace_records
           (workspace_id, collection, record_id, data, updated_at)
         VALUES ($1, $2, $3, $4::jsonb, now())`,
        [
          workspaceId,
          record.collection,
          record.recordId,
          JSON.stringify(record.data),
        ],
      );
    }
  }
  const coreCollections = new Set([
    ...(fullSave ? [
      'customers',
      'projects',
      'tasks',
      'milestones',
      'punchItems',
      'activities',
      'assets',
      'workLogs',
      'attendance',
      'approvals',
      'pipelineStages',
      'preferences',
    ] : collections),
    ...(settingsChanged ? ['preferences'] : []),
  ]);
  if (coreCollections.size > 0) {
    await syncCoreTables(client, workspaceId, snapshot, coreCollections);
  }
  await syncDeliveryTables(client, workspaceId, snapshot, coreCollections);
  const communicationCollections = new Set(fullSave
    ? [...collections, 'communications']
    : collections);
  await syncCommunicationTables(
    client,
    workspaceId,
    snapshot,
    communicationCollections,
  );
  const financeCollections = new Set(fullSave
    ? [...collections, 'quotations', 'templates', 'proposals', 'invoices']
    : collections);
  await syncFinanceTables(
    client,
    workspaceId,
    userId,
    snapshot,
    financeCollections,
    previousInvoices,
    nextRevision,
    fullSave,
  );
  return nextRevision;
}

async function loadWorkspace(client, userId) {
  const result = await client.query(
    `SELECT w.id, s.data, s.revision
     FROM workspaces w
     LEFT JOIN workspace_settings s ON s.workspace_id = w.id
     WHERE w.owner_user_id = $1`,
    [userId],
  );
  if (result.rows.length === 0) return { revision: 0, snapshot: null };
  const row = result.rows[0];
  if (row.data === null) return { revision: 0, snapshot: null };
  const records = await client.query(
    `SELECT collection, data
     FROM workspace_records
     WHERE workspace_id = $1
     ORDER BY collection, record_id`,
    [row.id],
  );
  return {
    revision: Number(row.revision),
    snapshot: unflattenSnapshot(row.data, records.rows),
  };
}

function getQueryValue(req, key) {
  const queryValue = req.query?.[key];
  if (typeof queryValue === 'string') return queryValue;
  if (queryValue !== undefined) {
    throw new HttpError(400, 'invalid_query_parameter');
  }
  const url = new URL(req.url || '/', 'http://localhost');
  return url.searchParams.get(key);
}

async function loadCollection(client, userId, req) {
  const collection = getQueryValue(req, 'collection');
  if (!collection || !collectionNames.has(collection)) {
    throw new HttpError(400, 'invalid_collection');
  }
  const limitValue = getQueryValue(req, 'limit');
  const offsetValue = getQueryValue(req, 'offset');
  const search = getQueryValue(req, 'search')?.trim() || null;
  const limit = limitValue == null ? 50 : Number(limitValue);
  const offset = offsetValue == null ? 0 : Number(offsetValue);
  if (!Number.isInteger(limit) || limit < 1 || limit > 100 ||
      !Number.isInteger(offset) || offset < 0 ||
      (search !== null && search.length > 80)) {
    throw new HttpError(400, 'invalid_pagination');
  }

  const workspaceResult = await client.query(
    `SELECT w.id, s.revision
     FROM workspaces w
     LEFT JOIN workspace_settings s ON s.workspace_id = w.id
     WHERE w.owner_user_id = $1`,
    [userId],
  );
  if (workspaceResult.rows.length === 0) {
    return {
      collection,
      records: [],
      total: 0,
      nextOffset: null,
      revision: 0,
      workspaceExists: false,
    };
  }
  const workspaceId = workspaceResult.rows[0].id;
  const workspaceRevision = workspaceResult.rows[0].revision;
  const workspaceExists = workspaceRevision != null;
  const revision = Number(workspaceRevision || 0);
  if (collection === 'invoicePayments') {
    const count = await client.query(
      `SELECT count(*)::integer AS total
       FROM invoice_payments p
       JOIN finance_documents d
         ON d.workspace_id = p.workspace_id AND d.id = p.invoice_id
       WHERE p.workspace_id = $1
         AND (
           $2::text IS NULL OR
           position(lower($2) in lower(d.number || ' ' || p.invoice_id)) > 0
         )`,
      [workspaceId, search],
    );
    const result = await client.query(
      `SELECT p.id,
              p.invoice_id AS "invoiceId",
              d.number AS "invoiceNumber",
              p.amount::text AS amount,
              p.recorded_at AS "recordedAt",
              p.recorded_by AS "recordedBy"
       FROM invoice_payments p
       JOIN finance_documents d
         ON d.workspace_id = p.workspace_id AND d.id = p.invoice_id
       WHERE p.workspace_id = $1
         AND (
           $2::text IS NULL OR
           position(lower($2) in lower(d.number || ' ' || p.invoice_id)) > 0
         )
       ORDER BY p.recorded_at DESC, p.id
       LIMIT $3 OFFSET $4`,
      [workspaceId, search, limit, offset],
    );
    const total = count.rows[0].total;
    return {
      collection,
      records: result.rows,
      total,
      nextOffset: offset + result.rows.length < total
        ? offset + result.rows.length
        : null,
      revision,
      workspaceExists,
    };
  }
  if (collection === 'preferences' || collection === 'financialSettings') {
    const settings = await client.query(
      'SELECT data FROM workspace_settings WHERE workspace_id = $1',
      [workspaceId],
    );
    return {
      collection,
      records: settings.rows.length === 0
        ? []
        : [settings.rows[0].data[
            collection === 'preferences' ? 'preferences' : 'financialSettings'
          ]],
      total: settings.rows.length === 0 ? 0 : 1,
      nextOffset: null,
      revision,
      workspaceExists,
    };
  }

  const count = await client.query(
    `SELECT count(*)::integer AS total
     FROM workspace_records
     WHERE workspace_id = $1
       AND collection = $2
       AND (
         $3::text IS NULL OR
         position(lower($3) in lower(data::text)) > 0
       )`,
    [workspaceId, collection, search],
  );
  const result = await client.query(
    `SELECT data
     FROM workspace_records
     WHERE workspace_id = $1
       AND collection = $2
       AND (
         $3::text IS NULL OR
         position(lower($3) in lower(data::text)) > 0
       )
     ORDER BY record_id
     LIMIT $4 OFFSET $5`,
    [workspaceId, collection, search, limit, offset],
  );
  const total = count.rows[0].total;
  const nextOffset = offset + result.rows.length < total
    ? offset + result.rows.length
    : null;
  return {
    collection,
    records: result.rows.map((row) => row.data),
    total,
    nextOffset,
    revision,
    workspaceExists,
  };
}

function createWorkspaceHandler({
  authenticate = authenticateRequest,
  withTransaction = withUserTransaction,
  rateLimit = null,
  logger = console.error,
} = {}) {
  return async function workspaceHandler(req, res) {
    const requestId = attachRequestId(res);
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Vary', 'Authorization');
    if (!['GET', 'PUT', 'PATCH'].includes(req.method)) {
      res.setHeader('Allow', 'GET, PUT, PATCH');
      return res.status(405).json({ error: 'method_not_allowed' });
    }

    try {
      const { userId, profile } = await authenticate(req);
      if (rateLimit) {
        await rateLimit(
          userId,
          req.method === 'GET' ? 'workspace_read' : 'workspace_write',
          {
            limit: req.method === 'GET' ? 120 : 30,
            windowSeconds: 60,
          },
        );
      }
      if (req.method === 'GET') {
        const result = await withTransaction(
          userId,
          (client) =>
            getQueryValue(req, 'collection') === null
              ? loadWorkspace(client, userId)
              : loadCollection(client, userId, req),
        );
        return res.status(200).json(result);
      }

      const bodySize = Buffer.byteLength(JSON.stringify(req.body ?? null));
      if (bodySize > maximumRequestBytes) {
        throw new HttpError(413, 'workspace_too_large');
      }
      if (!isRecord(req.body) ||
          !Number.isSafeInteger(req.body.revision) ||
          req.body.revision < 0) {
        throw new HttpError(400, 'invalid_workspace_revision');
      }
      const revision = await withTransaction(userId, async (client) => {
        if (req.method === 'PUT') {
          const snapshot = validateSnapshot(req.body.snapshot, userId);
          return saveWorkspace(
            client,
            userId,
            req.body.revision,
            snapshot,
            profile,
          );
        }

        const current = await loadWorkspace(client, userId);
        if (current.snapshot === null) {
          throw new HttpError(404, 'workspace_not_found');
        }
        if (current.revision !== req.body.revision) {
          throw new HttpError(409, 'workspace_revision_conflict');
        }
        const changes = mergeSnapshotChanges(
          current.snapshot,
          req.body.changes,
        );
        const snapshot = validateSnapshot(changes.snapshot, userId);
        return saveWorkspace(
          client,
          userId,
          req.body.revision,
          snapshot,
          profile,
          changes.changedCollections,
          changes.settingsChanged,
        );
      });
      return res.status(200).json({ revision });
    } catch (error) {
      if (respondToRateLimit(error, res)) return;
      if (error instanceof HttpError ||
          (Number.isInteger(error?.statusCode) && error.statusCode === 401)) {
        const statusCode = error.statusCode;
        const code = error instanceof HttpError
          ? error.code
          : 'unauthorized';
        return res.status(statusCode).json({ error: code });
      }
      if (error?.code === '23505' &&
          ['finance_documents_number_unique',
            'finance_document_templates_name_unique'].includes(
            error.constraint)) {
        return res.status(409).json({
          error: error.constraint === 'finance_documents_number_unique'
            ? 'duplicate_financial_document_number'
            : 'duplicate_financial_template_name',
        });
      }
      logger('Workspace API request failed.', {
        requestId,
        errorName: error instanceof Error ? error.name : 'UnknownError',
        ...(typeof error?.code === 'string' ? { errorCode: error.code } : {}),
      });
      return res.status(500).json({ error: 'internal_server_error' });
    }
  };
}

const handler = createWorkspaceHandler({
  rateLimit: enforceUserRateLimit,
});
Object.assign(handler, {
  HttpError,
  createWorkspaceHandler,
  flattenSnapshot,
  loadWorkspace,
  saveWorkspace,
  unflattenSnapshot,
  validateSnapshot,
});

module.exports = handler;
