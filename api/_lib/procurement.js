const approvalPermissions = new Set([
  'procurement.approve',
  'manageFinancials',
]);

function isRecord(value) {
  return value !== null && typeof value === 'object' &&
    !Array.isArray(value);
}

function isValidDateTime(value) {
  return typeof value === 'string' &&
    Number.isFinite(Date.parse(value));
}

function validPolicy(policy) {
  const validSteps = (steps) =>
    Array.isArray(steps) &&
    steps.length > 0 &&
    steps.length <= 5 &&
    steps.every((step) => approvalPermissions.has(step)) &&
    new Set(steps).size === steps.length;
  return isRecord(policy) &&
    validSteps(policy.requisitionPermissions) &&
    validSteps(policy.purchaseOrderPermissions);
}

function approvalStatusMatches(status, steps) {
  if (!Array.isArray(steps) || steps.length > 5) return false;
  const seenPermissions = new Set();
  let pendingSeen = false;
  let rejectedSeen = false;
  for (const step of steps) {
    if (!isRecord(step) ||
        !approvalPermissions.has(step.permission) ||
        seenPermissions.has(step.permission) ||
        !['Pending', 'Approved', 'Rejected'].includes(step.status) ||
        typeof step.decisionNote !== 'string' ||
        step.decisionNote.length > 500 ||
        step.status === 'Pending' &&
          (step.decidedAt != null || step.decisionNote.length > 0) ||
        step.status !== 'Pending' && !isValidDateTime(step.decidedAt)) {
      return false;
    }
    seenPermissions.add(step.permission);
    if (pendingSeen && step.status !== 'Pending' ||
        rejectedSeen && step.status === 'Approved') {
      return false;
    }
    if (step.status === 'Pending') pendingSeen = true;
    if (step.status === 'Rejected') rejectedSeen = true;
  }
  if (status === 'Draft') return steps.length === 0;
  if (status === 'Pending approval') {
    return steps.length > 0 && pendingSeen && !rejectedSeen;
  }
  if (status === 'Approved') {
    return steps.length > 0 &&
      steps.every((step) => step.status === 'Approved');
  }
  return status === 'Rejected' && rejectedSeen;
}

function lineTotal(quantityMilli, unitPriceMinor) {
  if (!Number.isSafeInteger(quantityMilli) ||
      !Number.isSafeInteger(unitPriceMinor)) {
    return null;
  }
  const product = quantityMilli * unitPriceMinor;
  if (!Number.isSafeInteger(product)) return null;
  const total = Math.round(product / 1000);
  return Number.isSafeInteger(total) ? total : null;
}

function stableStringify(value) {
  if (Array.isArray(value)) {
    return `[${value.map(stableStringify).join(',')}]`;
  }
  if (isRecord(value)) {
    const entries = Object.keys(value).sort().map((key) =>
      `${JSON.stringify(key)}:${stableStringify(value[key])}`);
    return `{${entries.join(',')}}`;
  }
  return JSON.stringify(value);
}

