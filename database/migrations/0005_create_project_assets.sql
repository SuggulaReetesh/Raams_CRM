CREATE TABLE project_assets (
    workspace_id uuid NOT NULL REFERENCES workspaces (id) ON DELETE CASCADE,
    id text NOT NULL,
    project_id text NOT NULL,
    storage_path text NOT NULL UNIQUE,
    name text NOT NULL,
    mime_type text NOT NULL,
    kind text NOT NULL,
    caption text NOT NULL DEFAULT '',
    byte_length integer NOT NULL CHECK (byte_length BETWEEN 1 AND 1048576),
    added_by text NOT NULL,
    added_at timestamptz NOT NULL,
    PRIMARY KEY (workspace_id, id),
    CONSTRAINT project_assets_project_fk
        FOREIGN KEY (workspace_id, project_id)
        REFERENCES studio_projects (workspace_id, id)
        ON DELETE CASCADE,
    CONSTRAINT project_assets_mime_type CHECK (
        mime_type IN (
            'image/jpeg',
            'image/png',
            'image/webp',
            'application/pdf',
            'text/plain',
            'text/csv',
            'application/msword',
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'application/vnd.ms-excel',
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        )
    ),
    CONSTRAINT project_assets_kind CHECK (kind IN ('document', 'photo'))
);

CREATE INDEX project_assets_workspace_project_idx
    ON project_assets (workspace_id, project_id, added_at DESC);

ALTER TABLE project_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_assets FORCE ROW LEVEL SECURITY;
CREATE POLICY project_assets_owner_policy ON project_assets
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
