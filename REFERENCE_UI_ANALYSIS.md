# Reference UI and Functionality Analysis

## Purpose and scope

This document analyzes the 43 screenshots supplied as UI references. The
screens show a desktop-first construction/interior-design CRM and project
operations product. The goal is to extract reusable layout patterns and
functional requirements for Raams CRM, not to reproduce the reference
product's branding, assets, or exact screen designs.

The screenshots show real page states, dialogs, tables, dashboards, and some
loading/empty states. They do not reveal every interaction, validation rule,
permission, or underlying data relationship. Items described as "inferred"
below should be confirmed before implementation.

## Executive summary

The strongest recurring design pattern is a dense business workspace:

- A persistent, searchable left navigation with grouped modules.
- A compact top bar for workspace identity, global actions, notifications,
  support, and user profile.
- A large content region with page title, tabs, summary metrics, filters,
  search, and data tables or cards.
- Project-context pages with a second navigation row for project modules.
- Modal forms for create/edit tasks, with required fields grouped into sections.
- Color-coded statuses, progress indicators, date ranges, and performance
  summaries.

The screenshots cover sales/lead management, follow-ups, projects, quotations,
documents, project finance, site progress, labor, procurement, inventory,
warranty, vendors, inspirations, administration, attendance, and reports.

For Raams CRM, implement these as consistent Flutter web patterns and adapt
them to the app's existing data model, authorization, and responsive behavior.
Avoid copying the source product's logo, exact branding, or screenshot assets.

## Shared design system observations

### Application shell

- **Left navigation:** Search at the top; icon-and-label entries; expandable
  groups such as Sales, Execution, Accounting, Operations, Designers, HR, and
  Admin; selected module highlighted; a collapse control for narrower layouts.
- **Workspace header:** Organization/workspace name and switcher at upper left.
  Global actions, notification count, support/help, and user profile appear at
  upper right.
- **Content header:** Clear page title and contextual actions, usually with
  primary create action aligned to the right.
- **Project context:** Project pages show client/project identity and a
  horizontally scrollable row of project modules.
- **Page body:** Tables and cards use the available width; long tables can
  scroll horizontally rather than forcing each column to become unreadable.

### Visual language

- Light background, white content surfaces, neutral gray table headers, thin
  separators, modest rounded corners, and restrained shadows.
- A warm coral/red accent for selected navigation, primary actions, and active
  tabs. Pale red/pink is used for selected rows and some summary panels.
- Status colors communicate meaning (for example, green for complete/healthy,
  amber for pending/attention, red for overdue/failed, and blue for neutral
  information).
- Small typography and compact spacing support high information density.
  Raams should preserve readable text sizing and adequate touch targets,
  especially on mobile.
- Avatars/initials, icon buttons, badges, chips, and progress bars help make
  dense pages scannable.

These are approximate visual characteristics, not exact pixel or color
specifications.

### Reusable interaction patterns

1. **List page:** Title and summary counts; filter controls; search; optional
   column/filter controls; table with row actions; pagination and page-size
   selector.
2. **Dashboard:** Date range controls; KPI cards; chart/table sections; refresh
   or last-updated indicator.
3. **Create/edit workflow:** Grouped controls; visible required markers;
   contextual selectors; date/time pickers; notes; optional attachment; cancel
   and primary save/create action. For Raams, present substantial workflows on
   a dedicated page or inline in the current page rather than in a modal.
4. **Status change:** Clickable colored status chip or dropdown. Status options
   appear to be configurable in settings, including a color, closed-state flag,
   and optional automation association.
5. **Project workspace:** Client/project header, module tabs, summary, latest
   updates, and links into focused functional areas.
6. **Analytics toggle:** Some chart panels can switch between chart and table.
7. **Approval action:** Pending records have direct approve/deny or request
   approval actions; detailed record review is available separately.

### Non-modal UX requirement

Keep the features shown in popup dialogs, but do not implement those workflows
as modal popups or overlay drawers. Prefer normal page navigation or inline
content that does not obscure the current page:

- **Multi-step or large workflows** (such as quotation creation/editing):
  open a dedicated editor page with a clear back link, project/lead context,
  save state, preview, and approval actions.
- **Structured forms** (such as follow-ups, expenses, and funds): open a
  dedicated create/edit page, or expand an inline form within the relevant
  module. Preserve all fields, validation, attachments, and save/cancel
  behavior.
- **Record details and conversations** (such as warranty requests): navigate
  to a detail page or expand the record inline; keep status changes and the
  comment composer available without an overlay.
