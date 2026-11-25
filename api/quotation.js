const { randomUUID } = require('node:crypto');
const { authenticateRequest } = require('./_lib/auth');
const {
  requirePermission,
  WorkspaceAccessError,
  withWorkspaceTransaction,
} = require('./_lib/database');
const { getWorkspaceId } = require('./_lib/workspace_context');
const {
  enforceUserRateLimit,
  respondToRateLimit,
} = require('./_lib/rate_limit');
const { attachRequestId } = require('./_lib/request_id');
const {
  calculateQuotationLine,
  calculateQuotationTotals,
  amountInWords,
} = require('./_lib/quotation_calculator');

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

function text(value, maxLength = 120) {
  return typeof value === 'string' &&
    value.trim().length > 0 &&
    value.length <= maxLength
    ? value.trim()
    : null;
}

function validDate(value) {
  return value === null ||
    (typeof value === 'string' &&
      /^\d{4}-\d{2}-\d{2}$/.test(value) &&
      Number.isFinite(Date.parse(value)));
}

async function nextQuotationNumber(client, workspaceId) {
  const result = await client.query(
    `SELECT number
     FROM quotation_documents
     WHERE workspace_id = $1
       AND number ~ '^QT-[0-9]+$'
     ORDER BY length(number) DESC, number DESC
     LIMIT 1
     FOR UPDATE`,
    [workspaceId],
  );
  let sequence = 1;
  if (result.rows.length > 0) {
    const match = /^QT-(\d+)$/.exec(result.rows[0].number);
    if (match) sequence = Number(match[1]) + 1;
  }
  return `QT-${String(sequence).padStart(6, '0')}`;
}

function validatePayload(body) {
  if (!isRecord(body)) throw new HttpError(400, 'invalid_quotation');
  const title = text(body.title, 160);
  if (!title ||
      typeof body.currencySymbol !== 'string' ||
      body.currencySymbol.length > 10 ||
      !validDate(body.validityDate) ||
      !Array.isArray(body.sections) ||
      body.sections.length > 100 ||
      !Number.isFinite(Number(body.taxRate)) ||
      Number(body.taxRate) < 0 || Number(body.taxRate) > 100 ||
      !Number.isFinite(Number(body.discountPercent)) ||
      Number(body.discountPercent) < 0 ||
      Number(body.discountPercent) > 100) {
    throw new HttpError(400, 'invalid_quotation');
  }
  if (body.sections.some((section) =>
    !isRecord(section) ||
    !text(section.name, 160) ||
    !['room', 'service', 'other'].includes(section.type) ||
    !Array.isArray(section.lines) ||
    section.lines.length > 200)) {
    throw new HttpError(400, 'invalid_quotation_sections');
  }
  return body;
}

async function calculateSnapshot(client, workspaceId, body) {
  validatePayload(body);
  const calculatedLines = [];
  for (const [sectionIndex, section] of body.sections.entries()) {
    for (const [lineIndex, line] of section.lines.entries()) {
      if (!isRecord(line) || !text(line.description, 300) ||
          !text(line.pricingRuleId, 120)) {
        throw new HttpError(400, 'invalid_quotation_line');
      }
      const ruleResult = await client.query(
        `SELECT id, code, name, pricing_model, unit, unit_rate,
                input_unit, conversion_factor, minimum_quantity,
                rounding_decimals, wastage_percent, version, active
         FROM quotation_pricing_rules
         WHERE workspace_id = $1 AND id = $2`,
        [workspaceId, line.pricingRuleId],
      );
      if (ruleResult.rowCount !== 1 || !ruleResult.rows[0].active) {
        throw new HttpError(400, 'invalid_pricing_rule');
      }
      const row = ruleResult.rows[0];
      const rule = {
        pricingModel: row.pricing_model,
        unit: row.unit,
        unitRate: Number(row.unit_rate),
        roundingDecimals: row.rounding_decimals,
        minimumQuantity: Number(row.minimum_quantity),
        wastagePercent: Number(row.wastage_percent),
      };

      const hardware = [];
      if (line.hardware !== undefined && !Array.isArray(line.hardware)) {
        throw new HttpError(400, 'invalid_hardware_selection');
      }
      for (const selected of line.hardware || []) {
        if (!isRecord(selected) ||
            !text(selected.hardwareId, 120) ||
            !Number.isFinite(Number(selected.quantity)) ||
            Number(selected.quantity) <= 0) {
          throw new HttpError(400, 'invalid_hardware_selection');
        }
        const hardwareResult = await client.query(
          `SELECT id, name, brand, sku, unit, unit_rate, active, version
           FROM catalog_quotation_hardware
           WHERE workspace_id = $1 AND id = $2`,
          [workspaceId, selected.hardwareId],
        );
        if (hardwareResult.rowCount !== 1 ||
            !hardwareResult.rows[0].active) {
          throw new HttpError(400, 'invalid_hardware_selection');
        }
        const item = hardwareResult.rows[0];
        hardware.push({
          id: item.id,
          name: item.name,
          brand: item.brand,
          sku: item.sku,
          quantity: Number(selected.quantity),
          unit: item.unit,
          unitRate: Number(item.unit_rate),
        });
      }

      let calculated;
      try {
        calculated = calculateQuotationLine(rule, {
          quantity: line.quantity,
          lengthMm: line.lengthMm,
          heightMm: line.heightMm,
          widthMm: line.widthMm,
        }, hardware);
      } catch (_error) {
        throw new HttpError(400, 'invalid_quotation_line_calculation');
      }
      calculatedLines.push({
        sectionIndex,
        lineIndex,
        section,
        line,
        rule,
        ruleVersion: row.version,
        calculated,
      });
    }
  }
  const totals = calculateQuotationTotals(
    calculatedLines.map((entry) => entry.calculated),
    body.taxRate,
    body.discountPercent,
  );
  return {
    body,
    calculatedLines,
    totals: {
      ...totals,
      amountInWords: amountInWords(totals.grandTotal, 'Rupees'),
    },
  };
}

