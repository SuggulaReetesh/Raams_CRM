CREATE TABLE quotation_documents (
    workspace_id uuid NOT NULL REFERENCES workspaces (id) ON DELETE CASCADE,
    id text NOT NULL,
    number text NOT NULL,
    project_id text,
    customer_id text,
    title text NOT NULL,
    currency_symbol text NOT NULL DEFAULT '₹',
    status text NOT NULL DEFAULT 'Draft',
    validity_date date,
    created_by uuid,
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (workspace_id, id),
    CONSTRAINT quotation_documents_number_unique
        UNIQUE (workspace_id, number),
    CONSTRAINT quotation_documents_status
        CHECK (status IN ('Draft','Pending approval','Approved','Rejected'))
);

CREATE TABLE quotation_revisions (
    workspace_id uuid NOT NULL,
    id text NOT NULL,
    document_id text NOT NULL,
    revision_number integer NOT NULL CHECK (revision_number > 0),
    snapshot jsonb NOT NULL,
    subtotal numeric(14, 2) NOT NULL CHECK (subtotal >= 0),
    discount_amount numeric(14, 2) NOT NULL CHECK (discount_amount >= 0),
    tax_amount numeric(14, 2) NOT NULL CHECK (tax_amount >= 0),
    grand_total numeric(14, 2) NOT NULL CHECK (grand_total >= 0),
    immutable boolean NOT NULL DEFAULT false,
    created_by uuid,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (workspace_id, id),
    CONSTRAINT quotation_revisions_document_fk
        FOREIGN KEY (workspace_id, document_id)
        REFERENCES quotation_documents (workspace_id, id)
        ON DELETE CASCADE,
    CONSTRAINT quotation_revisions_number_unique
        UNIQUE (workspace_id, document_id, revision_number)
);

CREATE TABLE quotation_sections (
    workspace_id uuid NOT NULL,
    id text NOT NULL,
    revision_id text NOT NULL,
    section_type text NOT NULL,
    room_id text,
    name text NOT NULL,
    position integer NOT NULL DEFAULT 0 CHECK (position >= 0),
    data jsonb NOT NULL DEFAULT '{}'::jsonb,
    subtotal numeric(14, 2) NOT NULL CHECK (subtotal >= 0),
    PRIMARY KEY (workspace_id, id),
    CONSTRAINT quotation_sections_revision_fk
        FOREIGN KEY (workspace_id, revision_id)
        REFERENCES quotation_revisions (workspace_id, id)
        ON DELETE CASCADE,
    CONSTRAINT quotation_sections_type
        CHECK (section_type IN ('room','service','other'))
);

CREATE TABLE quotation_lines (
    workspace_id uuid NOT NULL,
    id text NOT NULL,
    revision_id text NOT NULL,
    section_id text NOT NULL,
    component_id text,
    service_id text,
    package_id text,
    pricing_rule_id text,
    description text NOT NULL,
    quantity numeric(12, 3) NOT NULL CHECK (quantity > 0),
    unit text NOT NULL,
    unit_rate numeric(14, 2) NOT NULL CHECK (unit_rate >= 0),
    base_amount numeric(14, 2) NOT NULL CHECK (base_amount >= 0),
    hardware_amount numeric(14, 2) NOT NULL CHECK (hardware_amount >= 0),
    final_amount numeric(14, 2) NOT NULL CHECK (final_amount >= 0),
    position integer NOT NULL DEFAULT 0 CHECK (position >= 0),
    data jsonb NOT NULL DEFAULT '{}'::jsonb,
    PRIMARY KEY (workspace_id, id),
    CONSTRAINT quotation_lines_revision_fk
        FOREIGN KEY (workspace_id, revision_id)
        REFERENCES quotation_revisions (workspace_id, id)
        ON DELETE CASCADE,
    CONSTRAINT quotation_lines_section_fk
        FOREIGN KEY (workspace_id, section_id)
        REFERENCES quotation_sections (workspace_id, id)
        ON DELETE CASCADE
);

