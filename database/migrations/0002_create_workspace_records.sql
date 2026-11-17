ALTER TABLE workspaces
    ADD CONSTRAINT workspaces_owner_user_id_unique UNIQUE (owner_user_id);

CREATE TABLE workspace_settings (
    workspace_id uuid PRIMARY KEY REFERENCES workspaces (id) ON DELETE CASCADE,
    data jsonb NOT NULL DEFAULT '{}'::jsonb,
    revision bigint NOT NULL DEFAULT 0 CHECK (revision >= 0),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE workspace_records (
    workspace_id uuid NOT NULL REFERENCES workspaces (id) ON DELETE CASCADE,
    collection text NOT NULL,
    record_id text NOT NULL,
    data jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (workspace_id, collection, record_id),
    CONSTRAINT workspace_records_collection CHECK (
        collection IN (
            'customers',
            'activities',
            'personas',
            'pipelineStages',
            'projects',
            'tasks',
            'milestones',
            'punchItems',
            'assets',
            'workLogs',
            'attendance',
            'approvals',
            'quotations',
            'templates',
            'proposals',
            'invoices',
            'communications'
        )
    ),
    CONSTRAINT workspace_records_id_length CHECK (
        char_length(record_id) BETWEEN 1 AND 160
    )
);

CREATE INDEX workspace_records_collection_idx
    ON workspace_records (workspace_id, collection, updated_at DESC);

ALTER TABLE workspaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE workspaces FORCE ROW LEVEL SECURITY;
CREATE POLICY workspaces_owner_policy ON workspaces
    USING (owner_user_id = NULLIF(current_setting('app.user_id', true), '')::uuid)
    WITH CHECK (owner_user_id = NULLIF(current_setting('app.user_id', true), '')::uuid);

ALTER TABLE workspace_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE workspace_settings FORCE ROW LEVEL SECURITY;
CREATE POLICY workspace_settings_owner_policy ON workspace_settings
    USING (
        workspace_id IN (
            SELECT id FROM workspaces
            WHERE owner_user_id =
                NULLIF(current_setting('app.user_id', true), '')::uuid
        )
    )
    WITH CHECK (
        workspace_id IN (
            SELECT id FROM workspaces
            WHERE owner_user_id =
                NULLIF(current_setting('app.user_id', true), '')::uuid
        )
    );

ALTER TABLE workspace_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE workspace_records FORCE ROW LEVEL SECURITY;
CREATE POLICY workspace_records_owner_policy ON workspace_records
    USING (
        workspace_id IN (
            SELECT id FROM workspaces
            WHERE owner_user_id =
                NULLIF(current_setting('app.user_id', true), '')::uuid
        )
    )
    WITH CHECK (
        workspace_id IN (
            SELECT id FROM workspaces
            WHERE owner_user_id =
                NULLIF(current_setting('app.user_id', true), '')::uuid
        )
    );
