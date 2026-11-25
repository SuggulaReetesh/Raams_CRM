const assert = require('node:assert/strict');
const test = require('node:test');
const {
  createProposalPdfBuffer,
} = require('../../api/quotation-pdf');

test('creates a valid premium quotation PDF buffer', async () => {
  const snapshot = {
    body: {
      title: 'Luxury Interior Proposal',
      customerName: 'Sravya Garu',
      projectName: 'Miyapur Residence',
      validityDate: '2026-10-13',
      currencySymbol: '₹',
      sections: [{
        name: 'Modular Kitchen',
        type: 'room',
        lines: [],
      }],
    },
    calculatedLines: [{
      sectionIndex: 0,
      line: {
        description: 'Kitchen Base Unit',
        quantity: 1,
        lengthMm: 5362,
        heightMm: 900,
      },
      calculated: {
        quantity: 1,
        unit: 'Sq. Ft',
        finalAmount: 85708,
        hardware: [{
          brand: 'Hettich',
          name: 'Soft Close Hinge',
          quantity: 4,
        }],
      },
    }],
    totals: {
      subtotal: 85708,
      discountPercent: 10,
      discountAmount: 8570.8,
      taxRate: 18,
      taxAmount: 13884.68,
      grandTotal: 91021.88,
      amountInWords: 'Ninety One Thousand Twenty One Rupees Eighty Eight Paise Only',
    },
  };
  const buffer = await createProposalPdfBuffer({
    number: 'QT-000001',
    revisionNumber: 1,
    snapshot,
  });
  assert.ok(Buffer.isBuffer(buffer));
  assert.ok(buffer.length > 1000);
  assert.equal(buffer.subarray(0, 4).toString(), '%PDF');
});
