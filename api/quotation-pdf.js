const PDFDocument = require('pdfkit');
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

class HttpError extends Error {
  constructor(statusCode, code) {
    super(code);
    this.name = 'HttpError';
    this.statusCode = statusCode;
    this.code = code;
  }
}

function money(value, symbol = '₹') {
  return `${symbol}${Number(value || 0).toLocaleString('en-IN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;
}

async function createProposalPdfBuffer(document) {
  const snapshot = document.snapshot;
  return new Promise((resolve, reject) => {
    const pdf = new PDFDocument({
      size: 'A4',
      margin: 44,
      info: {
        Title: `${document.number} - ${snapshot.body.title}`,
        Author: 'Raams CRM',
        Subject: 'Interior proposal',
      },
    });
    const chunks = [];
    pdf.on('data', (chunk) => chunks.push(chunk));
    pdf.on('end', () => resolve(Buffer.concat(chunks)));
    pdf.on('error', reject);

    pdf.rect(0, 0, pdf.page.width, 150).fill('#24332D');
    pdf.fillColor('#FFFFFF')
      .fontSize(10)
      .text('INTERIOR PROPOSAL', 44, 38, { characterSpacing: 2 });
    pdf.fillColor('#FFFFFF')
      .fontSize(28)
      .text(snapshot.body.title || 'Interior Proposal', 44, 68, {
        width: 400,
      });
    pdf.fontSize(10)
      .text(document.number, 44, 118);

    pdf.fillColor('#24332D').moveDown(2);
    pdf.fontSize(10).fillColor('#6D776F')
      .text(`Prepared for: ${snapshot.body.customerName || 'Client'}`);
    pdf.text(`Project: ${snapshot.body.projectName || 'Residential project'}`);
    pdf.text(`Valid until: ${snapshot.body.validityDate || '-'}`);
    pdf.moveDown();

    pdf.fillColor('#24332D').fontSize(15)
      .text('Bill of Quantities');

    for (const section of snapshot.body.sections || []) {
      pdf.moveDown(0.7);
      pdf.fillColor('#24332D').fontSize(12).text(section.name);
      const sectionLines = snapshot.calculatedLines.filter(
        (entry) => entry.sectionIndex ===
          (snapshot.body.sections.indexOf(section)),
      );
      for (const entry of sectionLines) {
        const line = entry.line;
        const dimensions = [
          line.lengthMm ? `L ${line.lengthMm} mm` : null,
          line.heightMm ? `H ${line.heightMm} mm` : null,
          line.widthMm ? `W ${line.widthMm} mm` : null,
        ].filter(Boolean).join(' × ');
        pdf.moveDown(0.25);
        pdf.fontSize(9).fillColor('#24332D');
        pdf.text(line.description, 44, pdf.y, { width: 320, continued: true });
        pdf.fillColor('#6D776F').text(dimensions ? `  ${dimensions}` : '', {
          width: 180,
          align: 'right',
        });
        pdf.fillColor('#24332D')
          .text(`${entry.calculated.quantity} ${entry.calculated.unit}`, 44,
            pdf.y + 2, { width: 320 });
        pdf.text(money(entry.calculated.finalAmount, snapshot.body.currencySymbol),
          390, pdf.y - 12, { width: 158, align: 'right' });

        for (const hardware of entry.calculated.hardware || []) {
          pdf.fontSize(8).fillColor('#777E79')
            .text(`• ${hardware.brand} ${hardware.name} (${hardware.quantity})`,
              58, pdf.y + 2, { width: 490 });
        }
      }
    }

    pdf.moveDown();
    pdf.moveTo(44, pdf.y).lineTo(551, pdf.y).strokeColor('#D9DDD8').stroke();
    pdf.moveDown();
    pdf.fontSize(10).fillColor('#24332D');
    const totals = snapshot.totals;
    pdf.text('Subtotal', 390, pdf.y, { width: 100, align: 'left' });
    pdf.text(money(totals.subtotal, snapshot.body.currencySymbol),
      490, pdf.y - 12, { width: 58, align: 'right' });
    pdf.moveDown();
    if (totals.discountAmount > 0) {
      pdf.text(`Discount (${totals.discountPercent}%)`, 390, pdf.y,
        { width: 100 });
      pdf.text(`-${money(totals.discountAmount, snapshot.body.currencySymbol)}`,
        490, pdf.y - 12, { width: 58, align: 'right' });
      pdf.moveDown();
    }
    if (totals.taxAmount > 0) {
      pdf.text(`Tax (${totals.taxRate}%)`, 390, pdf.y, { width: 100 });
      pdf.text(money(totals.taxAmount, snapshot.body.currencySymbol),
        490, pdf.y - 12, { width: 58, align: 'right' });
      pdf.moveDown();
    }
    pdf.fontSize(14).fillColor('#24332D');
    pdf.text('Grand Total', 390, pdf.y, { width: 100 });
    pdf.text(money(totals.grandTotal, snapshot.body.currencySymbol),
      490, pdf.y - 17, { width: 58, align: 'right' });
    pdf.moveDown(0.8);
    pdf.fontSize(9).fillColor('#6D776F')
      .text(totals.amountInWords, 44, pdf.y, { align: 'right' });

    pdf.moveDown(2);
    pdf.fontSize(8).fillColor('#8A928D')
      .text(
        `${document.number} · Revision ${document.revisionNumber} · Generated by Raams CRM`,
        44,
        pdf.page.height - 48,
        { align: 'center', width: pdf.page.width - 88 },
      );
    pdf.end();
  });
}

function createQuotationPdfHandler({
  authenticate = authenticateRequest,
  withWorkspace = withWorkspaceTransaction,
  rateLimit = null,
  logger = console.error,
} = {}) {
  return async function quotationPdfHandler(req, res) {
    const requestId = attachRequestId(res);
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Vary', 'Authorization');
    if (req.method !== 'POST') {
      res.setHeader('Allow', 'POST');
      return res.status(405).json({ error: 'method_not_allowed' });
    }
    try {
      const { userId } = await authenticate(req);
      if (rateLimit) {
        await rateLimit(userId, 'quotation_pdf', {
          limit: 10,
          windowSeconds: 60,
        });
      }
      const workspaceId = getWorkspaceId(req);
      const documentId = req.body?.id;
      if (typeof documentId !== 'string' || documentId.length > 120) {
        throw new HttpError(400, 'invalid_document_id');
      }
      const document = await withWorkspace(
        userId,
        workspaceId,
        async (client, access) => {
          requirePermission(access, 'viewFinancials');
          const result = await client.query(
            `SELECT d.id,d.number,d.status,r.revision_number,r.snapshot
             FROM quotation_documents d
             JOIN LATERAL (
               SELECT revision_number,snapshot
               FROM quotation_revisions
               WHERE workspace_id=d.workspace_id AND document_id=d.id
               ORDER BY revision_number DESC LIMIT 1
             ) r ON true
             WHERE d.workspace_id=$1 AND d.id=$2`,
            [workspaceId, documentId],
          );
          if (result.rowCount !== 1) {
            throw new HttpError(404, 'quotation_not_found');
          }
          return {
            number: result.rows[0].number,
            revisionNumber: result.rows[0].revision_number,
            snapshot: result.rows[0].snapshot,
          };
        },
      );
      const buffer = await createProposalPdfBuffer(document);
      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader(
        'Content-Disposition',
        `inline; filename="${document.number}-rev-${document.revisionNumber}.pdf"`,
      );
      return res.status(200).send(buffer);
    } catch (error) {
      if (respondToRateLimit(error, res)) return;
      if (error instanceof HttpError || error instanceof WorkspaceAccessError) {
        return res.status(error.statusCode).json({ error: error.code });
      }
      logger('Quotation PDF request failed.', {
        requestId,
        errorName: error instanceof Error ? error.name : 'UnknownError',
        ...(typeof error?.code === 'string' ? { errorCode: error.code } : {}),
      });
      return res.status(500).json({ error: 'internal_server_error' });
    }
  };
}

const handler = createQuotationPdfHandler({
  rateLimit: enforceUserRateLimit,
});
Object.assign(handler, {
  createQuotationPdfHandler,
  createProposalPdfBuffer,
});

module.exports = handler;