async function insertRevision(
  client,
  workspaceId,
  userId,
  documentId,
  revisionNumber,
  snapshot,
) {
  const revisionId = `${documentId}-r${revisionNumber}`;
  await client.query(
    `INSERT INTO quotation_revisions
       (workspace_id,id,document_id,revision_number,snapshot,subtotal,
        discount_amount,tax_amount,grand_total,immutable,created_by)
     VALUES ($1,$2,$3,$4,$5::jsonb,$6,$7,$8,$9,false,$10)`,
    [
      workspaceId,
      revisionId,
      documentId,
      revisionNumber,
      JSON.stringify(snapshot),
      snapshot.totals.subtotal,
      snapshot.totals.discountAmount,
      snapshot.totals.taxAmount,
      snapshot.totals.grandTotal,
      userId,
    ],
  );

  for (const [sectionIndex, section] of snapshot.body.sections.entries()) {
    const sectionId = `${revisionId}-s${sectionIndex}`;
    const sectionLines = snapshot.calculatedLines.filter(
      (entry) => entry.sectionIndex === sectionIndex,
    );
    const sectionSubtotal = sectionLines.reduce(
      (total, entry) => total + entry.calculated.finalAmount,
      0,
    );
    await client.query(
      `INSERT INTO quotation_sections
         (workspace_id,id,revision_id,section_type,room_id,name,position,data,subtotal)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8::jsonb,$9)`,
      [
        workspaceId,
        sectionId,
        revisionId,
        section.type,
        section.roomId || null,
        section.name,
        sectionIndex,
        JSON.stringify(section),
        sectionSubtotal,
      ],
    );
    for (const entry of sectionLines) {
      const line = entry.line;
      const lineId = `${revisionId}-l${sectionIndex}-${entry.lineIndex}`;
      await client.query(
        `INSERT INTO quotation_lines
           (workspace_id,id,revision_id,section_id,component_id,service_id,
            package_id,pricing_rule_id,description,quantity,unit,unit_rate,
            base_amount,hardware_amount,final_amount,position,data)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17::jsonb)`,
        [
          workspaceId,
          lineId,
          revisionId,
          sectionId,
          line.componentId || null,
          line.serviceId || null,
          line.packageId || null,
          line.pricingRuleId,
          line.description,
          Number(line.quantity ?? 1),
          entry.calculated.unit,
          entry.calculated.unitRate,
          entry.calculated.baseAmount,
          entry.calculated.hardwareAmount,
          entry.calculated.finalAmount,
          entry.lineIndex,
          JSON.stringify(line),
        ],
      );
      await client.query(
        `INSERT INTO quotation_line_dimensions
           (workspace_id,line_id,length_mm,height_mm,width_mm,depth_mm,
            billable_quantity)
         VALUES ($1,$2,$3,$4,$5,$6,$7)`,
        [
          workspaceId,
          lineId,
          line.lengthMm ?? null,
          line.heightMm ?? null,
          line.widthMm ?? null,
          line.depthMm ?? null,
          entry.calculated.billableQuantity,
        ],
      );
      for (const hardware of entry.calculated.hardware) {
        const hardwareId = `${lineId}-h-${hardware.id}`;
        await client.query(
          `INSERT INTO quotation_line_hardware
             (workspace_id,id,line_id,hardware_id,name,brand,sku,quantity,
              unit,unit_rate,amount)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,
          [
            workspaceId,
            hardwareId,
            lineId,
            hardware.id,
            hardware.name,
            hardware.brand,
            hardware.sku,
            hardware.quantity,
            hardware.unit,
            hardware.unitRate,
            hardware.amount,
          ],
        );
      }
      await client.query(
        `INSERT INTO quotation_calculation_audit
           (workspace_id,id,revision_id,line_id,calculator_version,
            pricing_rule_version,catalog_package_version,input_snapshot,
            result_snapshot)
         VALUES ($1,$2,$3,$4,'1.0.0',$5,$6,$7::jsonb,$8::jsonb)`,
        [
          workspaceId,
          `${lineId}-audit`,
          revisionId,
          lineId,
          entry.ruleVersion,
          line.packageVersion ?? null,
          JSON.stringify({
            quantity: line.quantity,
            lengthMm: line.lengthMm,
            heightMm: line.heightMm,
            widthMm: line.widthMm,
            hardware: line.hardware || [],
          }),
          JSON.stringify(entry.calculated),
        ],
      );
    }
  }
  await client.query(
    `INSERT INTO quotation_discounts
       (workspace_id,revision_id,scope_type,scope_id,discount_percent,discount_amount)
     VALUES ($1,$2,'boq','',$3,$4)`,
    [
      workspaceId,
      revisionId,
      snapshot.body.discountPercent,
      snapshot.totals.discountAmount,
    ],
  );
  return revisionId;
}

function createQuotationHandler({
  authenticate = authenticateRequest,
  withWorkspace = withWorkspaceTransaction,
  rateLimit = null,
  env = process.env,
  logger = console.error,
} = {}) {
  return async function quotationHandler(req, res) {
    const requestId = attachRequestId(res);
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Vary', 'Authorization');
    const method = req.method;
    if (!['GET', 'POST', 'PUT'].includes(method)) {
      res.setHeader('Allow', 'GET, POST, PUT');
      return res.status(405).json({ error: 'method_not_allowed' });
    }
    try {
      const { userId } = await authenticate(req);
      if (rateLimit) {
        await rateLimit(
          userId,
          method === 'GET' ? 'quotation_read' : 'quotation_write',
          { limit: method === 'GET' ? 60 : 30, windowSeconds: 60 },
        );
      }
      const workspaceId = getWorkspaceId(req);
      const action = req.query?.action;

      if (method === 'GET') {
        const result = await withWorkspace(
          userId,
          workspaceId,
          async (client, access) => {
            requirePermission(access, 'viewFinancials');
            const documents = await client.query(
              `SELECT d.*, r.id AS latest_revision_id,
                      r.revision_number, r.grand_total, r.created_at AS revision_created_at
               FROM quotation_documents d
               LEFT JOIN LATERAL (
                 SELECT id, revision_number, grand_total, created_at
                 FROM quotation_revisions
                 WHERE workspace_id = d.workspace_id AND document_id = d.id
                 ORDER BY revision_number DESC LIMIT 1
               ) r ON true
               WHERE d.workspace_id = $1
               ORDER BY d.updated_at DESC
               LIMIT 200`,
              [workspaceId],
            );
            return documents.rows;
          },
        );
        return res.status(200).json({ quotations: result });
      }

      if (method === 'POST' && action === 'calculate') {
        const result = await withWorkspace(
          userId,
          workspaceId,
          async (client, access) => {
            requirePermission(access, 'manageFinancials');
            return calculateSnapshot(client, workspaceId, req.body);
          },
        );
        return res.status(200).json({
          calculation: result.totals,
          lines: result.calculatedLines.map((entry) => entry.calculated),
        });
      }

      if (method === 'POST' &&
          ['submit', 'approve', 'reject'].includes(action)) {
        const documentId = req.query?.id;
        if (!text(documentId, 120)) {
          throw new HttpError(400, 'invalid_document_id');
        }
        const result = await withWorkspace(
          userId,
          workspaceId,
          async (client, access) => {
            requirePermission(access, 'manageFinancials');
            const document = await client.query(
              `SELECT id,status FROM quotation_documents
               WHERE workspace_id=$1 AND id=$2 FOR UPDATE`,
              [workspaceId, documentId],
            );
            if (document.rowCount !== 1) {
              throw new HttpError(404, 'quotation_not_found');
            }
            const status = action === 'submit'
              ? 'Pending approval'
              : action === 'approve'
                ? 'Approved'
                : 'Rejected';
            if (action === 'approve' &&
                document.rows[0].status === 'Pending approval') {
              await client.query(
                `UPDATE quotation_revisions
                 SET immutable=true
                 WHERE workspace_id=$1 AND document_id=$2
                   AND revision_number=(
                     SELECT max(revision_number)
                     FROM quotation_revisions
                     WHERE workspace_id=$1 AND document_id=$2
                   )`,
                [workspaceId, documentId],
              );
            } else if (action === 'approve') {
              throw new HttpError(409, 'quotation_not_pending_approval');
            }
            await client.query(
              `UPDATE quotation_documents
               SET status=$3,updated_at=now()
               WHERE workspace_id=$1 AND id=$2`,
              [workspaceId, documentId, status],
            );
            return { id: documentId, status };
          },
        );
        return res.status(200).json(result);
      }

      if (method === 'POST') {
        const created = await withWorkspace(
          userId,
          workspaceId,
          async (client, access) => {
            requirePermission(access, 'manageFinancials');
            await client.query('SELECT pg_advisory_xact_lock($1)', [
              workspaceId.split('').reduce((sum, char) =>
                (sum * 31 + char.charCodeAt(0)) >>> 0, 0),
            ]);
            const number = await nextQuotationNumber(client, workspaceId);
            const snapshot = await calculateSnapshot(
              client,
              workspaceId,
              req.body,
            );
            const documentId = randomUUID();
            await client.query(
              `INSERT INTO quotation_documents
                 (workspace_id,id,number,project_id,customer_id,title,
                  currency_symbol,status,validity_date,created_by)
               VALUES ($1,$2,$3,$4,$5,$6,$7,'Draft',$8,$9)`,
              [
                workspaceId,
                documentId,
                number,
                req.body.projectId || null,
                req.body.customerId || null,
                snapshot.body.title,
                snapshot.body.currencySymbol,
                snapshot.body.validityDate || null,
                userId,
              ],
            );
            const revisionId = await insertRevision(
              client,
              workspaceId,
              userId,
              documentId,
              1,
              snapshot,
            );
            return { id: documentId, number, revisionId, status: 'Draft',
              calculation: snapshot.totals };
          },
        );
        return res.status(201).json(created);
      }

      if (method === 'PUT') {
        const documentId = req.query?.id;
        if (!text(documentId, 120)) throw new HttpError(400, 'invalid_document_id');
        const result = await withWorkspace(
          userId,
          workspaceId,
          async (client, access) => {
            requirePermission(access, 'manageFinancials');
            const document = await client.query(
              `SELECT id, status FROM quotation_documents
               WHERE workspace_id = $1 AND id = $2
               FOR UPDATE`,
              [workspaceId, documentId],
            );
            if (document.rowCount !== 1) {
              throw new HttpError(404, 'quotation_not_found');
            }
            if (document.rows[0].status === 'Approved') {
              throw new HttpError(409, 'approved_quotation_requires_revision');
            }
            const latest = await client.query(
              `SELECT revision_number
               FROM quotation_revisions
               WHERE workspace_id = $1 AND document_id = $2
               ORDER BY revision_number DESC LIMIT 1
               FOR UPDATE`,
              [workspaceId, documentId],
            );
            if (latest.rowCount !== 1) {
              throw new HttpError(409, 'quotation_revision_missing');
            }
            const snapshot = await calculateSnapshot(
              client,
              workspaceId,
              req.body,
            );
            const revisionNumber = latest.rows[0].revision_number + 1;
            const revisionId = await insertRevision(
              client,
              workspaceId,
              userId,
              documentId,
              revisionNumber,
              snapshot,
            );
            await client.query(
              `UPDATE quotation_documents
               SET title=$3,currency_symbol=$4,status='Draft',
                   validity_date=$5,updated_at=now()
               WHERE workspace_id=$1 AND id=$2`,
              [workspaceId, documentId, snapshot.body.title,
                snapshot.body.currencySymbol,
                snapshot.body.validityDate || null],
            );
            return { id: documentId, revisionId, revisionNumber,
              status: 'Draft', calculation: snapshot.totals };
          },
        );
        return res.status(200).json(result);
      }
    } catch (error) {
      if (respondToRateLimit(error, res)) return;
      if (error instanceof HttpError || error instanceof WorkspaceAccessError ||
          (Number.isInteger(error?.statusCode) && error.statusCode === 401)) {
        return res.status(error.statusCode).json({
          error: error instanceof HttpError ||
              error instanceof WorkspaceAccessError
            ? error.code
            : 'unauthorized',
        });
      }
      logger('Quotation request failed.', {
        requestId,
        errorName: error instanceof Error ? error.name : 'UnknownError',
        ...(typeof error?.code === 'string' ? { errorCode: error.code } : {}),
      });
      return res.status(500).json({ error: 'internal_server_error' });
    }
  };
}

const handler = createQuotationHandler({
  rateLimit: enforceUserRateLimit,
});
Object.assign(handler, {
  createQuotationHandler,
  calculateSnapshot,
  validatePayload,
  insertRevision,
  nextQuotationNumber,
});

module.exports = handler;
