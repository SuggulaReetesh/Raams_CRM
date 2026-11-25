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
            'workforceAllocations','siteAttendance','projectExpenditures',
            'vendorBills','bankReconciliations','importRecords','reportSnapshots',
            'quotations','templates','proposals','invoices','communications'
        )
    );