CREATE TABLE quotation_line_dimensions (
    workspace_id uuid NOT NULL,
    line_id text NOT NULL,
    length_mm numeric(12, 3),
    height_mm numeric(12, 3),
    width_mm numeric(12, 3),
    depth_mm numeric(12, 3),
    billable_quantity numeric(14, 6) NOT NULL,
    PRIMARY KEY (workspace_id, line_id),
    CONSTRAINT quotation_line_dimensions_line_fk
        FOREIGN KEY (workspace_id, line_id)
        REFERENCES quotation_lines (workspace_id, id)
        ON DELETE CASCADE
);

CREATE TABLE quotation_line_hardware (
    workspace_id uuid NOT NULL,
    id text NOT NULL,
    line_id text NOT NULL,
    hardware_id text,
    name text NOT NULL,
    brand text NOT NULL DEFAULT '',
    sku text NOT NULL DEFAULT '',
    quantity numeric(12, 3) NOT NULL CHECK (quantity > 0),
    unit text NOT NULL,
    unit_rate numeric(14, 2) NOT NULL CHECK (unit_rate >= 0),
    amount numeric(14, 2) NOT NULL CHECK (amount >= 0),
    PRIMARY KEY (workspace_id, id),
    CONSTRAINT quotation_line_hardware_line_fk
        FOREIGN KEY (workspace_id, line_id)
        REFERENCES quotation_lines (workspace_id, id)
        ON DELETE CASCADE
);

CREATE TABLE quotation_discounts (
    workspace_id uuid NOT NULL,
    revision_id text NOT NULL,
    scope_type text NOT NULL,
    scope_id text NOT NULL DEFAULT '',
    discount_percent numeric(5, 2) NOT NULL
        CHECK (discount_percent >= 0 AND discount_percent <= 100),
    discount_amount numeric(14, 2) NOT NULL CHECK (discount_amount >= 0),
    PRIMARY KEY (workspace_id, revision_id, scope_type, scope_id),
    CONSTRAINT quotation_discounts_revision_fk
        FOREIGN KEY (workspace_id, revision_id)
        REFERENCES quotation_revisions (workspace_id, id)
        ON DELETE CASCADE,
    CONSTRAINT quotation_discounts_scope
        CHECK (scope_type IN ('boq','room','section','line'))
);

CREATE TABLE quotation_calculation_audit (
    workspace_id uuid NOT NULL,
    id text NOT NULL,
    revision_id text NOT NULL,
    line_id text NOT NULL,
    calculator_version text NOT NULL,
    pricing_rule_version integer NOT NULL,
    catalog_package_version integer,
    input_snapshot jsonb NOT NULL,
    result_snapshot jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (workspace_id, id),
    CONSTRAINT quotation_calculation_audit_revision_fk
        FOREIGN KEY (workspace_id, revision_id)
        REFERENCES quotation_revisions (workspace_id, id)
        ON DELETE CASCADE,
    CONSTRAINT quotation_calculation_audit_line_fk
        FOREIGN KEY (workspace_id, line_id)
        REFERENCES quotation_lines (workspace_id, id)
        ON DELETE CASCADE
);

CREATE INDEX quotation_revisions_document_idx
    ON quotation_revisions (workspace_id, document_id, revision_number DESC);
CREATE INDEX quotation_lines_revision_idx
    ON quotation_lines (workspace_id, revision_id, position);
CREATE INDEX quotation_sections_revision_idx
    ON quotation_sections (workspace_id, revision_id, position);
CREATE INDEX quotation_calculation_audit_revision_idx
    ON quotation_calculation_audit (workspace_id, revision_id, created_at DESC);

DO $$
DECLARE
    table_name text;
BEGIN
    FOREACH table_name IN ARRAY ARRAY[
        'quotation_documents',
        'quotation_revisions',
        'quotation_sections',
        'quotation_lines',
        'quotation_line_dimensions',
        'quotation_line_hardware',
        'quotation_discounts',
        'quotation_calculation_audit'
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
