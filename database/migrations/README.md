# Database migrations

Migration files are forward-only SQL scripts named
`NNNN_short_description.sql` and applied in numerical order. Do not edit a
migration after it has been applied to a shared environment; add a new
migration instead.

The Neon database stores the CRM records. User IDs are UUIDs from Supabase
Auth; they intentionally have no foreign key because Auth is a separate
service/database. Workspaces support multiple active memberships per user.

The migrations create organization workspaces, membership and role tables,
invitation records, scoped JSON records, RLS
policies, owner profile, relational CRM tables, private project-asset metadata,
delivery records, project schedules and phases, task dependencies, scoped
material and vendor master records, finance documents, line items, templates,
invoice-payment history, encrypted per-workspace communications integrations,
communication history, and idempotent WhatsApp provider events.
It also stores per-user, fixed-window API rate-limit counters with row-level
security. Expired counters are pruned on authenticated requests.
Authenticated API transactions set the transaction-local `app.user_id` used by
those policies. Do not grant end-user database credentials or bypass RLS from a
client.

Migration `0010_add_workspace_memberships_and_roles.sql` removes the unique
workspace-owner constraint, backfills existing owners into the Owner role,
and replaces owner-only record policies with membership-scoped policies.
Invitation acceptance requires a verified Supabase Auth email matching the
invitation address.

Migration `0011_add_project_planning_and_master_data.sql` adds project budgets
and start dates, project phases, phase-linked milestones, and same-project task
dependency records. Material and vendor records use the existing
membership-scoped `workspace_records` store. The API validates their structure
and rejects cross-project or cyclic task dependencies before persistence.

Migration `0012_add_procurement_workflows.sql` enables requisition, RFQ, vendor
quote, and purchase-order records in the workspace store. It also creates an
append-only, RLS-protected procurement audit log for lifecycle transitions,
approval decisions, vendor selection, and order issuance. Approval decisions
are authorized by organization or project role permissions; workflow rules and
configured approval steps are validated by the API before saving.

Migration `0013_add_inventory_and_site_execution.sql` enables inventory and
site-execution record collections and an append-only audit table for receipt,
stock, work-order, daily-report, and inspection events. Goods receipts are
validated against issued purchase orders and purchase-order line quantities;
stock movements require project scope and supported movement kinds.

Migration `0014_add_workforce_management.sql` enables employee and contractor
records, project allocations, and site attendance collections. The API requires
active worker records for allocations and validates project and attendance
scope. Payroll calculations are intentionally deferred until jurisdiction and
compliance requirements are configured.

Migration `0015_add_finance_controls.sql` defines financial-control record
coverage for project expenditure, vendor bills, and bank reconciliation. Vendor
bills are matched by the API to issued purchase orders and their goods receipts;
financial totals and reconciliation differences are represented in integer minor
currency units.

Migration `0016_add_documents_imports_reports.sql` extends the workspace
collection constraint to retain import history and dated report snapshots.
Document metadata remains organization/project scoped; reports and exports use
existing project and finance read permissions.

Migration `0017_quotation_catalog_foundation.sql` creates the normalized
catalog foundation for quotation packages, rooms, components, services,
materials, finishes, hardware, pricing rules, and proposal templates. Every
catalog table is workspace-scoped and protected by membership RLS. Package
prices and catalog versions must not be interpreted as approval snapshots;
quotation revisions will retain their own calculation snapshots in a later
milestone.

Migration `0018_quotation_revision_foundation.sql` creates workspace-scoped
quotation documents, revisions, room/service sections, BOQ lines, dimensions,
hardware selections, discounts, and calculation audit records. Revisions,
totals, and approved snapshots are append-oriented and protected by the API.

Migration `0019_workspace_line_item_catalog.sql` adds the workspace-owned,
searchable line-item catalog with Basic, Medium, and Luxury per-square-foot
rates. Starter item names are created by the quotation-catalog API on the
workspace's first catalog read; rates remain unconfigured until a workspace
manager sets them.

The WhatsApp routing function is deliberately restricted to the database role
that applies migrations. It can resolve only the workspace configured for the
requested phone-number ID; a narrowly scoped RLS policy supports that lookup.
All subsequent reads and writes run in a transaction with that owner's
`app.user_id` set. If migrations and the API use different database roles,
grant `EXECUTE` on this function only to the API's runtime role after reviewing
the deployment's role setup.

Apply migrations from the project root using `npm run db:migrate`. The runner
uses the local `.env.local` file (or `ENV_FILE` if set), obtains a PostgreSQL
transaction-scoped advisory lock, and applies each migration and its
`schema_migrations` record in one transaction. The transaction-scoped lock is
compatible with Neon pooled connections.

Before applying migrations to a database:

1. Use the development database and review the SQL.
2. Set `DATABASE_URL` only in a trusted environment. For local runs, use the
   ignored `.env.local` file and a development connection string.
3. Confirm the applied version is recorded in `schema_migrations`.
4. Verify the resulting schema before promoting the migration.

Run the same reviewed migration sequence separately against development,
staging, and production databases. Never share a database branch between those
environments.

The runner does not automatically roll back an already-applied migration. Add a
new forward migration to change the schema.
