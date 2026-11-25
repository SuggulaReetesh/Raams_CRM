ALTER TABLE workspaces
    DROP CONSTRAINT workspaces_owner_user_id_unique;

CREATE TABLE workspace_roles (
    workspace_id uuid NOT NULL REFERENCES workspaces (id) ON DELETE CASCADE,
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    scope text NOT NULL,
    project_id text,
    name text NOT NULL,
    permission_keys text[] NOT NULL DEFAULT ARRAY[]::text[],
    is_system boolean NOT NULL DEFAULT false,
    created_by uuid NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (workspace_id, id),
    CONSTRAINT workspace_roles_scope
        CHECK (
            (scope = 'organization' AND project_id IS NULL) OR
            (scope = 'project' AND project_id IS NOT NULL)
        ),
    CONSTRAINT workspace_roles_project_fk
        FOREIGN KEY (workspace_id, project_id)
        REFERENCES studio_projects (workspace_id, id)
        ON DELETE CASCADE,
    CONSTRAINT workspace_roles_name_length
        CHECK (char_length(btrim(name)) BETWEEN 1 AND 80)
);

CREATE UNIQUE INDEX workspace_roles_organization_name_unique_idx
    ON workspace_roles (workspace_id, lower(name))
    WHERE scope = 'organization';
CREATE UNIQUE INDEX workspace_roles_project_name_unique_idx
    ON workspace_roles (workspace_id, project_id, lower(name))
    WHERE scope = 'project';

CREATE TABLE workspace_memberships (
    workspace_id uuid NOT NULL REFERENCES workspaces (id) ON DELETE CASCADE,
    user_id uuid NOT NULL,
    role_id uuid NOT NULL,
    status text NOT NULL DEFAULT 'active',
    display_name text NOT NULL DEFAULT '',
    email text,
    joined_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (workspace_id, user_id),
    CONSTRAINT workspace_memberships_status
        CHECK (status IN ('active', 'suspended')),
    CONSTRAINT workspace_memberships_display_name_length
        CHECK (char_length(display_name) <= 120),
    CONSTRAINT workspace_memberships_email_length
        CHECK (email IS NULL OR char_length(email) <= 320),
    CONSTRAINT workspace_memberships_role_fk
        FOREIGN KEY (workspace_id, role_id)
        REFERENCES workspace_roles (workspace_id, id)
);

CREATE TABLE workspace_project_memberships (
    workspace_id uuid NOT NULL,
    project_id text NOT NULL,
    user_id uuid NOT NULL,
    role_id uuid NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (workspace_id, project_id, user_id),
    CONSTRAINT workspace_project_memberships_project_fk
        FOREIGN KEY (workspace_id, project_id)
        REFERENCES studio_projects (workspace_id, id) ON DELETE CASCADE,
    CONSTRAINT workspace_project_memberships_member_fk
        FOREIGN KEY (workspace_id, user_id)
        REFERENCES workspace_memberships (workspace_id, user_id)
        ON DELETE CASCADE,
    CONSTRAINT workspace_project_memberships_role_fk
        FOREIGN KEY (workspace_id, role_id)
        REFERENCES workspace_roles (workspace_id, id)
);

CREATE TABLE workspace_invitations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id uuid NOT NULL REFERENCES workspaces (id) ON DELETE CASCADE,
    email text NOT NULL,
    role_id uuid NOT NULL,
    invited_by uuid NOT NULL,
    status text NOT NULL DEFAULT 'pending',
    expires_at timestamptz NOT NULL DEFAULT now() + interval '7 days',
    accepted_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT workspace_invitations_email_length
        CHECK (char_length(email) BETWEEN 3 AND 320),
    CONSTRAINT workspace_invitations_status
        CHECK (status IN ('pending', 'accepted', 'revoked', 'expired')),
    CONSTRAINT workspace_invitations_role_fk
        FOREIGN KEY (workspace_id, role_id)
        REFERENCES workspace_roles (workspace_id, id)
);

CREATE UNIQUE INDEX workspace_invitations_pending_email_unique_idx
    ON workspace_invitations (workspace_id, lower(email))
    WHERE status = 'pending';
