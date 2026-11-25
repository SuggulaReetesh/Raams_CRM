CREATE TABLE quotation_packages (
    workspace_id uuid NOT NULL REFERENCES workspaces (id) ON DELETE CASCADE,
    id text NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    description text NOT NULL DEFAULT '',
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    active boolean NOT NULL DEFAULT true,
    data jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (workspace_id, id),
    CONSTRAINT quotation_packages_code_unique UNIQUE (workspace_id, code),
    CONSTRAINT quotation_packages_code_length
        CHECK (char_length(btrim(code)) BETWEEN 1 AND 40),
    CONSTRAINT quotation_packages_name_length
        CHECK (char_length(btrim(name)) BETWEEN 1 AND 120)
);

CREATE TABLE quotation_package_inclusions (
    workspace_id uuid NOT NULL,
    id text NOT NULL,
    package_id text NOT NULL,
    catalog_type text NOT NULL,
    catalog_id text NOT NULL,
    inclusion_kind text NOT NULL,
    quantity numeric(12, 3),
    data jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (workspace_id, id),
    CONSTRAINT quotation_package_inclusions_package_fk
        FOREIGN KEY (workspace_id, package_id)
        REFERENCES quotation_packages (workspace_id, id)
        ON DELETE CASCADE,
    CONSTRAINT quotation_package_inclusions_type
        CHECK (catalog_type IN (
            'room','component','service','material','finish','hardware'
        )),
    CONSTRAINT quotation_package_inclusions_kind
        CHECK (inclusion_kind IN ('included','optional','excluded','default'))
);

CREATE TABLE catalog_quotation_rooms (
    workspace_id uuid NOT NULL REFERENCES workspaces (id) ON DELETE CASCADE,
    id text NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    position integer NOT NULL DEFAULT 0 CHECK (position >= 0),
    active boolean NOT NULL DEFAULT true,
    data jsonb NOT NULL DEFAULT '{}'::jsonb,
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (workspace_id, id),
    CONSTRAINT catalog_quotation_rooms_code_unique UNIQUE (workspace_id, code),
    CONSTRAINT catalog_quotation_rooms_name_length
        CHECK (char_length(btrim(name)) BETWEEN 1 AND 120)
);

CREATE TABLE catalog_quotation_components (
    workspace_id uuid NOT NULL REFERENCES workspaces (id) ON DELETE CASCADE,
    id text NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    room_id text,
    description text NOT NULL DEFAULT '',
    pricing_model text NOT NULL,
    uom text NOT NULL,
    active boolean NOT NULL DEFAULT true,
    data jsonb NOT NULL DEFAULT '{}'::jsonb,
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (workspace_id, id),
    CONSTRAINT catalog_quotation_components_code_unique UNIQUE (workspace_id, code),
    CONSTRAINT catalog_quotation_components_pricing_model
        CHECK (pricing_model IN (
            'fixed','unit','point','lumpsum','area','running','volume'
        )),
    CONSTRAINT catalog_quotation_components_uom
        CHECK (char_length(btrim(uom)) BETWEEN 1 AND 30),
    CONSTRAINT catalog_quotation_components_room_fk
        FOREIGN KEY (workspace_id, room_id)
        REFERENCES catalog_quotation_rooms (workspace_id, id)
        ON DELETE SET NULL
);

CREATE TABLE catalog_quotation_services (
    workspace_id uuid NOT NULL REFERENCES workspaces (id) ON DELETE CASCADE,
    id text NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    description text NOT NULL DEFAULT '',
    pricing_model text NOT NULL,
    uom text NOT NULL,
    active boolean NOT NULL DEFAULT true,
    data jsonb NOT NULL DEFAULT '{}'::jsonb,
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (workspace_id, id),
    CONSTRAINT catalog_quotation_services_code_unique UNIQUE (workspace_id, code),
    CONSTRAINT catalog_quotation_services_pricing_model
        CHECK (pricing_model IN (
            'fixed','unit','point','lumpsum','area','running','volume'
        ))
);

CREATE TABLE catalog_quotation_materials (
    workspace_id uuid NOT NULL REFERENCES workspaces (id) ON DELETE CASCADE,
    id text NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    specifications text NOT NULL DEFAULT '',
    active boolean NOT NULL DEFAULT true,
    data jsonb NOT NULL DEFAULT '{}'::jsonb,
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (workspace_id, id),
    CONSTRAINT catalog_quotation_materials_code_unique UNIQUE (workspace_id, code)
);

CREATE TABLE catalog_quotation_finishes (
    workspace_id uuid NOT NULL REFERENCES workspaces (id) ON DELETE CASCADE,
    id text NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    brand text NOT NULL DEFAULT '',
    price_adjustment numeric(14, 2) NOT NULL DEFAULT 0,
    active boolean NOT NULL DEFAULT true,
    data jsonb NOT NULL DEFAULT '{}'::jsonb,
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (workspace_id, id),
    CONSTRAINT catalog_quotation_finishes_code_unique UNIQUE (workspace_id, code)
);

