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

const catalogQueries = {
  packages: 'SELECT * FROM quotation_packages WHERE workspace_id = $1 ORDER BY name',
  packageInclusions:
    'SELECT * FROM quotation_package_inclusions WHERE workspace_id = $1 ORDER BY id',
  rooms:
    'SELECT * FROM catalog_quotation_rooms WHERE workspace_id = $1 ORDER BY position, name',
  components:
    'SELECT * FROM catalog_quotation_components WHERE workspace_id = $1 ORDER BY name',
  services:
    'SELECT * FROM catalog_quotation_services WHERE workspace_id = $1 ORDER BY name',
  materials:
    'SELECT * FROM catalog_quotation_materials WHERE workspace_id = $1 ORDER BY name',
  finishes:
    'SELECT * FROM catalog_quotation_finishes WHERE workspace_id = $1 ORDER BY name',
  hardware:
    'SELECT * FROM catalog_quotation_hardware WHERE workspace_id = $1 ORDER BY name',
  pricingRules:
    'SELECT * FROM quotation_pricing_rules WHERE workspace_id = $1 ORDER BY name',
  termsTemplates:
    'SELECT * FROM proposal_terms_templates WHERE workspace_id = $1 ORDER BY name',
  documentTemplates:
    'SELECT * FROM proposal_document_templates WHERE workspace_id = $1 ORDER BY name',
  lineItems:
    `SELECT id,name,basic_rate_per_sqft::double precision AS "basicRatePerSqft",
       medium_rate_per_sqft::double precision AS "mediumRatePerSqft",
       luxury_rate_per_sqft::double precision AS "luxuryRatePerSqft",
       active,version
     FROM quotation_line_item_catalog
     WHERE workspace_id = $1 ORDER BY name`,
};