function validateProcurementSnapshot(snapshot, HttpError) {
  const fail = (code) => {
    throw new HttpError(400, code);
  };
  if (!validPolicy(snapshot.preferences.procurementApprovalPolicy)) {
    fail('invalid_procurement_approval_policy');
  }

  const projects = new Set(
    snapshot.delivery.projects.map((project) => project.id),
  );
  const materials = new Map(
    snapshot.delivery.materials.map((material) => [material.id, material]),
  );
  const vendors = new Map(
    snapshot.delivery.vendors.map((vendor) => [vendor.id, vendor]),
  );
  const requisitions = new Map();
  for (const requisition of snapshot.delivery.requisitions) {
    const items = requisition.items;
    if (!projects.has(requisition.projectId) ||
        typeof requisition.title !== 'string' ||
        requisition.title.trim().length === 0 ||
        requisition.title.length > 160 ||
        typeof requisition.notes !== 'string' ||
        requisition.notes.length > 2000 ||
        !['Draft', 'Pending approval', 'Approved', 'Rejected']
          .includes(requisition.status) ||
        !isValidDateTime(requisition.createdAt) ||
        (requisition.requiredBy != null &&
          !isValidDateTime(requisition.requiredBy)) ||
        !approvalStatusMatches(requisition.status, requisition.approvalSteps) ||
        !Array.isArray(items) ||
        items.length === 0 ||
        items.length > 100 ||
        items.some((item) =>
          !isRecord(item) ||
          typeof item.id !== 'string' ||
          item.id.trim().length === 0 ||
          typeof item.materialId !== 'string' ||
          !materials.has(item.materialId) ||
          typeof item.name !== 'string' ||
          item.name.trim().length === 0 ||
          item.name.length > 160 ||
          typeof item.unit !== 'string' ||
          item.unit.length === 0 ||
          item.unit.length > 20 ||
          !Number.isSafeInteger(item.quantityMilli) ||
          item.quantityMilli < 1 ||
          item.quantityMilli > 1000000000 ||
          typeof item.specification !== 'string' ||
          item.specification.length > 500) ||
        new Set(items.map((item) => item.id)).size !== items.length) {
      fail('invalid_requisition');
    }
    requisitions.set(requisition.id, requisition);
  }

  const rfqs = new Map();
  for (const rfq of snapshot.delivery.rfqs) {
    const requisition = requisitions.get(rfq.requisitionId);
    if (!projects.has(rfq.projectId) ||
        !requisition ||
        requisition.projectId !== rfq.projectId ||
        requisition.status !== 'Approved' ||
        !Array.isArray(rfq.vendorIds) ||
        rfq.vendorIds.length === 0 ||
        rfq.vendorIds.length > 100 ||
        rfq.vendorIds.some((vendorId) =>
          typeof vendorId !== 'string' ||
          !vendors.has(vendorId) ||
          vendors.get(vendorId).kind !== 'Supplier') ||
        new Set(rfq.vendorIds).size !== rfq.vendorIds.length ||
        (rfq.quoteDueAt != null && !isValidDateTime(rfq.quoteDueAt)) ||
        typeof rfq.notes !== 'string' ||
        rfq.notes.length > 2000 ||
        !['Draft', 'Issued', 'Closed'].includes(rfq.status) ||
        !isValidDateTime(rfq.createdAt)) {
      fail('invalid_rfq');
    }
    rfqs.set(rfq.id, rfq);
  }

  const quotes = new Map();
  const selectedQuoteCounts = new Map();
  for (const quote of snapshot.delivery.vendorQuotes) {
    const rfq = rfqs.get(quote.rfqId);
    const requisition = rfq && requisitions.get(rfq.requisitionId);
    const requiredLineIds = new Set(
      requisition?.items.map((item) => item.id) || [],
    );
    if (!Array.isArray(quote.items)) fail('invalid_vendor_quote');
    const lineIds = quote.items.map((item) =>
      isRecord(item) ? item.requisitionLineId : null);
    const calculatedTotal = quote.items.reduce((total, item) => {
      const requestLine = requisition?.items.find(
        (line) => line.id === item?.requisitionLineId,
      );
      const amount = requestLine
        ? lineTotal(requestLine.quantityMilli, item?.unitPriceMinor)
        : null;
      return Number.isSafeInteger(total) && Number.isSafeInteger(amount)
        ? total + amount
        : Number.NaN;
    }, 0);
    if (!rfq ||
        quote.projectId !== rfq.projectId ||
        !rfq.vendorIds.includes(quote.vendorId) ||
        !['Submitted', 'Selected', 'Not selected'].includes(quote.status) ||
        typeof quote.currency !== 'string' ||
        !/^[A-Z]{3}$/.test(quote.currency) ||
        quote.items.length !== requiredLineIds.size ||
        lineIds.some((id) => !requiredLineIds.has(id)) ||
        new Set(lineIds).size !== lineIds.length ||
        quote.items.some((item) =>
          !Number.isSafeInteger(item.unitPriceMinor) ||
          item.unitPriceMinor < 0 ||
          item.unitPriceMinor > 1000000000000) ||
        !Number.isSafeInteger(quote.totalMinor) ||
        quote.totalMinor <= 0 ||
        quote.totalMinor !== calculatedTotal ||
        (quote.validUntil != null && !isValidDateTime(quote.validUntil)) ||
        (quote.deliveryDays != null &&
          (!Number.isInteger(quote.deliveryDays) ||
            quote.deliveryDays < 0 || quote.deliveryDays > 3650)) ||
        typeof quote.terms !== 'string' ||
        quote.terms.length > 2000 ||
        !isValidDateTime(quote.submittedAt)) {
      fail('invalid_vendor_quote');
    }
    if (quote.status === 'Selected') {
      selectedQuoteCounts.set(
        quote.rfqId,
        (selectedQuoteCounts.get(quote.rfqId) || 0) + 1,
      );
    }
    quotes.set(quote.id, quote);
  }
  if ([...selectedQuoteCounts.values()].some((count) => count > 1)) {
    fail('multiple_selected_vendor_quotes');
  }

  const orderedQuoteIds = new Set();
  for (const order of snapshot.delivery.purchaseOrders) {
    const requisition = requisitions.get(order.requisitionId);
    const rfq = rfqs.get(order.rfqId);
    const quote = quotes.get(order.quoteId);
    const expectedLines = requisition && quote
      ? requisition.items.map((requestLine) => {
          const quoteLine = quote.items.find(
            (item) => item.requisitionLineId === requestLine.id,
          );
          const lineAmount = quoteLine
            ? lineTotal(requestLine.quantityMilli, quoteLine.unitPriceMinor)
            : null;
          return {
            requisitionLineId: requestLine.id,
            description: requestLine.name,
            unit: requestLine.unit,
            quantityMilli: requestLine.quantityMilli,
            unitPriceMinor: quoteLine?.unitPriceMinor,
            lineTotalMinor: lineAmount,
          };
        })
      : [];
    if (!Array.isArray(order.items)) fail('invalid_purchase_order');
    const computedTotal = order.items.reduce(
      (total, item) => total + item?.lineTotalMinor,
      0,
    );
    if (!requisition ||
        requisition.projectId !== order.projectId ||
        requisition.status !== 'Approved' ||
        !rfq ||
        rfq.projectId !== order.projectId ||
        rfq.requisitionId !== requisition.id ||
        !quote ||
        quote.status !== 'Selected' ||
        quote.rfqId !== rfq.id ||
        quote.vendorId !== order.vendorId ||
        quote.currency !== order.currency ||
        !['Draft', 'Pending approval', 'Approved', 'Rejected', 'Issued',
          'Cancelled'].includes(order.status) ||
        order.items.length !== expectedLines.length ||
        order.items.some((item, index) =>
          !isRecord(item) ||
          stableStringify(item) !== stableStringify(expectedLines[index])) ||
        !Number.isSafeInteger(order.totalMinor) ||
        order.totalMinor <= 0 ||
        order.totalMinor !== computedTotal ||
        typeof order.notes !== 'string' ||
        order.notes.length > 2000 ||
        !approvalStatusMatches(
          order.status === 'Draft'
            ? 'Draft'
            : order.status === 'Pending approval'
              ? 'Pending approval'
              : order.status === 'Rejected'
                ? 'Rejected'
                : 'Approved',
          order.approvalSteps,
        ) ||
        !isValidDateTime(order.createdAt) ||
        (order.status === 'Issued'
          ? !isValidDateTime(order.issuedAt)
          : order.issuedAt != null)) {
      fail('invalid_purchase_order');
    }
    if (orderedQuoteIds.has(order.quoteId)) {
      fail('duplicate_purchase_order_quote');
    }
    orderedQuoteIds.add(order.quoteId);
  }
}