CREATE TABLE catalog_quotation_hardware (
    workspace_id uuid NOT NULL REFERENCES workspaces (id) ON DELETE CASCADE,
    id text NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    brand text NOT NULL,
    sku text NOT NULL DEFAULT '',
    unit text NOT NULL DEFAULT 'No',
    unit_rate numeric(14, 2) NOT NULL CHECK (unit_rate >= 0),
    active boolean NOT NULL DEFAULT true,
    data jsonb NOT NULL DEFAULT '{}'::jsonb,
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (workspace_id, id),
    CONSTRAINT catalog_quotation_hardware_code_unique UNIQUE (workspace_id, code)
);

CREATE TABLE quotation_pricing_rules (
    workspace_id uuid NOT NULL REFERENCES workspaces (id) ON DELETE CASCADE,
    id text NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    pricing_model text NOT NULL,
    unit text NOT NULL,
    unit_rate numeric(14, 2) NOT NULL CHECK (unit_rate >= 0),
    input_unit text NOT NULL DEFAULT 'mm',
    conversion_factor numeric(20, 10) NOT NULL DEFAULT 1
        CHECK (conversion_factor > 0),
    minimum_quantity numeric(12, 3) NOT NULL DEFAULT 0
        CHECK (minimum_quantity >= 0),
    rounding_decimals integer NOT NULL DEFAULT 2
        CHECK (rounding_decimals BETWEEN 0 AND 6),
    wastage_percent numeric(5, 2) NOT NULL DEFAULT 0
        CHECK (wastage_percent BETWEEN 0 AND 100),
    active boolean NOT NULL DEFAULT true,
    data jsonb NOT NULL DEFAULT '{}'::jsonb,
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (workspace_id, id),
    CONSTRAINT quotation_pricing_rules_code_unique UNIQUE (workspace_id, code),
    CONSTRAINT quotation_pricing_rules_model
        CHECK (pricing_model IN (
            'fixed','unit','point','lumpsum','area','running','volume'
        ))
);

CREATE TABLE proposal_terms_templates (
    workspace_id uuid NOT NULL REFERENCES workspaces (id) ON DELETE CASCADE,
    id text NOT NULL,
    name text NOT NULL,
    notes text NOT NULL DEFAULT '',
    terms text NOT NULL DEFAULT '',
    assumptions text NOT NULL DEFAULT '',
    warranty text NOT NULL DEFAULT '',
    payment_schedule jsonb NOT NULL DEFAULT '[]'::jsonb,
    active boolean NOT NULL DEFAULT true,
    data jsonb NOT NULL DEFAULT '{}'::jsonb,
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (workspace_id, id),
    CONSTRAINT proposal_terms_templates_name_unique UNIQUE (workspace_id, name)
);

CREATE TABLE proposal_document_templates (
    workspace_id uuid NOT NULL REFERENCES workspaces (id) ON DELETE CASCADE,
    id text NOT NULL,
    name text NOT NULL,
    brand_name text NOT NULL DEFAULT '',
    logo_storage_path text,
    accent_color text NOT NULL DEFAULT '#B77C55',
    section_order jsonb NOT NULL DEFAULT '[
        "cover","metadata","scope","boq","summary","specifications",
        "terms","payment","warranty","footer"
    ]'::jsonb,
    data jsonb NOT NULL DEFAULT '{}'::jsonb,
    active boolean NOT NULL DEFAULT true,
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (workspace_id, id),
    CONSTRAINT proposal_document_templates_name_unique UNIQUE (workspace_id, name)
);

CREATE INDEX quotation_package_inclusions_package_idx
    ON quotation_package_inclusions (workspace_id, package_id);
CREATE INDEX catalog_quotation_components_room_idx
    ON catalog_quotation_components (workspace_id, room_id);
CREATE INDEX catalog_quotation_hardware_active_idx
    ON catalog_quotation_hardware (workspace_id, active);

DO $$
DECLARE
    table_name text;
BEGIN
    FOREACH table_name IN ARRAY ARRAY[
        'quotation_packages',
        'quotation_package_inclusions',
        'catalog_quotation_rooms',
        'catalog_quotation_components',
        'catalog_quotation_services',
        'catalog_quotation_materials',
        'catalog_quotation_finishes',
        'catalog_quotation_hardware',
        'quotation_pricing_rules',
        'proposal_terms_templates',
        'proposal_document_templates'
    ]
    LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', table_name);
        EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', table_name);
        EXECUTE format(
            'CREATE POLICY %I ON %I USING (
                workspace_id IN (
                    SELECT wm.workspace_id
                    FROM workspace_memberships wm
                    WHERE wm.user_id =
                        NULLIF(current_setting(''app.user_id'', true), '''')::uuid
                      AND wm.status = ''active''
                )
            ) WITH CHECK (
                workspace_id IN (
                    SELECT wm.workspace_id
                    FROM workspace_memberships wm
                    WHERE wm.user_id =
                        NULLIF(current_setting(''app.user_id'', true), '''')::uuid
                      AND wm.status = ''active''
                )
            )',
            table_name || '_member_policy',
            table_name
        );
    END LOOP;
END
$$;
