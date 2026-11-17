CREATE TABLE finance_documents (
    workspace_id uuid NOT NULL REFERENCES workspaces (id) ON DELETE CASCADE,
    id text NOT NULL,
    document_type text NOT NULL,
    number text NOT NULL,
    project_id text NOT NULL,
    customer_id text NOT NULL,
    title text NOT NULL,
    status text NOT NULL,
    currency_symbol text NOT NULL,
    tax_rate numeric(5, 2) NOT NULL CHECK (tax_rate BETWEEN 0 AND 100),
    subtotal numeric(14, 2) NOT NULL CHECK (subtotal >= 0),
    tax_total numeric(14, 2) NOT NULL CHECK (tax_total >= 0),
    total numeric(14, 2) NOT NULL CHECK (total = subtotal + tax_total),
    document_date date,
    due_date date,
    memo text NOT NULL DEFAULT '',
    data jsonb NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (workspace_id, id),
    CONSTRAINT finance_documents_type CHECK (
        document_type IN ('quotation', 'proposal', 'invoice')
    ),
    CONSTRAINT finance_documents_number_unique
        UNIQUE (workspace_id, document_type, number),
    CONSTRAINT finance_documents_tax_total
        CHECK (tax_total = round(subtotal * tax_rate / 100, 2)),
    CONSTRAINT finance_documents_project_fk
        FOREIGN KEY (workspace_id, project_id)
        REFERENCES studio_projects (workspace_id, id),
    CONSTRAINT finance_documents_customer_fk
        FOREIGN KEY (workspace_id, customer_id)
        REFERENCES crm_customers (workspace_id, id)
);

CREATE TABLE finance_line_items (
    workspace_id uuid NOT NULL,
    document_id text NOT NULL,
    id text NOT NULL,
    description text NOT NULL,
    quantity numeric(12, 3) NOT NULL CHECK (quantity > 0),
    unit text NOT NULL,
    unit_rate numeric(14, 2) NOT NULL CHECK (unit_rate >= 0),
    amount numeric(14, 2)
        GENERATED ALWAYS AS (round(quantity * unit_rate, 2)) STORED,
    PRIMARY KEY (workspace_id, document_id, id),
    CONSTRAINT finance_line_items_document_fk
        FOREIGN KEY (workspace_id, document_id)
        REFERENCES finance_documents (workspace_id, id)
        ON DELETE CASCADE
);

CREATE TABLE finance_document_templates (
    workspace_id uuid NOT NULL REFERENCES workspaces (id) ON DELETE CASCADE,
    id text NOT NULL,
    name text NOT NULL,
    data jsonb NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (workspace_id, id),
    CONSTRAINT finance_document_templates_name_unique
        UNIQUE (workspace_id, name)
);

CREATE TABLE invoice_payments (
    workspace_id uuid NOT NULL,
    id text NOT NULL,
    invoice_id text NOT NULL,
    amount numeric(14, 2) NOT NULL CHECK (amount > 0),
    recorded_at timestamptz NOT NULL DEFAULT now(),
    recorded_by uuid NOT NULL,
    PRIMARY KEY (workspace_id, id),
    CONSTRAINT invoice_payments_invoice_fk
        FOREIGN KEY (workspace_id, invoice_id)
        REFERENCES finance_documents (workspace_id, id)
);

CREATE INDEX finance_documents_workspace_updated_idx
    ON finance_documents (workspace_id, updated_at DESC);
CREATE INDEX invoice_payments_workspace_invoice_idx
    ON invoice_payments (workspace_id, invoice_id, recorded_at DESC);

DO $$
DECLARE
    table_name text;
BEGIN
    FOREACH table_name IN ARRAY ARRAY[
        'finance_documents',
        'finance_line_items',
        'finance_document_templates',
        'invoice_payments'
    ]
    LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', table_name);
        EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', table_name);
        EXECUTE format(
            'CREATE POLICY %I ON %I USING (
                workspace_id IN (
                    SELECT id FROM workspaces
                    WHERE owner_user_id =
                        NULLIF(current_setting(''app.user_id'', true), '''')::uuid
                )
            ) WITH CHECK (
                workspace_id IN (
                    SELECT id FROM workspaces
                    WHERE owner_user_id =
                        NULLIF(current_setting(''app.user_id'', true), '''')::uuid
                )
            )',
            table_name || '_owner_policy',
            table_name
        );
    END LOOP;
END
$$;
