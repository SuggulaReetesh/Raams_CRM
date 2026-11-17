ALTER TABLE workspaces
    ADD CONSTRAINT workspaces_id_owner_user_id_unique
    UNIQUE (id, owner_user_id);

CREATE TABLE workspace_owner_profiles (
    workspace_id uuid PRIMARY KEY,
    owner_user_id uuid NOT NULL UNIQUE,
    display_name text NOT NULL DEFAULT 'Studio owner',
    email text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT workspace_owner_profiles_name_length
        CHECK (char_length(btrim(display_name)) BETWEEN 1 AND 120),
    CONSTRAINT workspace_owner_profiles_email_length
        CHECK (email IS NULL OR char_length(email) <= 320),
    CONSTRAINT workspace_owner_profiles_workspace_owner_fk
        FOREIGN KEY (workspace_id, owner_user_id)
        REFERENCES workspaces (id, owner_user_id)
        ON DELETE CASCADE
);

ALTER TABLE workspace_owner_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE workspace_owner_profiles FORCE ROW LEVEL SECURITY;
CREATE POLICY workspace_owner_profiles_owner_policy
    ON workspace_owner_profiles
    USING (
        owner_user_id =
            NULLIF(current_setting('app.user_id', true), '')::uuid
    )
    WITH CHECK (
        owner_user_id =
            NULLIF(current_setting('app.user_id', true), '')::uuid
    );