- **Small feedback and validation:** use inline field errors, page-level
  success/error messages, and unsaved-changes prompts that follow the app's
  navigation pattern instead of modal dialogs.

The screenshots show large workflows as dialogs; the non-modal presentation is
the requested Raams behavior. Standard control menus (for example, a select
option list or date picker) are separate from these workflows and can retain
their normal control behavior unless a no-overlay rule is requested for those
too.

### Behavior to include across modules

- Search, filtering, sorting, pagination, and refresh where lists or metrics
  are shown.
- Loading, empty, error, and permission-denied states; a skeleton is visible in
  the Orders screenshot, but should not remain as the only feedback.
- Clear success and validation feedback on forms.
- Accessible labels and keyboard operation for tables, dialogs, menus, and
  status controls.
- Responsive layouts: preserve the desktop table experience while providing
  sensible tablet/mobile alternatives (collapsed navigation, stacked cards,
  and selective columns).
- Permission checks must be enforced by the backend, not only hidden in the UI.

## Functional analysis by area

### 1. Sales leads

**Visible capabilities**

- Lead list with total count and aggregate value.
- Status filter with many workflow stages, including created, assigned,
  requirements gathered, visit planned, follow-up, on hold, won/lost, and other
  configured outcomes.
- Additional filters, search, sort, filter/column controls, and pagination.
- Rows show lead/client, phone, follow-up, assignees, latest remark, project,
  budget, and scope.
- Quick status change from the list; quick follow-up creation.
- New lead action and a lead-form shortcut.
- Status configuration screen includes reorder handles, color selection,
  closed-state toggle, automation link, and edit action.

**Potential Raams behavior**

- Treat lead status values as workspace-configurable rather than hardcoding the
  screenshot's full list.
- Keep status history and latest remarks auditable.
- Support filtering by status and other lead attributes; allow column
  visibility where practical.
- Confirm which displayed columns already exist in Raams and which require new
  fields before changing the schema.

### 2. Follow-ups, calls, and meetings

**Visible capabilities**

- Follow-up dashboard with date ranges (Today, This Week, This Month, Custom).
- KPI cards for total, completed, upcoming, missed, and rescheduled follow-ups.
- Meeting summary and call summary metrics, including duration/talk time,
  dialed, connected, and not received.
- Performance area with individual ranking/score and completion/connect rates.
- Team page with team-wide follow-up, call, and meeting totals plus per-user
  performance cards.
- Team call log table with direction, lead, status, agent, customer number,
  provider, duration, and created time.
- Follow-up create workflow supports callback or meeting, lead, assignee, title,
  date/time, priority, reminder, notes, attachments, and create/cancel.

**Potential Raams behavior**

- Separate scheduled follow-ups from completed call/meeting outcomes.
- Provide overdue/upcoming indicators and date-range reporting.
- Validate that the selected lead and assignee exist.
- Team metrics, call recording/provider integrations, and individual ranking
  depend on team accounts and telephony data not established by these images.

### 3. Project overview and insights

**Visible capabilities**

- Project insights dashboard: active project count/value, on-track/running-late
  counts, ranked project status list, project-stage distribution, and a
  project timeline with date-range controls.
- Project summary shows client, project owner, start/handover dates, actual vs
  estimated progress, financial summary, unread communication count, site
  progress previews, design documents, latest updates, milestones, tasks, and
  procurement summaries.
- Project modules are available through a horizontal tab row and a module
  grid, including Details, Documents, Project Plan, Finance Plan, Payments,
  Site, Labour, Procurement, MB Sheet, Warranty, Quotations, Inspirations,
  Virtual Tour, and Communication.
- Module cards and summary panels act as shortcuts to focused pages.

**Potential Raams behavior**

- Use the existing client/project relationship as the source of truth for
  module context.
- Keep high-level project status separate from detailed task/milestone
  completion.
- Surface recent activity and outstanding items without duplicating finance or
  delivery records.
- Ensure project module navigation remains usable on small screens.

### 4. Project planning and milestones

**Visible capabilities**

- Milestone overview with total, in-progress, completed, and not-started
  counts.
- Planned/actual project dates and estimated/actual progress.
- Groups or teams with milestone counts and completion percentages.
- Expandable milestone rows showing timeline, assignee, client visibility,
  latest update, dependencies, and row actions.
- Tabs for milestones, Gantt chart, and tasks; add-scope action; refresh,
  column, chart, filter, search, and menu controls.