CREATE INDEX workspace_memberships_user_idx
    ON workspace_memberships (user_id, status, workspace_id);
CREATE INDEX workspace_project_memberships_user_idx
    ON workspace_project_memberships (workspace_id, user_id);

WITH owner_roles AS (
    INSERT INTO workspace_roles
        (workspace_id, scope, name, permission_keys, is_system, created_by)
    SELECT id, 'organization', 'Owner', ARRAY['*']::text[], true,
           owner_user_id
    FROM workspaces
    RETURNING workspace_id, id
)
INSERT INTO workspace_memberships
    (workspace_id, user_id, role_id, status, display_name, email)
SELECT r.workspace_id, w.owner_user_id, r.id, 'active',
       COALESCE(p.display_name, 'Workspace owner'), p.email
FROM owner_roles r
JOIN workspaces w ON w.id = r.workspace_id
LEFT JOIN workspace_owner_profiles p ON p.workspace_id = w.id
ON CONFLICT (workspace_id, user_id) DO NOTHING;

ALTER TABLE workspaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE workspaces FORCE ROW LEVEL SECURITY;
DROP POLICY workspaces_owner_policy ON workspaces;
CREATE POLICY workspaces_member_policy ON workspaces
    USING (
        id = NULLIF(current_setting('app.workspace_id', true), '')::uuid
        AND EXISTS (
            SELECT 1
            FROM workspace_memberships m
            WHERE m.workspace_id = workspaces.id
              AND m.user_id =
                  NULLIF(current_setting('app.user_id', true), '')::uuid
              AND m.status = 'active'
        )
    )
    WITH CHECK (
        id = NULLIF(current_setting('app.workspace_id', true), '')::uuid
        AND EXISTS (
            SELECT 1
            FROM workspace_memberships m
            WHERE m.workspace_id = workspaces.id
              AND m.user_id =
                  NULLIF(current_setting('app.user_id', true), '')::uuid
              AND m.status = 'active'
        )
    );
CREATE POLICY workspaces_owner_bootstrap_policy ON workspaces
    FOR INSERT
    WITH CHECK (
        id = NULLIF(current_setting('app.workspace_id', true), '')::uuid
        AND owner_user_id =
            NULLIF(current_setting('app.user_id', true), '')::uuid
    );
CREATE POLICY workspaces_invited_user_policy ON workspaces
    FOR SELECT
    USING (
        id = NULLIF(current_setting('app.workspace_id', true), '')::uuid
        AND EXISTS (
            SELECT 1
            FROM workspace_invitations i
            WHERE i.workspace_id = workspaces.id
              AND i.status = 'pending'
              AND i.expires_at > now()
              AND lower(i.email) =
                  lower(NULLIF(current_setting('app.user_email', true), ''))
        )
    );

ALTER TABLE workspace_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE workspace_memberships FORCE ROW LEVEL SECURITY;
CREATE POLICY workspace_memberships_member_policy
    ON workspace_memberships
    USING (
        user_id = NULLIF(current_setting('app.user_id', true), '')::uuid
        OR workspace_id =
            NULLIF(current_setting('app.workspace_id', true), '')::uuid
    )
    WITH CHECK (
        workspace_id =
            NULLIF(current_setting('app.workspace_id', true), '')::uuid
    );

ALTER TABLE workspace_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE workspace_roles FORCE ROW LEVEL SECURITY;
CREATE POLICY workspace_roles_member_policy ON workspace_roles
    USING (
        workspace_id =
            NULLIF(current_setting('app.workspace_id', true), '')::uuid
    )
    WITH CHECK (
        workspace_id =
            NULLIF(current_setting('app.workspace_id', true), '')::uuid
    );

ALTER TABLE workspace_project_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE workspace_project_memberships FORCE ROW LEVEL SECURITY;
CREATE POLICY workspace_project_memberships_member_policy
    ON workspace_project_memberships
    USING (
        workspace_id =
            NULLIF(current_setting('app.workspace_id', true), '')::uuid
    )
    WITH CHECK (
        workspace_id =
            NULLIF(current_setting('app.workspace_id', true), '')::uuid
    );

