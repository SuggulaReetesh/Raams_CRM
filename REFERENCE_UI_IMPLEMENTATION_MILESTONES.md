# Reference-Driven UI Implementation Milestones

## Purpose

This is an additive implementation workstream based on
[REFERENCE_UI_ANALYSIS.md](./REFERENCE_UI_ANALYSIS.md). It supplements the
production and feature milestones in [MILESTONES.md](./MILESTONES.md); it does
not replace them.

The app already has working navigation, CRM models, backend persistence, and
multiple project, finance, procurement, workforce, and communication flows.
The screenshots therefore represent a mixture of existing behavior, gaps, and
new presentation needs. The first milestone verifies those differences so we
do not rebuild existing capabilities unnecessarily.

## Current-code starting point

| Existing area | Starting point to preserve and extend |
|---|---|
| App shell and navigation | `lib/main.dart` owns the current sections and navigation. Keep the existing shell, menu structure, and destinations stable. |
| Client/project data | `lib/customer.dart` and `lib/delivery.dart` contain the current CRM and project data models/workflows. |
| Quotation editor | `QuotationEditorPage` already opens through route navigation from `lib/main.dart`; reuse it rather than replacing it with a new modal editor. |
| Finance | `lib/finance.dart` and `lib/finance_dialogs.dart` contain current finance data and form/editor components. |
| Procurement | `lib/procurement.dart` and `lib/procurement_dialogs.dart` contain current procurement models and workflows. |
| Project planning, files, and site work | `lib/delivery.dart`, `lib/project_planning_dialogs.dart`, and `lib/site_execution.dart` contain existing project and site workflows. |
| Workforce and attendance | `lib/workforce.dart` and current attendance flows contain the existing workforce foundation. |
| Communication and vendors | `lib/communication.dart`, `lib/communication_dialogs.dart`, and the vendor flows in `lib/main.dart` already support related CRM operations. |

This is an initial code map, not a claim that every screenshot feature already
exists. Milestone 1 must verify each item against current UI, data, API, and
tests.

## Non-disruption rules

1. **Do not replace or reorganize the app shell.** Keep current navigation,
   labels, section ordering, and existing destinations. Add new destinations
   within the relevant existing section or link to a new subpage from the
   current screen.
2. **Use additive screens for disruptive workflows.** Create dedicated
   `Navigator` routes or inline page sections for large forms and record
   details. Do not use modal dialogs or overlay drawers for these flows.
3. **Preserve existing behavior until the replacement is verified.** Build the
   new screen alongside the current workflow. After parity and regression
   checks pass, route the existing action to the new screen. Do not leave a
   popup as the normal alternative for that workflow.
4. **Avoid global restyling.** Introduce shared visual components/tokens in a
   scoped way and adopt them on new or specifically updated screens. Do not
   recolor or redesign unrelated screens as part of this workstream.
5. **Reuse existing models, APIs, permissions, and storage.** Add a migration
   only when the gap audit proves the current schema cannot represent required
   data. Keep workspace authorization and current owner scoping intact.
6. **Respect the current single-user workspace scope.** Team performance,
   managers, license counts, and multi-user role administration shown in the
   references are deferred unless the product scope is explicitly changed.
7. **Keep native control behavior practical.** Select menus and date pickers
   may use their normal control menus; the no-popup requirement applies to
   substantial create/edit/detail workflows.

## Status key

- `[ ]` Not started
- `[-]` In progress
- `[x]` Complete
- `[!]` Blocked on a product or data decision

All implementation milestones below are currently planned and not started.

## Milestones

### 1. Audit current flows and create a feature-gap map

**Status:** `[ ]`
**Depends on:** None

- [ ] Map each of the 43 reference captures to the closest current Raams
  screen, route, model, API, permission, and test.
- [ ] Classify each requested capability as existing, needs presentation
  changes, needs behavior changes, or is new.
- [ ] Record existing app entry points and baseline behavior before adding
  routes or changing actions.
- [ ] Identify any required schema/API gaps; do not propose duplicate entities
  for data already represented in current workspace models.
- [ ] Confirm scope for team-only workflows, configurable lead automations,
  order-list details, and any screenshot behavior that is not visible.