**Potential Raams behavior**

- Support milestone state, planned and actual dates, dependencies, assignee,
  and client-visible flag.
- Prevent invalid dependency cycles and clearly identify overdue work.
- Retain both list and timeline views; keep progress calculations consistent.
- Confirm whether group/team assignment is in scope given Raams' current
  workspace-user model.

### 5. Quotations and proposal documents

**Visible capabilities**

- Quotation list with tabs for My Quotations, All Quotations, Approvals, and
  Summary; filters, search, refresh, and create actions.
- Create page selects quotation name/template, type, and source (project or
  lead), then the corresponding source record.
- Quotation editor has Items and Preview views, template selector, save,
  request-approval, new-version, share/link, and download actions.
- Line-item document includes description, image, quantity, unit rate/UOM,
  price, discount, and final price, with category/area groupings.
- Preview includes a summary by area, initial total, discount, service charges,
  subtotal, GST, final total, payment plan, bank details, terms and conditions,
  and closing text.

**Potential Raams behavior**

- Preserve the existing quotation calculation and version/approval model.
- Clearly distinguish editable line items from generated preview output.
- Recalculate totals using trusted server-side logic and show currency/tax
  breakdowns.
- Support image/document attachments without embedding large media directly in
  database records.
- Approval, client sharing, and bank-detail exposure need explicit
  authorization and review.

### 6. Project documents

**Visible capabilities**

- Project-specific document page with folders and files, storage usage,
  search, filter, add action, and per-row actions.
- File rows show name, version, internal status, client approval status,
  description, upload identity/time, and comments.
- Folder menus and version links suggest file organization and version history.

**Potential Raams behavior**

- Use private object storage with workspace/project authorization.
- Keep file metadata, version lineage, review state, comments, and storage
  object identifiers in the database.
- Define file size/type limits, delete behavior, and retention before launch.
- Avoid public download URLs; use the app's authenticated file-access pattern.

### 7. Finance planning, payments, funds, and receivables

**Visible capabilities**

- Finance planning tabs for Inflow, Outflow, and Documents.
- Inflow shows contract/payment milestones with percentages, amounts, due
  dates, work-done state, and totals.
- Outflow shows vendors, category, agreed amount, contract count, disbursed
  amount, payables, and dues.
- Project payment dashboard shows project-level totals for value, funds
  received, receivables, expenses, disbursements, payables, cash flow, and
  expected profit/loss; it also supports project-stage filters and import.
- Project Payments contains Expenses and Funds tabs, financial summary cards,
  listing/analytics views, filter, and add actions.
- Add Expense page/form includes date, amount, source, expense type, project,
  vendor, contract, category, receipt upload, stock-in checkbox, and remarks.
- Add Fund page/form includes collection date/mode, collected by, amount,
  contract, attachment, and remarks.
- Account Receivables surfaces overdue payments, overdue milestones, upcoming
  milestones, and written-off payments, with project, milestone, due date,
  amount, pending, received, and action columns.

**Potential Raams behavior**

- Keep money movement, contract obligations, and calculated summary totals
  distinct but linked.
- Validate totals and permissions server-side; make audit history visible.
- Define how negative dues, corrections, reversals, and written-off amounts
  should behave.
- Confirm whether import is CSV, spreadsheet, or a specific provider workflow.

### 8. Site progress and labor

**Site progress visible capabilities**

- Gallery grouped by upload date with All, Client Visible, and Client Not
  Visible filters.
- Add Progress action; images show uploader, preview, and per-item actions.
- Client visibility can be indicated on an image.

**Labor visible capabilities**

- Labor overview with total/skilled/unskilled/coordinator counts and
  attendance action.
- Report table columns include date, vendor, contracts, category, skilled,
  unskilled, coordinator, total, remark, attachment, and action.
- Analytics view shows daily labor trend and breakdown by vendor, category,
  and contract, with chart/table toggles.
- Client-visible control is present.

**Potential Raams behavior**

- Scope site media to a project and enforce private storage/access rules.
- Distinguish upload date, event date, uploader, and client visibility.
- Validate labor totals and associate workforce entries with the correct
  project/vendor/contract.
- The screenshots do not define approval or payroll rules.

### 9. Procurement, RFQ, orders, and inventory

**Visible capabilities**

- Project procurement navigation includes Request, RFQs, Orders, Deliveries,
  and Inventory.
