# Construction ERP Implementation Milestones

## Purpose and current baseline

This roadmap expands the existing single-owner studio CRM into the construction
operations and finance product represented by the supplied module reference.
It groups related functionality into milestones and a compact navigation
structure instead of placing every module in the sidebar.

This is a forward-looking scope document, not a claim that the listed features
are already implemented. Existing project, task, client invoicing, and related
capabilities should be reused where appropriate, then extended to meet the
construction workflows below.

**Current implementation baseline**

- **Available in the app:** basic projects, project tasks, client quotations,
  proposals, invoices, and manually recorded client payments.
- **Partial building blocks:** studio settings, UI persona/role previews,
  project approvals, milestones, punch lists, project files, CSV client import,
  and studio attendance/work logs. These are not substitutes for company-wide
  access control, procurement, inventory, HR, or accounting.
- **Not yet verified in production:** provider provisioning, live database
  migrations, and end-to-end integrations. Development currently uses local
  storage; configured non-development environments use the remote API.

The existing production-readiness checklist remains in [MILESTONES.md](./MILESTONES.md).

## Proposed sidebar

Keep the top-level navigation to these eight areas. Put related workflows on
the selected area’s page as tabs, filters, or contextual project panels.

1. **Dashboard** — organization-wide status and pending actions.
2. **Projects** — project overview, phases and schedule, tasks, daily progress,
   issues, work orders, and inspections.
3. **Procurement** — vendor directory, material requests, RFQs, purchase orders,
   and procurement approvals.
4. **Inventory** — material catalogue, stock by warehouse/site, goods receipts,
   transfers, and consumption.
5. **Workforce** — employee and labour records, attendance, and workforce
   administration.
6. **Finance** — project expenditure, client billing, vendor bills and
   payables, accounting controls, and financial reports.
7. **Documents & Reports** — project and company documents, imports, exports,
   and operational reports.
8. **Organization & Access** — company profile, users, roles, permissions, and
   workspace settings.

The sidebar should show only navigation destinations the signed-in user is
authorized to access. Record-level permissions and API authorization must be
enforced on the server, not only hidden in the UI.

## Milestones

### Milestone 1 — Organization, users, and access control

**Priority:** Foundation  
**Status:** Implemented. Organization selection, membership
schema, role and invitation APIs, and server permission checks are implemented;
project-scoped reads now limit records to assigned projects and mask client
contact, budget, requirement, and note fields for project-only access. Live
live database/provider verification remains a deployment task.  
**Depends on:** Existing authentication and workspace foundation.

- Establish the organization/company profile and organization-level settings.
- Replace UI-only persona previews with real user membership and invitations.
- Define organization, project, and approval roles with server-enforced
  permissions.
- Add user lifecycle handling: invite, accept, deactivate, and remove access.
- Migrate from the current one-owner-per-workspace assumption without exposing
  data across organizations.

**Acceptance criteria**

- Multiple authorized users can access the same organization.
- Every protected API operation checks the signed-in user’s organization and
  permissions.
- A user cannot access another organization’s data by changing an identifier
  or calling an API directly.
- UI role previews are not treated as authorization.

### Milestone 2 — Master data and project planning

**Priority:** Core construction workflows  
**Status:** Implemented. Organization-scoped material
and vendor records, project budget/site dates, phases, milestone links, task
dependencies, and a schedule timeline are implemented. The vendor document
register stores metadata and references; file attachments, live migration
live migration verification remains a deployment task. Gantt visualization and
membership-ID assignee storage remain follow-on enhancements.
**Depends on:** Milestone 1.

- Add a standardized material catalogue with units, categories, and
  specifications.
- Add vendor/contractor profiles and their contact and document records.
- Extend projects with budgets, sites, schedules, and accountable project
  members using the existing project-role membership assignments.
- Add project phases and milestone relationships.
- Extend tasks for project assignments and planning dependencies.
- Add a schedule/timeline view; support Gantt-style visualization after
  schedule data and dependency rules are defined.

**Acceptance criteria**

- Projects, phases, tasks, materials, and vendors have validated,
  organization-scoped records.
- Project plans can be viewed and updated without losing existing CRM project
  and task data.
- Schedule dates and dependencies are validated consistently by the API.

### Milestone 3 — Procurement and approvals

**Priority:** Purchasing workflows  
**Status:** Implemented in the application and backend. Project requisitions,
RFQs, submitted and selected vendor quotes, purchase orders, approval policy
configuration, scoped decisions, vendor communication links, and audit-history
loading are implemented. Migration 0012 and live-provider verification remain
configuration/deployment tasks.  
**Depends on:** Milestones 1 and 2.

- Create and track project material requisitions.
- Request and record vendor quotations; compare submitted offers.
- Create purchase orders from approved requests and selected vendor quotes.
- Route requests and purchase orders through configurable approval steps.
- Keep vendor communications and procurement decisions attached to their
  relevant records.

**Acceptance criteria**

- Requisition, RFQ, quotation, approval, and purchase-order states follow
  explicit transition rules.
- Approvers can act only within their assigned scope.
- Approved order values and vendor selections are auditable.

### Milestone 4 — Inventory and site execution