**Acceptance criteria**

- Every reference screen is accounted for as existing, extend, new, or
  deferred with a reason.
- Current user flows and regression tests are identified before they are
  changed.
- Any decision that would change the one-user-per-workspace assumption is
  recorded as a blocker, not silently included.

### 2. Add non-modal page patterns without changing the app shell

**Status:** `[ ]`
**Depends on:** Milestone 1

- [ ] Add reusable page-level patterns for titles/actions, tabs, metric cards,
  filter/search rows, tables, status chips, inline validation, and empty,
  loading, and error states.
- [ ] Add a consistent subpage pattern with back navigation, contextual
  client/project identity, and save/cancel behavior.
- [ ] Ensure forms can retain draft values and report unsaved changes when
  navigating away.
- [ ] Keep existing top-level navigation, menu layout, theme, and unrelated
  screens unchanged.
- [ ] Make large form/detail workflows navigable pages or inline sections, not
  modal dialogs or overlay drawers.

**Acceptance criteria**

- Existing destinations remain available and their current navigation works.
- New screens can be opened and closed through normal page navigation without
  losing the underlying workspace state.
- The shared patterns are usable at desktop and mobile widths and support
  keyboard/accessibility semantics.

### 3. Add lead and follow-up workflows incrementally

**Status:** `[ ]`
**Depends on:** Milestones 1–2

- [ ] Extend the current lead list only for gaps found in the audit: summary
  counts, filtering, search, sorting, pagination, status display, and relevant
  lead/project fields.
- [ ] Preserve the existing pipeline and status configuration behavior; add
  configurable fields or automation only when supported by current data and
  approved scope.
- [ ] Add a dedicated Follow-Up create/edit page for callback or meeting,
  lead, schedule, priority, reminder, notes, and attachments.
- [ ] Add the follow-up overview, date-range filters, and available summary
  metrics using existing data.
- [ ] Defer team rankings, manager/assignee administration, and call-provider
  analytics until multi-user and telephony scope is confirmed.

**Acceptance criteria**

- Existing lead create/edit/status flows remain functional.
- Follow-up creation and editing use a page or inline form, with validation,
  save/cancel, and attachment handling.
- Summary values reflect persisted records; unavailable team/telephony data is
  not fabricated.

### 4. Extend project workspace and delivery screens

**Status:** `[ ]`
**Depends on:** Milestones 1–2

- [ ] Add or extend a project overview using existing project/client data,
  progress, milestones, tasks, communications, files, and procurement
  summaries.
- [ ] Add project-context navigation to new module screens without replacing
  the current project entry point or reorganizing global navigation.
- [ ] Extend project planning with milestone list/timeline views, progress,
  dependencies, and client visibility only where equivalent functionality is
  missing.
- [ ] Extend site-progress browsing with date grouping, client-visibility
  filters, and media previews using current private file storage.
- [ ] Extend project documents with folders, versions, status, and comments
  only after confirming current asset metadata can support them.

**Acceptance criteria**

- Current project, task, milestone, and file workflows continue to work.
- New project pages link to the same underlying project records and enforce
  existing access checks.
- File access remains private and scoped; no data is duplicated solely for the
  new presentation.

### 5. Complete quotation and document workflows

**Status:** `[ ]`
**Depends on:** Milestones 1–2 and 4

- [ ] Reuse the existing route-based `QuotationEditorPage` and its calculation,
  catalog, version, and save behavior.
- [ ] Add a dedicated quotation start/selection page for choosing a project or
  lead and its template/type; do not silently select the first eligible
  project.
- [ ] Extend the editor/preview for the visible item, image, totals, payment
  plan, terms, and document actions only where the audit finds gaps.
- [ ] Ensure quotation start, edit, proposal generation, and related document
  workflows do not require popup forms.
- [ ] Extend project document browsing only through the existing private
  storage and authorization mechanisms.

**Acceptance criteria**

- Creating a quotation remains a full-page route and associates it with the
  user's explicit project/lead choice.
- Existing quotation save, calculation, PDF/document, and approval flows pass
  their current tests.
- No quote totals or document permissions are trusted solely to client-side
  input.

