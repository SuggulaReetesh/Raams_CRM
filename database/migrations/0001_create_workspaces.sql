CREATE TABLE workspaces (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id uuid NOT NULL,
    name text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT workspaces_name_length
        CHECK (char_length(btrim(name)) BETWEEN 1 AND 80)
);

CREATE INDEX workspaces_owner_user_id_idx
    ON workspaces (owner_user_id);
