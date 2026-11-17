CREATE TABLE crm_customers (
    workspace_id uuid NOT NULL REFERENCES workspaces (id) ON DELETE CASCADE,
    id text NOT NULL,
    name text NOT NULL,
    project text NOT NULL DEFAULT '',
    stage text NOT NULL,
    value text NOT NULL DEFAULT '',
    email text NOT NULL DEFAULT '',
    phone text NOT NULL DEFAULT '',
    notes text NOT NULL DEFAULT '',
    initials text NOT NULL DEFAULT '',
    tint bigint NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (workspace_id, id),
    CONSTRAINT crm_customers_name_length
        CHECK (char_length(btrim(name)) BETWEEN 1 AND 160)
);

CREATE TABLE customer_requirements (
    workspace_id uuid NOT NULL,
    customer_id text NOT NULL,
    rooms text[] NOT NULL,
    style text NOT NULL,
    budget_min numeric(14, 2),
    budget_max numeric(14, 2),
    start_date date,
    target_date date,
    brief text NOT NULL DEFAULT '',
    PRIMARY KEY (workspace_id, customer_id),
    CONSTRAINT customer_requirements_customer_fk
        FOREIGN KEY (workspace_id, customer_id)
        REFERENCES crm_customers (workspace_id, id)
        ON DELETE CASCADE,
    CONSTRAINT customer_requirements_budget_range
        CHECK (
            budget_min IS NULL OR budget_max IS NULL OR
            budget_min <= budget_max
        ),
    CONSTRAINT customer_requirements_date_range
        CHECK (
            start_date IS NULL OR target_date IS NULL OR
            start_date <= target_date
        )
);

CREATE TABLE workspace_pipeline_stages (
    workspace_id uuid NOT NULL REFERENCES workspaces (id) ON DELETE CASCADE,
    position integer NOT NULL CHECK (position >= 0),
    name text NOT NULL,
    PRIMARY KEY (workspace_id, position),
    CONSTRAINT workspace_pipeline_stages_name_length
        CHECK (char_length(btrim(name)) BETWEEN 1 AND 40)
);
CREATE UNIQUE INDEX workspace_pipeline_stages_unique_name_idx
    ON workspace_pipeline_stages (workspace_id, lower(name));

CREATE TABLE studio_projects (
    workspace_id uuid NOT NULL REFERENCES workspaces (id) ON DELETE CASCADE,
    id text NOT NULL,
    name text NOT NULL,
    location text NOT NULL DEFAULT '',
    status text NOT NULL,
    customer_id text,
    target_date date,
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (workspace_id, id),
    CONSTRAINT studio_projects_customer_fk
        FOREIGN KEY (workspace_id, customer_id)
        REFERENCES crm_customers (workspace_id, id)
        ON DELETE SET NULL (customer_id)
);

CREATE TABLE workspace_activities (
    workspace_id uuid NOT NULL REFERENCES workspaces (id) ON DELETE CASCADE,
    id text NOT NULL,
    customer_id text,
    customer_name text NOT NULL,
    kind text NOT NULL,
    title text NOT NULL,
    details text NOT NULL DEFAULT '',
    actor text NOT NULL,
    occurred_at timestamptz NOT NULL,
    PRIMARY KEY (workspace_id, id)
);

CREATE TABLE workspace_preferences (
    workspace_id uuid PRIMARY KEY REFERENCES workspaces (id) ON DELETE CASCADE,
    studio_name text NOT NULL,
    default_pipeline_stage text NOT NULL,
    active_persona_id text NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT workspace_preferences_name_length
        CHECK (char_length(btrim(studio_name)) BETWEEN 1 AND 80)
);

CREATE INDEX crm_customers_workspace_name_idx
    ON crm_customers (workspace_id, lower(name));
CREATE INDEX studio_projects_workspace_updated_idx
    ON studio_projects (workspace_id, updated_at DESC);
CREATE INDEX workspace_activities_workspace_time_idx
    ON workspace_activities (workspace_id, occurred_at DESC);

DO $$
DECLARE
    table_name text;
BEGIN
    FOREACH table_name IN ARRAY ARRAY[
        'crm_customers',
        'customer_requirements',
        'workspace_pipeline_stages',
        'studio_projects',
        'workspace_activities',
        'workspace_preferences'
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