function isSameExcept(first, second, fields) {
  const normalizedFirst = { ...first };
  const normalizedSecond = { ...second };
  for (const field of fields) {
    normalizedFirst[field] = null;
    normalizedSecond[field] = null;
  }
  return stableStringify(normalizedFirst) ===
    stableStringify(normalizedSecond);
}

function hasScopedPermission(access, projectId, permission, hasPermission) {
  if (hasPermission(access, permission)) return true;
  return (access.projectPermissions?.get(projectId) || [])
    .includes(permission);
}

function validateApprovalDecision(
  previous,
  next,
  access,
  hasPermission,
  WorkspaceAccessError,
) {
  if (!isSameExcept(previous, next, ['status', 'approvalSteps'])) return null;
  const before = previous.approvalSteps;
  const after = next.approvalSteps;
  if (!Array.isArray(before) || before.length === 0 ||
      !Array.isArray(after) || after.length !== before.length) {
    return null;
  }
  const stepIndex = before.findIndex((step) => step.status === 'Pending');
  if (stepIndex < 0) return null;
  const oldStep = before[stepIndex];
  const newStep = after[stepIndex];
  if (newStep.status === 'Pending' ||
      !['Approved', 'Rejected'].includes(newStep.status)) {
    return null;
  }
  if (!hasScopedPermission(
    access,
    previous.projectId,
    oldStep.permission,
    hasPermission,
  )) {
    throw new WorkspaceAccessError(403, 'permission_denied');
  }
  for (let index = 0; index < before.length; index += 1) {
    if (index === stepIndex) continue;
    if (stableStringify(before[index]) !== stableStringify(after[index])) {
      return null;
    }
  }
  if (oldStep.permission !== newStep.permission ||
      oldStep.status !== 'Pending' ||
      typeof newStep.decisionNote !== 'string' ||
      newStep.decisionNote.length > 500 ||
      !isValidDateTime(newStep.decidedAt)) {
    return null;
  }
  if (newStep.status === 'Rejected') {
    return next.status === 'Rejected'
      ? {
          action: 'approval_rejected',
          fromStatus: previous.status,
          toStatus: next.status,
          details: {
            permission: oldStep.permission,
            decisionNote: newStep.decisionNote,
          },
        }
      : null;
  }
  const allApproved = after.every((step) => step.status === 'Approved');
  const expectedStatus = allApproved ? 'Approved' : 'Pending approval';
  return next.status === expectedStatus
    ? {
        action: 'approval_granted',
        fromStatus: previous.status,
        toStatus: next.status,
        details: { permission: oldStep.permission },
      }
    : null;
}

