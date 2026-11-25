ALTER TABLE workspace_records
    DROP CONSTRAINT workspace_records_collection;

ALTER TABLE workspace_records
    ADD CONSTRAINT workspace_records_collection CHECK (
        collection IN (
            'customers','activities','personas','pipelineStages','projects','phases',
            'tasks','milestones','punchItems','assets','workLogs','attendance',
            'approvals','materials','vendors','requisitions','rfqs','vendorQuotes',
            'purchaseOrders','stockBalances','goodsReceipts','stockMovements',
            'workOrders','dailyReports','siteInspections','workers',
            'workforceAllocations','siteAttendance','quotations','templates',
            'proposals','invoices','communications'
        )
    );

CREATE TABLE workforce_audit_events (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    workspace_id uuid NOT NULL REFERENCES workspaces (id) ON DELETE CASCADE,
    project_id text,
    worker_id text,
    action text NOT NULL,
    actor_user_id uuid NOT NULL,
    details jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT workforce_audit_details_object
        CHECK (jsonb_typeof(details) = 'object')
);

CREATE INDEX workforce_audit_workspace_project_idx
    ON workforce_audit_events
       (workspace_id, project_id, created_at DESC, id DESC);

ALTER TABLE workforce_audit_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE workforce_audit_events FORCE ROW LEVEL SECURITY;

CREATE POLICY workforce_audit_member_read
    ON workforce_audit_events
    FOR SELECT
    USING (
        workspace_id =
            NULLIF(current_setting('app.workspace_id', true), '')::uuid
        AND EXISTS (
            SELECT 1 FROM workspace_memberships m
            WHERE m.workspace_id = workforce_audit_events.workspace_id
              AND m.user_id =
                  NULLIF(current_setting('app.user_id', true), '')::uuid
              AND m.status = 'active'
        )
    );

CREATE POLICY workforce_audit_member_insert
    ON workforce_audit_events
    FOR INSERT
    WITH CHECK (
        workspace_id =
            NULLIF(current_setting('app.workspace_id', true), '')::uuid
        AND actor_user_id =
            NULLIF(current_setting('app.user_id', true), '')::uuid
    );