function isRecord(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function text(value, field, maxLength = 120) {
  if (typeof value !== 'string' ||
      value.trim().length === 0 ||
      value.length > maxLength) {
    throw new HttpError(400, `invalid_${field}`);
  }
  return value.trim();
}

function optionalText(value, field, maxLength = 4000) {
  if (value === undefined) return '';
  if (typeof value !== 'string' || value.length > maxLength) {
    throw new HttpError(400, `invalid_${field}`);
  }
  return value;
}

function booleanValue(value, field) {
  if (value !== undefined && typeof value !== 'boolean') {
    throw new HttpError(400, `invalid_${field}`);
  }
  return value === undefined ? true : value;
}

function positiveInteger(value, field, fallback = 1) {
  if (value === undefined) return fallback;
  if (!Number.isInteger(value) || value < 1) {
    throw new HttpError(400, `invalid_${field}`);
  }
  return value;
}

function jsonData(value) {
  if (value === undefined) return {};
  if (!isRecord(value)) throw new HttpError(400, 'invalid_data');
  return value;
}

const writeDefinitions = {
  packages: {
    table: 'quotation_packages',
    fields: ['id', 'code', 'name', 'description', 'version', 'active', 'data'],
  },
  rooms: {
    table: 'catalog_quotation_rooms',
    fields: ['id', 'code', 'name', 'position', 'active', 'data', 'version'],
  },
  components: {
    table: 'catalog_quotation_components',
    fields: ['id', 'code', 'name', 'roomId', 'description', 'pricingModel', 'uom',
      'active', 'data', 'version'],
  },
  services: {
    table: 'catalog_quotation_services',
    fields: ['id', 'code', 'name', 'description', 'pricingModel', 'uom',
      'active', 'data', 'version'],
  },
  materials: {
    table: 'catalog_quotation_materials',
    fields: ['id', 'code', 'name', 'specifications', 'active', 'data', 'version'],
  },
  finishes: {
    table: 'catalog_quotation_finishes',
    fields: ['id', 'code', 'name', 'brand', 'priceAdjustment',
      'active', 'data', 'version'],
  },
  hardware: {
    table: 'catalog_quotation_hardware',
    fields: ['id', 'code', 'name', 'brand', 'sku', 'unit', 'unitRate',
      'active', 'data', 'version'],
  },
  pricingRules: {
    table: 'quotation_pricing_rules',
    fields: ['id', 'code', 'name', 'pricingModel', 'unit', 'unitRate',
      'inputUnit', 'conversionFactor', 'minimumQuantity', 'roundingDecimals',
      'wastagePercent', 'active', 'data', 'version'],
  },
  termsTemplates: {
    table: 'proposal_terms_templates',
    fields: ['id', 'name', 'notes', 'terms', 'assumptions', 'warranty',
      'paymentSchedule', 'active', 'data', 'version'],
  },
  documentTemplates: {
    table: 'proposal_document_templates',
    fields: ['id', 'name', 'brandName', 'logoStoragePath', 'accentColor',
      'sectionOrder', 'data', 'active', 'version'],
  },
  lineItems: {
    table: 'quotation_line_item_catalog',
    fields: ['id', 'name', 'basicRatePerSqft', 'mediumRatePerSqft',
      'luxuryRatePerSqft', 'active', 'version'],
  },
};

const pricingModels = new Set([
  'fixed', 'unit', 'point', 'lumpsum', 'area', 'running', 'volume',
]);

function validateRecord(type, record) {
  if (!isRecord(record)) throw new HttpError(400, `invalid_${type}_record`);
  const id = text(record.id, 'id', 120);
  if (type === 'lineItems') {
    const nullableRate = (value, field) => {
      if (value === undefined || value === null) return null;
      if (typeof value !== 'number' || !Number.isFinite(value) || value < 0) {
        throw new HttpError(400, `invalid_${field}`);
      }
      return value;
    };
    return {
      id,
      name: text(record.name, 'name'),
      basicRatePerSqft: nullableRate(
        record.basicRatePerSqft,
        'basic_rate_per_sqft',
      ),
      mediumRatePerSqft: nullableRate(
        record.mediumRatePerSqft,
        'medium_rate_per_sqft',
      ),
      luxuryRatePerSqft: nullableRate(
        record.luxuryRatePerSqft,
        'luxury_rate_per_sqft',
      ),
      active: booleanValue(record.active, 'active'),
      version: positiveInteger(record.version, 'version'),
    };
  }
  if (type === 'packages') {
    return {
      id,
      code: text(record.code, 'code', 40).toUpperCase(),
      name: text(record.name, 'name'),
      description: optionalText(record.description, 'description', 4000),
      version: positiveInteger(record.version, 'version'),
      active: booleanValue(record.active, 'active'),
      data: jsonData(record.data),
    };
  }
  if (type === 'rooms') {
    return {
      id,
      code: text(record.code, 'code', 40).toUpperCase(),
      name: text(record.name, 'name'),
      position: Number.isInteger(record.position) && record.position >= 0
        ? record.position
        : 0,
      active: booleanValue(record.active, 'active'),
      data: jsonData(record.data),
      version: positiveInteger(record.version, 'version'),
    };
  }
  if (type === 'components' || type === 'services') {
    const pricingModel = record.pricingModel;
    if (!pricingModels.has(pricingModel)) {
      throw new HttpError(400, 'invalid_pricing_model');
    }
    return {
      id,
      code: text(record.code, 'code', 40).toUpperCase(),
      name: text(record.name, 'name'),
      ...(type === 'components'
        ? { roomId: typeof record.roomId === 'string' ? record.roomId : null }
        : {}),
      description: optionalText(record.description, 'description', 4000),
      pricingModel,
      uom: text(record.uom, 'uom', 30),
      active: booleanValue(record.active, 'active'),
      data: jsonData(record.data),
      version: positiveInteger(record.version, 'version'),
    };
  }
  if (type === 'materials') {
    return {
      id,
      code: text(record.code, 'code', 40).toUpperCase(),
      name: text(record.name, 'name'),
      specifications: optionalText(record.specifications, 'specifications', 4000),
      active: booleanValue(record.active, 'active'),
      data: jsonData(record.data),
      version: positiveInteger(record.version, 'version'),
    };
  }
  if (type === 'finishes') {
    const adjustment = Number(record.priceAdjustment ?? 0);
    if (!Number.isFinite(adjustment)) {
      throw new HttpError(400, 'invalid_price_adjustment');
    }
    return {
      id,
      code: text(record.code, 'code', 40).toUpperCase(),
      name: text(record.name, 'name'),
      brand: optionalText(record.brand, 'brand', 120),
      priceAdjustment: adjustment,
      active: booleanValue(record.active, 'active'),
      data: jsonData(record.data),
      version: positiveInteger(record.version, 'version'),
    };
  }
  if (type === 'hardware') {
    const unitRate = Number(record.unitRate);
    if (!Number.isFinite(unitRate) || unitRate < 0) {
      throw new HttpError(400, 'invalid_unit_rate');
    }
    return {
      id,
      code: text(record.code, 'code', 40).toUpperCase(),
      name: text(record.name, 'name'),
      brand: text(record.brand, 'brand', 120),
      sku: optionalText(record.sku, 'sku', 120),
      unit: text(record.unit ?? 'No', 'unit', 30),
      unitRate,
      active: booleanValue(record.active, 'active'),
      data: jsonData(record.data),
      version: positiveInteger(record.version, 'version'),
    };
  }
  if (type === 'pricingRules') {
    const unitRate = Number(record.unitRate);
    const conversionFactor = Number(record.conversionFactor ?? 1);
    const wastagePercent = Number(record.wastagePercent ?? 0);
    if (!pricingModels.has(record.pricingModel) ||
        !Number.isFinite(unitRate) || unitRate < 0 ||
        !Number.isFinite(conversionFactor) || conversionFactor <= 0 ||
        !Number.isFinite(wastagePercent) ||
        wastagePercent < 0 || wastagePercent > 100) {
      throw new HttpError(400, 'invalid_pricing_rule');
    }
    return {
      id,
      code: text(record.code, 'code', 40).toUpperCase(),
      name: text(record.name, 'name'),
      pricingModel: record.pricingModel,
      unit: text(record.unit, 'unit', 30),
      unitRate,
      inputUnit: text(record.inputUnit ?? 'mm', 'input_unit', 30),
      conversionFactor,
      minimumQuantity: Number(record.minimumQuantity ?? 0),
      roundingDecimals: Number.isInteger(record.roundingDecimals)
        ? record.roundingDecimals
        : 2,
      wastagePercent,
      active: booleanValue(record.active, 'active'),
      data: jsonData(record.data),
      version: positiveInteger(record.version, 'version'),
    };
  }
  if (type === 'termsTemplates') {
    if (!Array.isArray(record.paymentSchedule) ||
        !record.paymentSchedule.every(isRecord)) {
      throw new HttpError(400, 'invalid_payment_schedule');
    }
    return {
      id,
      name: text(record.name, 'name'),
      notes: optionalText(record.notes, 'notes', 8000),
      terms: optionalText(record.terms, 'terms', 8000),
      assumptions: optionalText(record.assumptions, 'assumptions', 8000),
      warranty: optionalText(record.warranty, 'warranty', 8000),
      paymentSchedule: record.paymentSchedule,
      active: booleanValue(record.active, 'active'),
      data: jsonData(record.data),
      version: positiveInteger(record.version, 'version'),
    };
  }
  if (type === 'documentTemplates') {
    if (!Array.isArray(record.sectionOrder) ||
        record.sectionOrder.some((value) => typeof value !== 'string')) {
      throw new HttpError(400, 'invalid_section_order');
    }
    return {
      id,
      name: text(record.name, 'name'),
      brandName: optionalText(record.brandName, 'brand_name', 120),
      logoStoragePath: typeof record.logoStoragePath === 'string'
        ? record.logoStoragePath
        : null,
      accentColor: typeof record.accentColor === 'string'
        ? record.accentColor
        : '#B77C55',
      sectionOrder: record.sectionOrder,
      data: jsonData(record.data),
      active: booleanValue(record.active, 'active'),
      version: positiveInteger(record.version, 'version'),
    };
  }
  throw new HttpError(400, 'invalid_catalog_type');
}

async function upsertRecord(client, workspaceId, type, record) {
  const validated = validateRecord(type, record);
  const definition = writeDefinitions[type];
  if (!definition) throw new HttpError(400, 'invalid_catalog_type');

  if (type === 'lineItems') {
    const duplicate = await client.query(
      `SELECT id FROM quotation_line_item_catalog
       WHERE workspace_id = $1 AND lower(btrim(name)) = lower(btrim($2))
         AND id <> $3 LIMIT 1`,
      [workspaceId, validated.name, validated.id],
    );
    if (duplicate.rows.length > 0) {
      throw new HttpError(409, 'duplicate_line_item_name');
    }
    await client.query(
      `INSERT INTO quotation_line_item_catalog
       (workspace_id,id,name,basic_rate_per_sqft,medium_rate_per_sqft,
        luxury_rate_per_sqft,active,version)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
       ON CONFLICT (workspace_id,id) DO UPDATE SET
         name=EXCLUDED.name,basic_rate_per_sqft=EXCLUDED.basic_rate_per_sqft,
         medium_rate_per_sqft=EXCLUDED.medium_rate_per_sqft,
         luxury_rate_per_sqft=EXCLUDED.luxury_rate_per_sqft,
         active=EXCLUDED.active,version=EXCLUDED.version,updated_at=now()`,
      [workspaceId, validated.id, validated.name,
        validated.basicRatePerSqft, validated.mediumRatePerSqft,
        validated.luxuryRatePerSqft, validated.active, validated.version],
    );
  } else if (type === 'packages') {
    await client.query(
      `INSERT INTO quotation_packages
       (workspace_id,id,code,name,description,version,active,data)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
       ON CONFLICT (workspace_id,id) DO UPDATE SET
         code=EXCLUDED.code,name=EXCLUDED.name,description=EXCLUDED.description,
         version=EXCLUDED.version,active=EXCLUDED.active,data=EXCLUDED.data,
         updated_at=now()`,
      [workspaceId, validated.id, validated.code, validated.name,
        validated.description, validated.version, validated.active,
        JSON.stringify(validated.data)],
    );
  } else if (type === 'rooms') {
    await client.query(
      `INSERT INTO catalog_quotation_rooms
       (workspace_id,id,code,name,position,active,data,version)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
       ON CONFLICT (workspace_id,id) DO UPDATE SET
         code=EXCLUDED.code,name=EXCLUDED.name,position=EXCLUDED.position,
         active=EXCLUDED.active,data=EXCLUDED.data,version=EXCLUDED.version,
         updated_at=now()`,
      [workspaceId, validated.id, validated.code, validated.name,
        validated.position, validated.active, JSON.stringify(validated.data),
        validated.version],
    );
  } else if (type === 'components') {
    await client.query(
      `INSERT INTO catalog_quotation_components
       (workspace_id,id,code,name,room_id,description,pricing_model,uom,
        active,data,version)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
       ON CONFLICT (workspace_id,id) DO UPDATE SET
         code=EXCLUDED.code,name=EXCLUDED.name,room_id=EXCLUDED.room_id,
         description=EXCLUDED.description,pricing_model=EXCLUDED.pricing_model,
         uom=EXCLUDED.uom,active=EXCLUDED.active,data=EXCLUDED.data,
         version=EXCLUDED.version,updated_at=now()`,
      [workspaceId, validated.id, validated.code, validated.name,
        validated.roomId, validated.description, validated.pricingModel,
        validated.uom, validated.active, JSON.stringify(validated.data),
        validated.version],
    );
  } else if (type === 'services') {
    await client.query(
      `INSERT INTO catalog_quotation_services
       (workspace_id,id,code,name,description,pricing_model,uom,active,data,version)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
       ON CONFLICT (workspace_id,id) DO UPDATE SET
         code=EXCLUDED.code,name=EXCLUDED.name,description=EXCLUDED.description,
         pricing_model=EXCLUDED.pricing_model,uom=EXCLUDED.uom,
         active=EXCLUDED.active,data=EXCLUDED.data,version=EXCLUDED.version,
         updated_at=now()`,
      [workspaceId, validated.id, validated.code, validated.name,
        validated.description, validated.pricingModel, validated.uom,
        validated.active, JSON.stringify(validated.data), validated.version],
    );
  } else if (type === 'materials') {
    await client.query(
      `INSERT INTO catalog_quotation_materials
       (workspace_id,id,code,name,specifications,active,data,version)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
       ON CONFLICT (workspace_id,id) DO UPDATE SET
         code=EXCLUDED.code,name=EXCLUDED.name,
         specifications=EXCLUDED.specifications,active=EXCLUDED.active,
         data=EXCLUDED.data,version=EXCLUDED.version,updated_at=now()`,
      [workspaceId, validated.id, validated.code, validated.name,
        validated.specifications, validated.active, JSON.stringify(validated.data),
        validated.version],
    );
  } else if (type === 'finishes') {
    await client.query(
      `INSERT INTO catalog_quotation_finishes
       (workspace_id,id,code,name,brand,price_adjustment,active,data,version)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
       ON CONFLICT (workspace_id,id) DO UPDATE SET
         code=EXCLUDED.code,name=EXCLUDED.name,brand=EXCLUDED.brand,
         price_adjustment=EXCLUDED.price_adjustment,active=EXCLUDED.active,
         data=EXCLUDED.data,version=EXCLUDED.version,updated_at=now()`,
      [workspaceId, validated.id, validated.code, validated.name,
        validated.brand, validated.priceAdjustment, validated.active,
        JSON.stringify(validated.data), validated.version],
    );
  } else if (type === 'hardware') {
    await client.query(
      `INSERT INTO catalog_quotation_hardware
       (workspace_id,id,code,name,brand,sku,unit,unit_rate,active,data,version)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
       ON CONFLICT (workspace_id,id) DO UPDATE SET
         code=EXCLUDED.code,name=EXCLUDED.name,brand=EXCLUDED.brand,
         sku=EXCLUDED.sku,unit=EXCLUDED.unit,unit_rate=EXCLUDED.unit_rate,
         active=EXCLUDED.active,data=EXCLUDED.data,version=EXCLUDED.version,
         updated_at=now()`,
      [workspaceId, validated.id, validated.code, validated.name,
        validated.brand, validated.sku, validated.unit, validated.unitRate,
        validated.active, JSON.stringify(validated.data), validated.version],
    );
  } else if (type === 'pricingRules') {
    await client.query(
      `INSERT INTO quotation_pricing_rules
       (workspace_id,id,code,name,pricing_model,unit,unit_rate,input_unit,
        conversion_factor,minimum_quantity,rounding_decimals,wastage_percent,
        active,data,version)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15)
       ON CONFLICT (workspace_id,id) DO UPDATE SET
         code=EXCLUDED.code,name=EXCLUDED.name,
         pricing_model=EXCLUDED.pricing_model,unit=EXCLUDED.unit,
         unit_rate=EXCLUDED.unit_rate,input_unit=EXCLUDED.input_unit,
         conversion_factor=EXCLUDED.conversion_factor,
         minimum_quantity=EXCLUDED.minimum_quantity,
         rounding_decimals=EXCLUDED.rounding_decimals,
         wastage_percent=EXCLUDED.wastage_percent,active=EXCLUDED.active,
         data=EXCLUDED.data,version=EXCLUDED.version,updated_at=now()`,
      [workspaceId, validated.id, validated.code, validated.name,
        validated.pricingModel, validated.unit, validated.unitRate,
        validated.inputUnit, validated.conversionFactor,
        validated.minimumQuantity, validated.roundingDecimals,
        validated.wastagePercent, validated.active, JSON.stringify(validated.data),
        validated.version],
    );
  } else if (type === 'termsTemplates') {
    await client.query(
      `INSERT INTO proposal_terms_templates
       (workspace_id,id,name,notes,terms,assumptions,warranty,payment_schedule,
        active,data,version)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
       ON CONFLICT (workspace_id,id) DO UPDATE SET
         name=EXCLUDED.name,notes=EXCLUDED.notes,terms=EXCLUDED.terms,
         assumptions=EXCLUDED.assumptions,warranty=EXCLUDED.warranty,
         payment_schedule=EXCLUDED.payment_schedule,active=EXCLUDED.active,
         data=EXCLUDED.data,version=EXCLUDED.version,updated_at=now()`,
      [workspaceId, validated.id, validated.name, validated.notes,
        validated.terms, validated.assumptions, validated.warranty,
        JSON.stringify(validated.paymentSchedule), validated.active,
        JSON.stringify(validated.data), validated.version],
    );
  } else if (type === 'documentTemplates') {
    await client.query(
      `INSERT INTO proposal_document_templates
       (workspace_id,id,name,brand_name,logo_storage_path,accent_color,
        section_order,data,active,version)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
       ON CONFLICT (workspace_id,id) DO UPDATE SET
         name=EXCLUDED.name,brand_name=EXCLUDED.brand_name,
         logo_storage_path=EXCLUDED.logo_storage_path,
         accent_color=EXCLUDED.accent_color,
         section_order=EXCLUDED.section_order,data=EXCLUDED.data,
         active=EXCLUDED.active,version=EXCLUDED.version,updated_at=now()`,
      [workspaceId, validated.id, validated.name, validated.brandName,
        validated.logoStoragePath, validated.accentColor,
        JSON.stringify(validated.sectionOrder), JSON.stringify(validated.data),
        validated.active, validated.version],
    );
  }
  return validated;
}

async function seedStarterLineItems(client, workspaceId) {
  await client.query(
    `INSERT INTO quotation_line_item_catalog
     (workspace_id,id,name)
     SELECT $1,starter.id,starter.name
     FROM (VALUES
       ('starter-wardrobe','Wardrobe'),
       ('starter-kitchen-cabinet','Kitchen cabinet'),
       ('starter-tv-unit','TV unit'),
       ('starter-vanity','Vanity'),
       ('starter-shoe-rack','Shoe rack'),
       ('starter-loft-storage','Loft storage')
     ) AS starter(id,name)
     WHERE NOT EXISTS (
       SELECT 1 FROM quotation_line_item_catalog
       WHERE workspace_id = $1
     )
     ON CONFLICT (workspace_id,id) DO NOTHING`,
    [workspaceId],
  );
}

function createQuotationCatalogHandler({
  authenticate = authenticateRequest,
  withWorkspace = withWorkspaceTransaction,
  rateLimit = null,
  env = process.env,
  logger = console.error,
} = {}) {
  return async function quotationCatalogHandler(req, res) {
    const requestId = attachRequestId(res);
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Vary', 'Authorization');
    if (!['GET', 'PUT'].includes(req.method)) {
      res.setHeader('Allow', 'GET, PUT');
      return res.status(405).json({ error: 'method_not_allowed' });
    }

    try {
      const { userId } = await authenticate(req);
      if (rateLimit) {
        await rateLimit(
          userId,
          req.method === 'GET'
            ? 'quotation_catalog_read'
            : 'quotation_catalog_write',
          { limit: req.method === 'GET' ? 60 : 20, windowSeconds: 60 },
        );
      }
      const workspaceId = getWorkspaceId(req);
      if (req.method === 'GET') {
        const catalog = await withWorkspace(
          userId,
          workspaceId,
          async (client, access) => {
            requirePermission(access, 'viewFinancials');
            await seedStarterLineItems(client, workspaceId);
            const result = {};
            for (const [type, query] of Object.entries(catalogQueries)) {
              const rows = await client.query(query, [workspaceId]);
              result[type] = rows.rows;
            }
            return result;
          },
        );
        return res.status(200).json({ catalog });
      }

      if (!isRecord(req.body) ||
          typeof req.body.type !== 'string' ||
          !isRecord(req.body.record)) {
        throw new HttpError(400, 'invalid_catalog_payload');
      }
      if (!Object.hasOwn(writeDefinitions, req.body.type)) {
        throw new HttpError(400, 'invalid_catalog_type');
      }
      await withWorkspace(userId, workspaceId, async (client, access) => {
        requirePermission(access, 'manageFinancials');
        await upsertRecord(
          client,
          workspaceId,
          req.body.type,
          req.body.record,
        );
      });
      return res.status(200).json({ saved: true, type: req.body.type });
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
      logger('Quotation catalog request failed.', {
        requestId,
        errorName: error instanceof Error ? error.name : 'UnknownError',
        ...(typeof error?.code === 'string' ? { errorCode: error.code } : {}),
      });
      return res.status(500).json({ error: 'internal_server_error' });
    }
  };
}

const handler = createQuotationCatalogHandler({
  rateLimit: enforceUserRateLimit,
});
Object.assign(handler, {
  createQuotationCatalogHandler,
  validateRecord,
  upsertRecord,
});

module.exports = handler;