function validateProcurementTransitions(
  previousSnapshot,
  nextSnapshot,
  access,
  hasPermission,
  HttpError,
  WorkspaceAccessError,
) {
  const events = [];
  const fail = (code) => {
    throw new HttpError(400, code);
  };
  const requirePermission = (projectId, permission) => {
    if (!hasScopedPermission(access, projectId, permission, hasPermission)) {
      throw new WorkspaceAccessError(403, 'permission_denied');
    }
  };
  const policy = previousSnapshot?.preferences?.procurementApprovalPolicy ||
    nextSnapshot.preferences.procurementApprovalPolicy;
  const policyChanges = [
    ['requisitions', previousSnapshot?.delivery?.requisitions || [],
      nextSnapshot.delivery.requisitions, 'requisitionPermissions'],
    ['rfqs', previousSnapshot?.delivery?.rfqs || [],
      nextSnapshot.delivery.rfqs, null],
    ['vendorQuotes', previousSnapshot?.delivery?.vendorQuotes || [],
      nextSnapshot.delivery.vendorQuotes, null],
    ['purchaseOrders', previousSnapshot?.delivery?.purchaseOrders || [],
      nextSnapshot.delivery.purchaseOrders, 'purchaseOrderPermissions'],
  ];
  const nextPurchaseOrders = nextSnapshot.delivery.purchaseOrders;
  for (const [collection, previousRecords, nextRecords, policyKey] of
    policyChanges) {
    const previousById = new Map(
      previousRecords.map((record) => [record.id, record]),
    );
    const nextById = new Map(nextRecords.map((record) => [record.id, record]));
    for (const id of new Set([...previousById.keys(), ...nextById.keys()])) {
      const previous = previousById.get(id);
      const next = nextById.get(id);
      if (stableStringify(previous) === stableStringify(next)) continue;
      const projectId = next?.projectId ?? previous?.projectId;
      if (typeof projectId !== 'string') fail('invalid_procurement_project');
      if (!previous) {
        requirePermission(projectId, 'procurement.manage');
        const expectedStatus = collection === 'vendorQuotes'
          ? 'Submitted'
          : 'Draft';
        if (next.status !== expectedStatus) {
          fail('invalid_procurement_initial_state');
        }
        if (collection === 'rfqs') {
          const requisition = nextSnapshot.delivery.requisitions.find(
            (record) => record.id === next.requisitionId,
          );
          if (!requisition ||
              requisition.status !== 'Approved' ||
              previousSnapshot?.delivery?.requisitions?.find(
                (record) => record.id === next.requisitionId,
              )?.status !== 'Approved') {
            fail('requisition_not_approved');
          }
        }
        if (collection === 'vendorQuotes') {
          const rfq = nextSnapshot.delivery.rfqs.find(
            (record) => record.id === next.rfqId,
          );
          if (!rfq ||
              rfq.status !== 'Issued' ||
              previousSnapshot?.delivery?.rfqs?.find(
                (record) => record.id === next.rfqId,
              )?.status !== 'Issued') {
            fail('rfq_not_issued');
          }
        }
        if (collection === 'purchaseOrders') {
          const quote = previousSnapshot?.delivery?.vendorQuotes?.find(
            (record) => record.id === next.quoteId,
          );
          if (!quote || quote.status !== 'Selected') {
            fail('vendor_quote_not_selected');
          }
        }
        events.push({
          collection,
          recordId: id,
          projectId,
          action: 'created',
          fromStatus: null,
          toStatus: next.status,
          details: collection === 'vendorQuotes'
            ? {
                vendorId: next.vendorId,
                totalMinor: next.totalMinor,
                currency: next.currency,
              }
            : collection === 'purchaseOrders'
              ? {
                  vendorId: next.vendorId,
                  quoteId: next.quoteId,
                  totalMinor: next.totalMinor,
                  currency: next.currency,
                }
              : {},
        });
        continue;
      }
      if (!next) {
        requirePermission(projectId, 'procurement.manage');
        if (previous.status !== 'Draft' ||
            collection === 'vendorQuotes' ||
            collection === 'rfqs' &&
              previousSnapshot.delivery.vendorQuotes.some(
                (quote) => quote.rfqId === previous.id,
              ) ||
            collection === 'requisitions' &&
              previousSnapshot.delivery.rfqs.some(
                (rfq) => rfq.requisitionId === previous.id,
              ) ||
            collection === 'purchaseOrders' &&
              nextPurchaseOrders.some((order) =>
                order.quoteId === previous.quoteId)) {
          fail('procurement_record_cannot_be_deleted');
        }
        events.push({
          collection,
          recordId: id,
          projectId,
          action: 'draft_deleted',
          fromStatus: previous.status,
          toStatus: null,
          details: {},
        });
        continue;
      }
      if (previous.projectId !== next.projectId) {
        fail('procurement_project_immutable');
      }

      const manage = () => requirePermission(projectId, 'procurement.manage');
      if (collection === 'requisitions') {
        if (previous.status === 'Draft' && next.status === 'Draft') {
          manage();
          continue;
        }
        if (previous.status === 'Draft' &&
            next.status === 'Pending approval' &&
            isSameExcept(previous, next, ['status', 'approvalSteps']) &&
            stableStringify(next.approvalSteps) === stableStringify(
              policy[policyKey].map((permission) => ({
                permission,
                status: 'Pending',
                decisionNote: '',
                decidedAt: null,
              })),
            )) {
          manage();
          events.push({
            collection,
            recordId: id,
            projectId,
            action: 'submitted_for_approval',
            fromStatus: previous.status,
            toStatus: next.status,
            details: {},
          });
          continue;
        }
        if (previous.status === 'Pending approval') {
          const decision = validateApprovalDecision(
            previous,
            next,
            access,
            hasPermission,
            WorkspaceAccessError,
          );
          if (decision) {
            events.push({
              collection,
              recordId: id,
              projectId,
              ...decision,
            });
            continue;
          }
        }
        fail('invalid_requisition_transition');
      }

      if (collection === 'rfqs') {
        if (previous.status === 'Draft' && next.status === 'Draft') {
          manage();
          continue;
        }
        if (previous.status === 'Draft' && next.status === 'Issued' &&
            isSameExcept(previous, next, ['status'])) {
          manage();
          events.push({
            collection,
            recordId: id,
            projectId,
            action: 'rfq_issued',
            fromStatus: previous.status,
            toStatus: next.status,
            details: { vendorIds: next.vendorIds },
          });
          continue;
        }
        if (previous.status === 'Issued' && next.status === 'Closed' &&
            isSameExcept(previous, next, ['status'])) {
          manage();
          events.push({
            collection,
            recordId: id,
            projectId,
            action: 'rfq_closed',
            fromStatus: previous.status,
            toStatus: next.status,
            details: {},
          });
          continue;
        }
        fail('invalid_rfq_transition');
      }

      if (collection === 'vendorQuotes') {
        if (isSameExcept(previous, next, ['status']) &&
            ['Submitted', 'Selected', 'Not selected'].includes(next.status) &&
            previous.status !== next.status) {
          manage();
          if (previous.status === 'Selected' &&
              nextPurchaseOrders.some((order) =>
                order.quoteId === previous.id)) {
            fail('selected_quote_has_purchase_order');
          }
          if (next.status === 'Selected' &&
              nextSnapshot.delivery.vendorQuotes.some((quote) =>
                quote.id !== next.id &&
                quote.rfqId === next.rfqId &&
                quote.status === 'Selected')) {
            fail('another_vendor_quote_selected');
          }
          if (!(
            previous.status === 'Submitted' ||
            (previous.status === 'Selected' &&
              next.status === 'Not selected') ||
            (previous.status === 'Not selected' &&
              next.status === 'Selected')
          )) {
            fail('invalid_vendor_quote_transition');
          }
          events.push({
            collection,
            recordId: id,
            projectId,
            action: next.status === 'Selected'
              ? 'quote_selected'
              : 'quote_not_selected',
            fromStatus: previous.status,
            toStatus: next.status,
            details: {
              vendorId: next.vendorId,
              totalMinor: next.totalMinor,
              currency: next.currency,
            },
          });
          continue;
        }
        fail('vendor_quote_immutable');
      }

      if (collection === 'purchaseOrders') {
        if (previous.status === 'Draft' && next.status === 'Draft') {
          manage();
          continue;
        }
        if (previous.status === 'Draft' &&
            next.status === 'Pending approval' &&
            isSameExcept(previous, next, ['status', 'approvalSteps']) &&
            stableStringify(next.approvalSteps) === stableStringify(
              policy[policyKey].map((permission) => ({
                permission,
                status: 'Pending',
                decisionNote: '',
                decidedAt: null,
              })),
            )) {
          manage();
          events.push({
            collection,
            recordId: id,
            projectId,
            action: 'submitted_for_approval',
            fromStatus: previous.status,
            toStatus: next.status,
            details: {
              vendorId: next.vendorId,
              quoteId: next.quoteId,
              totalMinor: next.totalMinor,
              currency: next.currency,
            },
          });
          continue;
        }
        if (previous.status === 'Pending approval') {
          const decision = validateApprovalDecision(
            previous,
            next,
            access,
            hasPermission,
            WorkspaceAccessError,
          );
          if (decision) {
            events.push({
              collection,
              recordId: id,
              projectId,
              ...decision,
            });
            continue;
          }
        }
        if (previous.status === 'Approved' && next.status === 'Issued' &&
            isSameExcept(previous, next, ['status', 'issuedAt']) &&
            isValidDateTime(next.issuedAt)) {
          manage();
          events.push({
            collection,
            recordId: id,
            projectId,
            action: 'purchase_order_issued',
            fromStatus: previous.status,
            toStatus: next.status,
            details: {
              vendorId: next.vendorId,
              quoteId: next.quoteId,
              totalMinor: next.totalMinor,
              currency: next.currency,
            },
          });
          continue;
        }
        if (previous.status === 'Approved' &&
            next.status === 'Cancelled' &&
            isSameExcept(previous, next, ['status'])) {
          manage();
          events.push({
            collection,
            recordId: id,
            projectId,
            action: 'purchase_order_cancelled',
            fromStatus: previous.status,
            toStatus: next.status,
            details: { vendorId: next.vendorId, totalMinor: next.totalMinor },
          });
          continue;
        }
        fail('invalid_purchase_order_transition');
      }
    }
  }

  const previousPolicy = previousSnapshot?.preferences
    ?.procurementApprovalPolicy;
  const nextPolicy = nextSnapshot.preferences.procurementApprovalPolicy;
  if (stableStringify(previousPolicy) !== stableStringify(nextPolicy)) {
    if (!hasPermission(access, 'configureWorkspace')) {
      throw new WorkspaceAccessError(403, 'permission_denied');
    }
    const pending = [
      ...nextSnapshot.delivery.requisitions,
      ...nextSnapshot.delivery.purchaseOrders,
    ].some((record) => record.status === 'Pending approval');
    if (pending) fail('procurement_approval_policy_in_use');
  }
  return events;
}

module.exports = {
  validateProcurementSnapshot,
  validateProcurementTransitions,
};
