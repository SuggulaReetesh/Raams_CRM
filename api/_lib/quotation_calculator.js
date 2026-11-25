const MM_PER_SQUARE_FOOT = 929030.4;
const MM_PER_CUBIC_FOOT = 28316846.592;
const MM_PER_RUNNING_FOOT = 304.8;

function roundMoney(value) {
  return Math.round((value + Number.EPSILON) * 100) / 100;
}

function positiveNumber(value) {
  return typeof value === 'number' &&
    Number.isFinite(value) && value > 0;
}

function positiveInteger(value) {
  return Number.isSafeInteger(value) && value > 0;
}

function calculateArea(lengthMm, heightMm, quantity) {
  if (!positiveNumber(lengthMm) || !positiveNumber(heightMm) ||
      !positiveNumber(quantity)) {
    throw new Error('invalid_area_dimensions');
  }
  return (lengthMm * heightMm * quantity) / MM_PER_SQUARE_FOOT;
}

function calculateRunning(lengthMm, heightMm, quantity) {
  if (!positiveNumber(quantity)) throw new Error('invalid_quantity');
  const dimension = lengthMm > 0 ? lengthMm : heightMm;
  if (!positiveNumber(dimension)) throw new Error('invalid_running_dimension');
  return (dimension * quantity) / MM_PER_RUNNING_FOOT;
}

function calculateVolume(lengthMm, widthMm, heightMm, quantity) {
  if (!positiveNumber(lengthMm) || !positiveNumber(widthMm) ||
      !positiveNumber(heightMm) || !positiveNumber(quantity)) {
    throw new Error('invalid_volume_dimensions');
  }
  return (lengthMm * widthMm * heightMm * quantity) / MM_PER_CUBIC_FOOT;
}

function roundedBillableQuantity(quantity, decimals) {
  if (!Number.isInteger(decimals) || decimals < 0 || decimals > 6) {
    throw new Error('invalid_rounding_decimals');
  }
  const factor = 10 ** decimals;
  return Math.ceil(quantity * factor - Number.EPSILON) / factor;
}

function calculateQuotationLine(rule, line, hardware = []) {
  if (!rule || typeof rule !== 'object') throw new Error('invalid_pricing_rule');
  if (!line || typeof line !== 'object') throw new Error('invalid_line');

  const model = rule.pricingModel;
  const quantity = Number(line.quantity ?? 1);
  let billableQuantity;

  if (model === 'area') {
    billableQuantity = calculateArea(
      Number(line.lengthMm),
      Number(line.heightMm),
      quantity,
    );
  } else if (model === 'running') {
    billableQuantity = calculateRunning(
      Number(line.lengthMm),
      Number(line.heightMm),
      quantity,
    );
  } else if (model === 'volume') {
    billableQuantity = calculateVolume(
      Number(line.lengthMm),
      Number(line.widthMm),
      Number(line.heightMm),
      quantity,
    );
  } else if (['fixed', 'unit', 'point', 'lumpsum'].includes(model)) {
    if (!positiveNumber(quantity) &&
        !(model === 'fixed' || model === 'lumpsum')) {
      throw new Error('invalid_quantity');
    }
    billableQuantity = model === 'fixed' ? 1 : quantity;
  } else {
    throw new Error('invalid_pricing_model');
  }

  const decimals = Number.isInteger(rule.roundingDecimals)
    ? rule.roundingDecimals
    : 2;
  billableQuantity = roundedBillableQuantity(billableQuantity, decimals);
  const minimum = Number(rule.minimumQuantity ?? 0);
  if (Number.isFinite(minimum) && billableQuantity < minimum) {
    billableQuantity = minimum;
  }

  const unitRate = Number(rule.unitRate);
  if (!Number.isFinite(unitRate) || unitRate < 0) {
    throw new Error('invalid_unit_rate');
  }
  const wastagePercent = Number(rule.wastagePercent ?? 0);
  if (!Number.isFinite(wastagePercent) ||
      wastagePercent < 0 || wastagePercent > 100) {
    throw new Error('invalid_wastage_percent');
  }

  const hardwareSnapshot = hardware.map((item) => {
    const hardwareQuantity = Number(item.quantity);
    const hardwareUnitRate = Number(item.unitRate);
    if (!positiveNumber(hardwareQuantity) ||
        !Number.isFinite(hardwareUnitRate) ||
        hardwareUnitRate < 0) {
      throw new Error('invalid_hardware_line');
    }
    return {
      id: item.id,
      name: item.name,
      brand: item.brand,
      sku: item.sku,
      quantity: hardwareQuantity,
      unit: item.unit,
      unitRate: hardwareUnitRate,
      amount: roundMoney(hardwareQuantity * hardwareUnitRate),
    };
  });

  const baseAmount = billableQuantity * unitRate;
  const baseWithWastage = baseAmount * (1 + wastagePercent / 100);
  const hardwareAmount = hardwareSnapshot.reduce(
    (total, item) => total + item.amount,
    0,
  );

  return {
    pricingModel: model,
    billableQuantity,
    quantity,
    unit: rule.unit,
    unitRate,
    wastagePercent,
    baseAmount: roundMoney(baseWithWastage),
    hardwareAmount: roundMoney(hardwareAmount),
    finalAmount: roundMoney(baseWithWastage + hardwareAmount),
    hardware: hardwareSnapshot,
  };
}