ALTER TABLE workspace_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE workspace_invitations FORCE ROW LEVEL SECURITY;
CREATE POLICY workspace_invitations_member_policy ON workspace_invitations
    USING (
        workspace_id =
            NULLIF(current_setting('app.workspace_id', true), '')::uuid
    )
    WITH CHECK (
        workspace_id =
            NULLIF(current_setting('app.workspace_id', true), '')::uuid
    );
CREATE POLICY workspace_invitations_accept_policy
    ON workspace_invitations
    FOR SELECT
    USING (
        status = 'pending'
        AND expires_at > now()
        AND lower(email) =
            lower(NULLIF(current_setting('app.user_email', true), ''))
    );

ALTER TABLE workspace_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE workspace_settings FORCE ROW LEVEL SECURITY;
DROP POLICY workspace_settings_owner_policy ON workspace_settings;
CREATE POLICY workspace_settings_member_policy ON workspace_settings
    USING (
        workspace_id =
            NULLIF(current_setting('app.workspace_id', true), '')::uuid
    )
    WITH CHECK (
        workspace_id =
            NULLIF(current_setting('app.workspace_id', true), '')::uuid
    );

ALTER TABLE workspace_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE workspace_records FORCE ROW LEVEL SECURITY;
DROP POLICY workspace_records_owner_policy ON workspace_records;
CREATE POLICY workspace_records_member_policy ON workspace_records
    USING (
        workspace_id =
            NULLIF(current_setting('app.workspace_id', true), '')::uuid
    )
    WITH CHECK (
        workspace_id =
            NULLIF(current_setting('app.workspace_id', true), '')::uuid
    );

ALTER TABLE workspace_owner_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE workspace_owner_profiles FORCE ROW LEVEL SECURITY;
DROP POLICY workspace_owner_profiles_owner_policy
    ON workspace_owner_profiles;
CREATE POLICY workspace_owner_profiles_member_policy
    ON workspace_owner_profiles
    USING (
        workspace_id =
            NULLIF(current_setting('app.workspace_id', true), '')::uuid
    )
    WITH CHECK (
        workspace_id =
            NULLIF(current_setting('app.workspace_id', true), '')::uuid
    );

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
        'workspace_preferences',
        'project_assets',
        'project_tasks',
        'project_milestones',
        'project_punch_items',
        'project_work_logs',
        'project_attendance',
        'project_approval_requests',
        'finance_documents',
        'finance_line_items',
        'finance_document_templates',
        'invoice_payments',
        'communication_messages',
        'communication_provider_events'
    ]
    LOOP
        EXECUTE format('DROP POLICY %I ON %I',
            table_name || '_owner_policy', table_name);
        EXECUTE format(
            'CREATE POLICY %I ON %I USING (
                workspace_id =
                    NULLIF(current_setting(''app.workspace_id'', true), '''')::uuid
            ) WITH CHECK (
                workspace_id =
                    NULLIF(current_setting(''app.workspace_id'', true), '''')::uuid
            )',
            table_name || '_member_policy',
            table_name
        );
    END LOOP;
END
$$;

ALTER TABLE workspace_integrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE workspace_integrations FORCE ROW LEVEL SECURITY;
DROP POLICY workspace_integrations_owner_policy ON workspace_integrations;
CREATE POLICY workspace_integrations_member_policy
    ON workspace_integrations
    USING (
        workspace_id =
            NULLIF(current_setting('app.workspace_id', true), '')::uuid
    )
    WITH CHECK (
        workspace_id =
            NULLIF(current_setting('app.workspace_id', true), '')::uuid
    );

DROP POLICY workspace_integrations_webhook_route ON workspace_integrations;
CREATE POLICY workspace_integrations_webhook_route
    ON workspace_integrations
    FOR SELECT
    USING (
        provider = 'whatsapp'
        AND account_id =
            NULLIF(current_setting('app.whatsapp_account_id', true), '')
    );