**Priority:** Site operations  
**Status:** Implemented in application and backend with goods receipts,
stock balances and movements, work orders, daily reports, and quality/safety
inspections. Migration 0013 and live database verification remain deployment
tasks.  
**Depends on:** Milestones 2 and 3.

- Record goods received against purchase orders and resolve quantity or
  quality discrepancies.
- Track stock balances by material, warehouse, and project site.
- Record stock transfers and material consumption with an audit trail.
- Create and track contractor/labour work orders.
- Add daily project progress reports.
- Expand the punch list into issue tracking and add quality/safety inspections.

**Acceptance criteria**

- Inventory updates are traceable to receipts, transfers, and consumption.
- A goods receipt cannot silently exceed or mismatch its purchase order.
- Daily reports, issues, inspections, and work orders are project-scoped and
  searchable.
- Stock changes preserve a complete audit history.

### Milestone 5 — Workforce and attendance

**Priority:** Workforce administration  
**Status:** Implemented in the application and backend with employee/contractor
records, project allocations, and site attendance linked to real worker IDs.
Migration 0014 and live database verification remain deployment tasks.
**Depends on:** Milestone 1; integrates with project/site records from
Milestones 2 and 4.

- Add employee and labour/contractor records.
- Record site and organization attendance against real people and work dates.
- Support workforce allocation or transfers between project sites.
- Define HR and payroll requirements before implementing salary calculations,
  statutory deductions, or payroll exports.

**Acceptance criteria**

- Attendance links to actual employee/labour records, not UI persona previews.
- Changes are auditable and restricted to authorized users.
- Payroll functionality is not enabled until jurisdiction, tax, and compliance
  requirements are confirmed.

### Milestone 6 — Finance and accounting controls

**Priority:** Financial operations  
**Status:** Implemented for project expenditure, vendor bill matching to issued
purchase orders and goods receipts, and bank reconciliation snapshots. Existing
client quotations, proposals, invoices, and payments remain available.
**Depends on:** Milestones 1–4; vendor billing also depends on Milestone 3.

- Track project expenditure and compare actual amounts with project budgets.
- Add vendor bills and payable balances.
- Retain client invoices and incoming-payment tracking, extending them only
  where required by the agreed billing workflow.
- Match vendor bills to purchase orders and goods receipts before payment.
- Add finance reports and auditable bank/cash reconciliation and contra-entry
  workflows if required.
- Confirm accounting periods, currency, tax rules, numbering, and approval
  requirements before finalizing the ledger design.

**Acceptance criteria**

- Financial totals are calculated and validated by trusted server-side code.
- Payables, client receivables, and project expenditure remain distinct,
  traceable records.
- Matching, reconciliation, and ledger changes are auditable and protected
  against duplicate or concurrent updates.
- No payment-provider integration is assumed without a separate product
  decision.

### Milestone 7 — Documents, imports, and reporting

**Priority:** Cross-workflow information access  
**Status:** Implemented around existing project documents and CSV import:
validated import history, dated report snapshots, and authorized operational
CSV reporting are now retained and displayed.
**Depends on:** Milestones 2–6.

- Organize project and company documents with metadata and access policies.
- Expand imports beyond client CSVs, with validation, preview, duplicate
  handling, and an import history.
- Provide operational reports for project progress, procurement, inventory,
  workforce, and finance.
- Support exports with organization-level access checks and consistent data
  snapshots.

**Acceptance criteria**

- Imports do not partially apply invalid batches without explaining failures.
- Reports and exports use authorized, consistent data and identify their
  reporting period.
- Documents remain private and follow organization/project access rules.

### Milestone 8 — Integration, verification, and rollout

**Priority:** Production release  
**Status:** Implementation complete across Milestones 1–7. Backend syntax,
migrations, and 46 full-suite tests pass. Cross-platform native build/signing,
live migration application, staging verification, monitoring, backup restore,
and deployment rollback remain environment/release tasks.  
**Depends on:** Milestones 1–7.

- Connect all new UI workflows to their authenticated APIs and database
  migrations.
- Add automated tests for permissions, workflow transitions, stock integrity,
  financial calculations, and imports.
- Apply and verify migrations against development and staging databases before
  production.
- Run web, Android, and iOS workflow testing, including accessibility and
  responsive layouts.
- Configure monitoring, backups, restore validation, deployment rollback, and
  support procedures.

**Acceptance criteria**

- Each delivered module persists and reloads through the configured backend;
  no production workflow silently falls back to local-only data.
- Critical cross-organization authorization tests pass.
- Release builds use production identifiers and signing.
- Backup restore and rollback procedures are exercised before launch.

## Decisions required before detailed design

- Whether the product should support multiple organizations per account or one
  organization per user.
- Which approval stages and delegation rules are required.
- Whether warehouses and project sites have separate stock ownership.
- Supported units, currencies, tax jurisdictions, and accounting conventions.
- Employee/labour payroll scope and applicable legal requirements.
- Whether payments are recorded manually or integrated with a payment/banking
  provider.
- Required document retention, audit history, and data-export policies.

These choices affect schema and authorization design; confirm them before
building the corresponding milestone rather than assuming defaults.