- Request dashboard shows total/in-progress/due requests and item counts
  grouped by stage; list rows include ID, name, type, expected delivery,
  created date, stage, creator, and action.
- RFQ table shows ID, request name, vendors (with additional vendor count),
  expected delivery, item count, created date, status, and actions.
- Orders page has filters for project, creator, vendor, approval state,
  payment state, type, and date range. The supplied screenshot is a loading
  skeleton, so completed order columns/actions cannot be confirmed.
- Inventory history table shows item, date, category, quantity, UOM, unit rate,
  price, tax, and total; tabs include stock-in and stock-out history.
- Inventory Management shows warehouse/site rows, goods value, last stock-in,
  last stock-out, actions, search, archive state, and company/project warehouse
  tabs.

**Potential Raams behavior**

- Preserve traceability from request to RFQ to order, delivery, and inventory
  movement.
- Show counts and stage labels without treating them as the only source of
  record status.
- Validate quantities, units, tax, and totals; record stock adjustments as
  transactions.
- Define approval and warehouse access policies.

### 10. Warranty and service requests

**Visible capabilities**

- Warranty items and Service Requests tabs; list includes ticket ID, subject,
  item, model, installation date, request type, created date, and status.
- Status values include open, in progress, and closed.
- Request detail page or inline detail shows created/due dates, request type, issue
  description, item information, project/company, and a comments conversation
  with message composer.

**Potential Raams behavior**

- Link a request to a project and a product/item record.
- Preserve status history, conversation entries, and any due-date/SLA
  calculations.
- Add attachment support only after defining file permissions and limits.

### 11. Vendors and inspirations

**Vendors visible capabilities**

- Vendor listing with category, working model, created status, country, state,
  and city filters; search; create action.
- Rows show vendor name, phone, city, category, working model, status, and row
  actions.
- Vendor module has My Vendors, Find Vendors, and My Business Profile areas.

**Inspirations visible capabilities**

- Global and Custom collections; style filters such as traditional, minimalist,
  luxury, contemporary, rustic, eclectic, and other.
- Search, add inspiration, image-card gallery, and selection controls.

**Potential Raams behavior**

- Keep vendor discovery separate from a workspace's approved/vendor records.
- Define inspiration ownership, image source/licensing, tags, and project
  association.
- Do not infer that gallery images are freely reusable assets.

### 12. Users, roles, and attendance

**Users and roles visible capabilities**

- User admin tabs for Active, Role Management, Groups, and Deactivated, with
  purchased/active/unused license counts and add-user action.
- User list includes name/email, date of birth, mobile number, role, 2FA
  indicator, activity, manager, and actions.
- Role editor shows module-level permission groups and individual toggles,
  including project and communication permissions.

**Attendance visible capabilities**

- Today's summary for employees, check-ins, leave, and work-from-home.
- Approval tabs for leave, WFH, and visit requests; filter by user; approve or
  deny actions; report view.

**Important Raams scope constraint**

These screenshots imply multiple users, teams, managers, license counts, and
fine-grained roles. Raams' current milestone plan records a single user per
workspace and defers team collaboration for v1. Do not copy these multi-user
features without an explicit product decision. Attendance approvals also
depend on employee and permission models.

### 13. Reports

**Visible capabilities**

- A report directory presents cards for payment, client, lead, user, and labor
  reports, each with a category, short description, and View Full Report action.

**Potential Raams behavior**

- Build reports from authorized, paginated source data.
- Reuse filters and date ranges consistently with the underlying module.
- Define export formats and report permissions before implementation.

## Screenshot-by-screenshot inventory

The inventory follows the order in which the screenshots were attached.
Repeated captures of the same view are retained because they reveal layout
details or open/closed states.