### 6. Add project finance pages while retaining existing finance data flows

**Status:** `[ ]`
**Depends on:** Milestones 1–2 and 4

- [ ] Extend project finance overview with existing inflow/outflow, funds,
  expenses, receivables, and payable data where present.
- [ ] Add route-based or inline Expense and Fund forms; preserve all existing
  validations, attachments, and save behavior.
- [ ] Add receivables and finance summary views only for values backed by
  existing persisted data and established calculations.
- [ ] Reuse current finance models, APIs, and server-side calculations; add
  schema/API changes only for verified data gaps.
- [ ] Defer bulk import or new approval behavior until its format and rules are
  specified.

**Acceptance criteria**

- Existing finance records remain accessible and unchanged through the
  current app.
- Expense/Fund workflows no longer require a popup for the primary form.
- Totals, permissions, attachment access, and financial audit history remain
  correct.

### 7. Extend procurement, inventory, and vendor screens

**Status:** `[ ]`
**Depends on:** Milestones 1–2 and 4

- [ ] Map the current procurement/request/RFQ/order/delivery flows and extend
  lists and summaries only where missing.
- [ ] Add or extend inventory warehouse and movement views using existing
  inventory records and transaction history.
- [ ] Route substantial create/edit actions to dedicated pages while keeping
  existing procurement actions and approval rules intact.
- [ ] Extend vendor listing/search/filter behavior using current vendor
  records; use non-modal pages for substantial vendor forms if they interrupt
  the current flow.
- [ ] Confirm the intended loaded Orders columns and actions before
  implementing details that are not visible in the reference captures.

**Acceptance criteria**

- Existing requisition, RFQ, order, delivery, inventory, and vendor workflows
  remain reachable and preserve their current data.
- Inventory movements and procurement totals remain consistent with existing
  validation rules.
- Unknown behavior from the Orders loading screenshot is confirmed rather
  than guessed.

### 8. Extend workforce, warranty, inspirations, and reports

**Status:** `[ ]`
**Depends on:** Milestones 1–2 and 4

- [ ] Extend labor and attendance views using current workforce/attendance
  models; do not add team dashboards unless user/account scope permits them.
- [ ] Add a warranty/service-request list and non-modal detail/conversation
  page only after defining the required request fields and status behavior.
- [ ] Add an inspirations gallery only after defining image source, ownership,
  and storage/licensing rules.
- [ ] Extend the report directory and report pages using authorized, existing
  workspace data and current reporting/export infrastructure.
- [ ] Defer user licensing, manager hierarchy, team performance, and
  multi-person role administration under the current single-user scope.

**Acceptance criteria**

- New workforce/service/report views use the established workspace
  authorization and data sources.
- Any new persistent fields or entities have explicit requirements and
  migration tests.
- Deferred team and image-source requirements are documented and not simulated
  in the UI.

### 9. Cross-module regression, responsive QA, and rollout

**Status:** `[ ]`
**Depends on:** Milestones 3–8

- [ ] Add focused widget/integration tests for each new route and the workflow
  that opens it from the existing screen.
- [ ] Verify save, cancel, back navigation, validation, unsaved drafts, and
  error states.
- [ ] Verify current app navigation, permissions, data persistence, and
  project/client relationships after each affected screen is connected.
- [ ] Review desktop, tablet, and mobile layouts; keyboard navigation and
  accessible labels; loading/empty/error states.
- [ ] Roll out incrementally by existing module entry points; do not replace
  the full application shell in one release.

**Acceptance criteria**

- Existing critical flows pass before and after each new page is connected.
- All large create/edit/detail workflows in this workstream use pages or inline
  content, not modal popups or overlay drawers.
- No unrelated navigation or theme changes are introduced.
- Any regression is fixed before enabling the affected entry point for normal
  use.

## Implementation scope note

This plan describes a staged product/UI workstream, not a request to reproduce
the reference application exactly. Each feature must be checked against the
current Raams implementation during Milestone 1. If a capability already
works, retain it and only make the smallest required presentation change.
Features that require unapproved team accounts, uncertain data rules, or
unseen behavior stay deferred until those decisions are made.

