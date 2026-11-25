CREATE TABLE quotation_line_item_catalog (
    workspace_id uuid NOT NULL REFERENCES workspaces (id) ON DELETE CASCADE,
    id text NOT NULL,
    name text NOT NULL,
    basic_rate_per_sqft numeric(14, 2),
    medium_rate_per_sqft numeric(14, 2),
    luxury_rate_per_sqft numeric(14, 2),
    active boolean NOT NULL DEFAULT true,
    version integer NOT NULL DEFAULT 1 CHECK (version > 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (workspace_id, id),
    CONSTRAINT quotation_line_item_catalog_name_length
        CHECK (char_length(btrim(name)) BETWEEN 1 AND 120),
    CONSTRAINT quotation_line_item_catalog_basic_rate
        CHECK (basic_rate_per_sqft IS NULL OR basic_rate_per_sqft >= 0),
    CONSTRAINT quotation_line_item_catalog_medium_rate
        CHECK (medium_rate_per_sqft IS NULL OR medium_rate_per_sqft >= 0),
    CONSTRAINT quotation_line_item_catalog_luxury_rate
        CHECK (luxury_rate_per_sqft IS NULL OR luxury_rate_per_sqft >= 0)
);

CREATE UNIQUE INDEX quotation_line_item_catalog_name_unique
    ON quotation_line_item_catalog (workspace_id, lower(btrim(name)));
CREATE INDEX quotation_line_item_catalog_active_name_idx
    ON quotation_line_item_catalog (workspace_id, active, lower(name));

ALTER TABLE quotation_line_item_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE quotation_line_item_catalog FORCE ROW LEVEL SECURITY;

CREATE POLICY quotation_line_item_catalog_member_policy
    ON quotation_line_item_catalog
    USING (
        workspace_id IN (
            SELECT wm.workspace_id
            FROM workspace_memberships wm
            WHERE wm.user_id =
                NULLIF(current_setting('app.user_id', true), '')::uuid
              AND wm.status = 'active'
        )
    )
    WITH CHECK (
        workspace_id IN (
            SELECT wm.workspace_id
            FROM workspace_memberships wm
            WHERE wm.user_id =
                NULLIF(current_setting('app.user_id', true), '')::uuid
              AND wm.status = 'active'
        )
    );