| # | Screen represented | Main evidence |
|---:|---|---|
| 1 | Lead list with status menu open | Inline status workflow and many status choices |
| 2 | New Follow-Up dialog (reference; implement as a page/inline form) | Callback/meeting, lead, assignee, schedule, priority, reminder, notes, attachments |
| 3 | Lead list | Summary metrics, filters, search, pagination, lead/project columns |
| 4 | Lead Status settings | Reorder, color, closed-state, automation association |
| 5 | Create Quotation dialog (reference; implement as a page) | Source type and lead/project selection |
| 6 | Quotation editor, items | Editable item table, images, quantity, rates, discount, final price |
| 7 | Quotation preview | Summary totals and payment plan |
| 8 | Quotation preview, summary/payment plan | Totals, discount, charges, tax, staged payments |
| 9 | Quotation preview, terms | Bank details and terms/conditions content |
| 10 | Follow-Ups overview | Date ranges, follow-up KPIs, meeting/call summaries, performance |
| 11 | Follow-Ups overview, repeated capture | Confirms dashboard layout and metric hierarchy |
| 12 | Follow-Ups team | Team/user performance, ratios, streaks, team call logs |
| 13 | Project Insights | Project KPIs, ranked status list, stage chart, timeline |
| 14 | Project Data summary | Client/project context, communication, site progress, finance, milestones, procurement |
| 15 | Project Data modules | Module shortcut grid and project progress |
| 16 | Design Documents | Folders, file list, storage usage, version/status/client approval |
| 17 | Project Plan overview | Milestone counts, dates, progress, team/group cards |
| 18 | Project Plan expanded | Milestone table with timeline, assignee, visibility, updates, dependencies |
| 19 | Finance Planning, Inflow | Contract milestones, percent/amount, due date, work-done state |
| 20 | Finance Planning, Outflow | Vendor, category, agreement, disbursement, payables, dues |
| 21 | Finance Planning, Outflow repeated capture | Reinforces vendor-level financial table |
| 22 | Project Payments, Expenses | Financial summary, expense listing, filters, analytics toggle |
| 23 | Add Expense dialog (reference; implement as a page/inline form) | Expense fields, project/vendor/contract/category, receipt, stock-in, remarks |
| 24 | Add Fund dialog (reference; implement as a page/inline form) | Collection date/mode, collected by, amount, contract, attachment |
| 25 | Site Progress gallery | Visibility filters, dated image groups, uploader, image actions |
| 26 | Labour Report empty state | Labor summary, attendance action, report table structure |
| 27 | Labour Analytics | Daily trend and vendor/category/contract breakdowns |
| 28 | Procurement Requests | Request KPIs, stages, expected delivery, creator, request list |
| 29 | RFQ list | Request, vendors, item count, delivery date, status |
| 30 | Project Inventory stock history | Item movements with quantity, UOM, rate, tax, and totals |
| 31 | Orders loading state | Filter dimensions visible; loaded order behavior remains unknown |
| 32 | Inventory Management | Warehouse/site inventory, value and movement dates |
| 33 | Warranty service requests | Ticket list and statuses |
| 34 | Warranty request detail (reference; implement as a page/inline detail) | Issue/item/project data, status, comments, reply composer |
| 35 | Vendor list | Vendor filters, phone/city/category/model/status |
| 36 | Inspirations gallery | Global/custom, style filters, search, selection, add action |
| 37 | User management | Active users, roles, license counts, activity, 2FA, manager |
| 38 | Attendance approvals | Daily employee summary, leave/WFH/visit requests, approve/deny |
| 39 | User management repeated capture | Confirms user listing and administrative navigation |
| 40 | Edit Role | Permission toggles grouped by module |
| 41 | Payments Dashboard | Portfolio/project financial KPI cards, stage filter, import |
| 42 | Account Receivables | Overdue/upcoming/written-off cards and milestone receivables |
| 43 | Reports directory | Payment, client, lead, user, and labor report cards |

## Recommended implementation approach

1. **Map reference patterns to Raams modules.** Identify existing screens,
   models, APIs, and permissions; mark each desired behavior as existing,
   partial, or new.
2. **Agree on scope and data decisions.** In particular, resolve multi-user
   features, lead-status configuration, approval rules, report exports, and
   which finance/procurement screens are required.
3. **Establish shared UI primitives.** Navigation shell, page header, tabs,
   KPI card, filter/search row, data table, status chip, route-based or inline
   form, file picker, empty/error/loading state, and responsive breakpoints.
4. **Implement one complete vertical slice at a time.** Start with a selected
   module and deliver UI, API/data behavior, permissions, tests, and responsive
   validation together before expanding.
5. **Validate with reference-based review.** Compare hierarchy, density,
   navigation, and workflows, not copied brand assets or exact pixels.

## Open decisions before implementation

- Which module(s) should be implemented first? The references cover many
  modules, so the full set needs prioritization.
- Should the current single-user-per-workspace assumption change to support
  teams, roles, managers, assignments, and team analytics?
- Which lead statuses and closed-state/automation behaviors are required?
- Which finance, procurement, labor, warranty, and reporting workflows are
  in-scope for Raams v1?
- What should the loading Orders screen show once data is loaded?
- Which fields, exports, approval levels, and client-visible behaviors are
  required for each module?

