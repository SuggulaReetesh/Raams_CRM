ALTER TABLE workspace_records
    DROP CONSTRAINT workspace_records_collection;

ALTER TABLE workspace_records
    ADD CONSTRAINT workspace_records_collection CHECK (
        collection IN (
            'customers',
            'activities',
            'personas',
            'pipelineStages',
            'projects',
            'phases',
            'tasks',
            'milestones',
            'punchItems',
            'assets',
            'workLogs',
            'attendance',
            'approvals',
            'materials',
            'vendors',
            'requisitions',
            'rfqs',
            'vendorQuotes',
            'purchaseOrders',
            'quotations',
            'templates',
            'proposals',
            'invoices',
            'communications'
        )
    );

CREATE TABLE procurement_audit_events (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    workspace_id uuid NOT NULL REFERENCES workspaces (id) ON DELETE CASCADE,
    project_id text NOT NULL,
    collection text NOT NULL,
    record_id text NOT NULL,
    action text NOT NULL,
    actor_user_id uuid NOT NULL,
    from_status text,
    to_status text,
    details jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT procurement_audit_collection
        CHECK (collection IN (
            'requisitions', 'rfqs', 'vendorQuotes', 'purchaseOrders'
        )),
    CONSTRAINT procurement_audit_record_id_length
        CHECK (char_length(record_id) BETWEEN 1 AND 160),
    CONSTRAINT procurement_audit_action_length
        CHECK (char_length(action) BETWEEN 1 AND 80),
    CONSTRAINT procurement_audit_details_object
        CHECK (jsonb_typeof(details) = 'object')
);

CREATE INDEX procurement_audit_workspace_project_created_idx
    ON procurement_audit_events
       (workspace_id, project_id, created_at DESC, id DESC);
CREATE INDEX procurement_audit_record_created_idx
    ON procurement_audit_events
       (workspace_id, collection, record_id, created_at DESC, id DESC);

ALTER TABLE procurement_audit_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE procurement_audit_events FORCE ROW LEVEL SECURITY;

CREATE POLICY procurement_audit_member_read
    ON procurement_audit_events
    FOR SELECT
    USING (
        workspace_id =
            NULLIF(current_setting('app.workspace_id', true), '')::uuid
        AND EXISTS (
            SELECT 1
            FROM workspace_memberships m
            WHERE m.workspace_id = procurement_audit_events.workspace_id
              AND m.user_id =
                  NULLIF(current_setting('app.user_id', true), '')::uuid
              AND m.status = 'active'
        )
    );

CREATE POLICY procurement_audit_member_insert
    ON procurement_audit_events
    FOR INSERT
    WITH CHECK (
        workspace_id =
            NULLIF(current_setting('app.workspace_id', true), '')::uuid
        AND actor_user_id =
            NULLIF(current_setting('app.user_id', true), '')::uuid
        AND EXISTS (
            SELECT 1
            FROM workspace_memberships m
            WHERE m.workspace_id = procurement_audit_events.workspace_id
              AND m.user_id =
                  NULLIF(current_setting('app.user_id', true), '')::uuid
              AND m.status = 'active'
        )
    );
