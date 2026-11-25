const assert = require('node:assert/strict');
const test = require('node:test');
const {
  calculateArea,
  calculateRunning,
  calculateVolume,
  calculateQuotationLine,
  calculateQuotationTotals,
  amountInWords,
  roundedBillableQuantity,
} = require('../../api/_lib/quotation_calculator');

test('calculates woodwork area from millimeters', () => {
  const area = calculateArea(5362, 900, 1);
  assert.equal(Math.round(area * 100) / 100, 5.19);
});

test('rounds billable quantity upward by configured decimals', () => {
  assert.equal(roundedBillableQuantity(5.201, 2), 5.21);
  assert.equal(roundedBillableQuantity(5.200, 2), 5.20);
});

test('calculates line amount with hardware and wastage', () => {
  const result = calculateQuotationLine({
    pricingModel: 'area',
    unit: 'Sq. Ft',
    unitRate: 1600,
    roundingDecimals: 2,
    minimumQuantity: 0,
    wastagePercent: 5,
  }, {
    quantity: 1,
    lengthMm: 5362,
    heightMm: 900,
  }, [{
    id: 'hinge',
    name: 'Soft close hinge',
    brand: 'Hettich',
    sku: 'H001',
    quantity: 4,
    unit: 'No',
    unitRate: 250,
  }]);
  assert.equal(result.baseAmount, 8736);
  assert.equal(result.hardwareAmount, 1000);
  assert.equal(result.finalAmount, 9736);
});

test('calculates running and volume quantities', () => {
  assert.ok(calculateRunning(3000, 600, 1) > 9);
  assert.ok(calculateVolume(1000, 500, 2000, 1) > 0);
});

test('calculates discount, tax, and grand total', () => {
  const totals = calculateQuotationTotals([
    { finalAmount: 100000 },
    { finalAmount: 50000 },
  ], 18, 10);
  assert.equal(totals.subtotal, 150000);
  assert.equal(totals.discountAmount, 15000);
  assert.equal(totals.taxableAmount, 135000);
  assert.equal(totals.taxAmount, 24300);
  assert.equal(totals.grandTotal, 159300);
});

test('generates Indian amount-in-words text', () => {
  assert.equal(
    amountInWords(1204823, 'Rupees'),
    'Twelve Lakh Four Thousand Eight Hundred Twenty Three Rupees Only',
  );
});

test('rejects invalid dimensional input', () => {
  assert.throws(
    () => calculateArea(0, 900, 1),
    /invalid_area_dimensions/,
  );
  assert.throws(
    () => calculateQuotationTotals([], -1, 10),
    /invalid_quotation_totals/,
  );
});