function calculateQuotationTotals(lines, taxRate = 0, discountPercent = 0) {
  if (!Number.isFinite(Number(taxRate)) ||
      Number(taxRate) < 0 || Number(taxRate) > 100 ||
      !Number.isFinite(Number(discountPercent)) ||
      Number(discountPercent) < 0 || Number(discountPercent) > 100 ||
      !Array.isArray(lines)) {
    throw new Error('invalid_quotation_totals');
  }
  const subtotal = roundMoney(lines.reduce(
    (total, line) => total + Number(line.finalAmount ?? 0),
    0,
  ));
  const discountAmount = roundMoney(subtotal * Number(discountPercent) / 100);
  const taxableAmount = roundMoney(subtotal - discountAmount);
  const taxAmount = roundMoney(taxableAmount * Number(taxRate) / 100);
  return {
    subtotal,
    discountPercent: Number(discountPercent),
    discountAmount,
    taxableAmount,
    taxRate: Number(taxRate),
    taxAmount,
    grandTotal: roundMoney(taxableAmount + taxAmount),
  };
}

function amountInWords(value, currency = 'Rupees') {
  const amount = Math.round(Number(value) * 100);
  if (!Number.isSafeInteger(amount) || amount < 0) {
    throw new Error('invalid_amount');
  }
  const ones = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight',
    'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen',
    'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen',
  ];
  const tens = [
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy',
    'Eighty', 'Ninety',
  ];

  function belowThousand(number) {
    const parts = [];
    if (number >= 100) {
      parts.push(`${ones[Math.floor(number / 100)]} Hundred`);
      number %= 100;
    }
    if (number >= 20) {
      parts.push(tens[Math.floor(number / 10)]);
      number %= 10;
    }
    if (number > 0) parts.push(ones[number]);
    return parts.join(' ');
  }

  function integerWords(number) {
    if (number === 0) return 'Zero';
    const result = [];
    const crores = Math.floor(number / 10000000);
    number %= 10000000;
    const lakhs = Math.floor(number / 100000);
    number %= 100000;
    const thousands = Math.floor(number / 1000);
    number %= 1000;
    if (crores) result.push(`${belowThousand(crores)} Crore`);
    if (lakhs) result.push(`${belowThousand(lakhs)} Lakh`);
    if (thousands) result.push(`${belowThousand(thousands)} Thousand`);
    if (number) result.push(belowThousand(number));
    return result.join(' ').replace(/\s+/g, ' ').trim();
  }

  const whole = Math.floor(amount / 100);
  const paise = amount % 100;
  let words = `${integerWords(whole)} ${currency}`;
  if (paise > 0) {
    words += ` and ${integerWords(paise)} Paise`;
  }
  return `${words.trim()} Only`;
}

module.exports = {
  MM_PER_SQUARE_FOOT,
  MM_PER_CUBIC_FOOT,
  MM_PER_RUNNING_FOOT,
  calculateArea,
  calculateRunning,
  calculateVolume,
  calculateQuotationLine,
  calculateQuotationTotals,
  amountInWords,
  roundMoney,
  roundedBillableQuantity,
};
