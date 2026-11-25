ALTER TABLE workspace_records
    DROP CONSTRAINT workspace_records_collection;

ALTER TABLE workspace_records
    ADD CONSTRAINT workspace_records_collection CHECK (
        collection IN (
            'customers','activities','personas','pipelineStages','projects','phases',
            'tasks','milestones','punchItems','assets','workLogs','attendance',
            'approvals','materials','vendors','requisitions','rfqs','vendorQuotes',
            'purchaseOrders','stockBalances','goodsReceipts','stockMovements',
            'workOrders','dailyReports','siteInspections','quotations','templates',
            'proposals','invoices','communications'
        )
    );

CREATE TABLE site_execution_audit_events (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    workspace_id uuid NOT NULL REFERENCES workspaces (id) ON DELETE CASCADE,
    project_id text NOT NULL,
    collection text NOT NULL,
    record_id text NOT NULL,
    action text NOT NULL,
    actor_user_id uuid NOT NULL,
    details jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT site_execution_audit_collection CHECK (
        collection IN (
            'goodsReceipts','stockMovements','workOrders','dailyReports','siteInspections'
        )
    ),
    CONSTRAINT site_execution_audit_details_object
        CHECK (jsonb_typeof(details) = 'object')
);

CREATE INDEX site_execution_audit_workspace_project_idx
    ON site_execution_audit_events
       (workspace_id, project_id, created_at DESC, id DESC);

ALTER TABLE site_execution_audit_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE site_execution_audit_events FORCE ROW LEVEL SECURITY;

CREATE POLICY site_execution_audit_member_read
    ON site_execution_audit_events
    FOR SELECT
    USING (
        workspace_id =
            NULLIF(current_setting('app.workspace_id', true), '')::uuid
        AND EXISTS (
            SELECT 1 FROM workspace_memberships m
            WHERE m.workspace_id = site_execution_audit_events.workspace_id
              AND m.user_id =
                  NULLIF(current_setting('app.user_id', true), '')::uuid
              AND m.status = 'active'
        )
    );

CREATE POLICY site_execution_audit_member_insert
    ON site_execution_audit_events
    FOR INSERT
    WITH CHECK (
        workspace_id =
            NULLIF(current_setting('app.workspace_id', true), '')::uuid
        AND actor_user_id =
            NULLIF(current_setting('app.user_id', true), '')::uuid
        AND EXISTS (
            SELECT 1 FROM workspace_memberships m
            WHERE m.workspace_id = site_execution_audit_events.workspace_id
              AND m.user_id =
                  NULLIF(current_setting('app.user_id', true), '')::uuid
              AND m.status = 'active'
        )
    );
