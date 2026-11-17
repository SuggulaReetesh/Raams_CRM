# Production Readiness Milestones

## Project target

Deliver the Raams CRM as a production-ready web, Android, and iOS app using
Vercel for web hosting and API functions, Neon for the CRM PostgreSQL database,
and Supabase Auth and Storage.

**Overall status:** Milestones 2–10 implementation in progress; provider setup,
live verification, platform release configuration, and operational procedures
remain outstanding.  
**Planning assumption:** One user per workspace, per the decision recorded in
Milestone 1. Team collaboration features are deferred for v1; reconsider team
memberships before enabling them.

## Status key

- `[ ]` Not started
- `[-]` In progress
- `[x]` Complete
- `[!]` Blocked

## Milestones

### 1. Confirm production requirements

**Status:** `[x]`  
**Depends on:** None

- [x] Confirm workspace model, user roles, invitations, and ownership rules.
- [x] Decide whether web and mobile must support offline reads/writes.
- [x] Select the email delivery approach.
- [x] Confirm whether WhatsApp Business API sending is required.
- [x] Decide whether online invoice payments are in scope.
- [x] Select the database provider and preferred data region.
- [x] Confirm web hosting and the separation between web hosting and PostgreSQL.
- [x] Select authentication and file-storage services.

**Decisions recorded (2026-11-16)**

- Workspace model: one user per workspace.
- Collaboration scope: defer team collaboration features for v1. Do not treat
  local persona previews as real user accounts or security boundaries.
- Offline behavior: online-first; cache reads, with no offline writes.
- Email: self-host an open-source mail server; no paid email SaaS. A library
  alone cannot deliver email; production sending requires server-side mail
  infrastructure, domain deliverability setup, monitoring, and operational
  work.
- WhatsApp: integrate WhatsApp Business API sending.
- Invoice payments: out of scope; invoices are tracked without in-app payment.
- Web hosting and API functions: Vercel.
- CRM database: Neon PostgreSQL. Vercel is the app/API host, not the PostgreSQL
  database provider.
- Authentication and file storage: Supabase Auth and private Supabase Storage.
  The CRM records remain in Neon; the Supabase project is used for Auth and
  Storage services.
- Preferred data location: Mumbai or another region in India. Verify that the
  selected Neon and Storage regions meet this requirement before provisioning.
- Retention/privacy requirements: none known yet; review before production.

**Acceptance criteria**

- Product and integration choices are recorded above.
- The India region preference and the pending privacy/retention review are
  documented.
- Team-only features are explicitly deferred for the single-user release.

### 2. Establish backend foundation

**Status:** `[-]`  
**Depends on:** Milestone 1

- [!] Create separate development, staging, and production environments for
  Vercel, Neon, and Supabase Auth/Storage. Provider accounts and project IDs
  have not been provisioned.
- [!] Verify and select India-region resources for Neon and Supabase Auth/
  Storage. Current provider documentation lists no India Neon region; Singapore
  is the nearest listed Neon region. Supabase lists Mumbai (`ap-south-1`) and
  Singapore (`ap-southeast-1`). Resolve whether to use Singapore for both or
  split Neon/Supabase regions before creating projects.
- [-] Select and configure the open-source mail server. Postal is selected for
  outbound delivery; the VM, sender domain, DNS, and deliverability operations
  remain unconfigured.
- [x] Define and version the initial database migration and migration ledger.
- [x] Add a Flutter workspace repository contract around local persistence.
- [x] Add validated Flutter and server environment configuration.
- [x] Add Vercel API liveness/readiness endpoints.
- [x] Add typed readiness models, loading/error states, and a Flutter API client
  for liveness/readiness checks.
- [x] Add an authenticated workspace API and connect the Flutter remote
  repository. Authentication and data-model validation continue in Milestones
  3–4.
- [x] Add automated migration naming and backend endpoint checks.
- [x] Add a transaction-safe database migration runner and mocked tests.
- [!] Apply migrations and run live integration checks. This requires a
  provisioned Neon database and trusted `DATABASE_URL`.

**Acceptance criteria**

- [x] Schema changes are reproducible from migrations.
- [x] No production secrets or privileged database keys are shipped in the
  client.
- [!] The milestone cannot be closed until the provider projects, region
  decision, mail host/DNS, and live database checks are complete.

### 3. Authentication, workspaces, and authorization

**Status:** `[-]`  
**Depends on:** Milestone 2

- [x] Implement sign-up/sign-in, sign-out, password recovery, and session
  handling in the Flutter client.
- [x] Add studio workspaces and owner profiles with one authenticated owner per
  workspace.
- [x] Defer invitations, team memberships, and multi-user role administration
  for v1.
- [x] Validate Supabase Auth tokens in the Vercel API before accessing Neon.
- [x] Enforce workspace authorization in the API and PostgreSQL row-level
  security policies.
- [!] Verify allowed and denied cross-workspace access with a live Neon
  integration test after provisioning.

**Acceptance criteria**

- Unauthenticated users cannot access protected CRM data.
- An owner cannot read or modify another studio's data, including through
  direct API requests.
- UI role checks are backed by server-side authorization.

### 4. Core CRM data and local-data migration

**Status:** `[-]`  
**Depends on:** Milestone 3

- [x] Add relational tables for clients, requirements, pipeline stages,
  projects, preferences, and activity history.
- [x] Add revision-protected feature-level remote writes and a paged,
  searchable collection API. The app loads collections in revision-consistent
  pages rather than one full workspace snapshot.
- [x] Add an opt-in one-time import flow for existing local workspace data.
- [x] Add server-side workspace validation, pagination, search, and duplicate
  handling. Live Neon integration remains pending.
- [ ] Add tests for migration, invalid data, and workspace scoping.

**Acceptance criteria**

- Core CRM changes persist across devices for the authenticated workspace owner.
- A user can migrate existing local records without silently losing data.

### 5. Project delivery and file storage

**Status:** `[-]`  
**Depends on:** Milestone 4

- [x] Add scoped tables and APIs for tasks, milestones, punch lists, work logs,
  attendance, and approval requests/decisions.
- [x] Move project files and progress photos to a private Supabase Storage bucket.
- [x] Store file metadata and storage paths in PostgreSQL instead of base64 data.
- [x] Enforce file type/size limits and owner authorization for upload, view, download,
  and deletion.
- [ ] Test file access for the workspace owner and isolation between workspaces.

The private bucket, project-asset metadata table, scoped delivery tables, and
owner-scoped storage policies are implemented. Live provider verification and
storage integration tests remain outstanding.

**Acceptance criteria**

- Files are not publicly accessible by default.
- Database records and stored files remain consistent through upload and delete
  operations.

### 6. Finance workflows

**Status:** `[-]`  
**Depends on:** Milestone 4

- [x] Add workspace-scoped tables and API persistence for quotations, line items, document templates,
  proposals, invoices, and payment records.
- [x] Validate totals, taxes, currency, and document numbering on trusted
  server-side operations.
- [x] Generate and export proposal and invoice HTML documents with escaped
  user-provided content.
- [x] Keep online payment processing out of scope for v1.
- [ ] Test concurrent edits and numbering to prevent duplicate document numbers.

Financial totals are calculated from line items on the server and database
constraints enforce unique numbers and invoice/payment integrity. Concurrent
edit tests and live database verification remain outstanding.

**Acceptance criteria**

- Finance records are workspace-scoped and auditable.
- Financial totals and document identifiers cannot be trusted solely from client
  input.

### 7. Communications and notifications

**Status:** `[-]`  
**Depends on:** Milestones 3 and 4

- [x] Persist communication history in PostgreSQL.
- [x] Integrate the self-hosted open-source mail server through server-side
  functions, with per-workspace credentials.
- [x] Integrate WhatsApp Business Cloud API sending through server-side
  functions, with per-workspace credentials.
- [x] Verify and process WhatsApp provider webhooks with signature checks,
  workspace routing, and duplicate-event protection.
- [x] Defer team mentions, teammate notifications, and multi-person approval
  routing for the single-user v1.
- [ ] Add push notifications only if a solo-user notification requirement is
  confirmed.
- [x] Keep provider secrets out of the Flutter client.

Communication history is mirrored to normalized PostgreSQL records. The
Flutter app now supports encrypted sender-account management, connected-account
sending, provider status updates, and the existing external-app fallback.
Provider accounts, server environment values, DNS/webhook registration, and
live delivery/isolation verification are still outstanding.

**Acceptance criteria**

- Message status reflects provider events where supported, rather than only
  manual confirmation.
- Notifications are delivered only to authorized recipients.

### 8. Sync, imports, exports, and reporting

**Status:** `[-]`  
**Depends on:** Milestones 4–7

- [x] Add revision-consistent paginated workspace loading and manual refresh
  for cross-device updates; realtime subscriptions remain deferred.
- [x] Keep the loaded workspace in memory only; do not queue offline writes in
  v1.
- [x] Validate and import CSV data into the authenticated owner's workspace.
- [x] Generate authenticated-owner exports and reports from revision-
  consistent paginated remote data; persona-preview filters are UI behavior,
  not a security boundary.
- [ ] Test cross-device updates and large workspaces.

The app loads workspace collections in bounded pages, verifies that all pages
share a single workspace revision, and provides manual refresh. CSV imports and
reports refresh remote data first. Live Neon checks, cross-device tests, and
large-workspace performance verification remain outstanding.

**Acceptance criteria**

- Updates made by the workspace owner appear on other signed-in devices according
  to the agreed sync behavior.
- Imports, exports, and reports do not expose data across workspaces.

### 9. Cross-platform quality and release readiness

**Status:** `[-]`  
**Depends on:** Milestones 3–8

- [ ] Test responsive web layouts and supported browsers.
- [x] Add native Supabase auth callback handling and platform URL-scheme
  registration for Android and iOS.
- [x] Remove Android release's debug-signing fallback and support signing from
  build-environment values.
- [ ] Test Android and iOS authentication, file operations, deep links, and
  notifications on real devices.
- [ ] Configure the production Android application ID and release signing
  values.
- [ ] Configure iOS bundle ID, signing, permissions, and store metadata.
- [ ] Configure web domain, HTTPS, redirects, and required hosting settings.
- [ ] Add unit, widget, integration, and end-to-end tests for critical flows.
- [ ] Review accessibility, privacy disclosures, and platform-specific behavior.

**Acceptance criteria**

- Critical CRM workflows pass on web, Android, and iOS.
- Release builds use production identifiers and signing, not development
  credentials.
- No known critical defects remain in authentication, authorization, data
  integrity, or file access.

### 10. Production operations and launch

**Status:** `[-]`  
**Depends on:** Milestone 9

- [ ] Configure database backups and verify a restore procedure.
- [ ] Add application error reporting, backend logs, and actionable alerts.
- [x] Add generated request IDs to API responses and sanitized backend error
  logs to support request correlation.
- [x] Add PostgreSQL-backed per-owner rate limits for workspace, integration,
  and communications APIs.
- [ ] Review rate limits, access policies, data retention, and secret rotation.
- [ ] Document deployment, rollback, incident response, and support procedures.
- [ ] Run a production-readiness review and staged rollout.

**Acceptance criteria**

- A backup restore has been tested successfully.
- Production monitoring and rollback procedures are operational.
- Launch approval is recorded.

## Release blockers

- [ ] RLS and workspace-isolation tests pass.
- [ ] No privileged backend key is present in any client build.
- [ ] Production build signing and platform identifiers are configured.
- [ ] Backup restoration and deployment rollback have been verified.
- [ ] Critical end-to-end workflows pass on web, Android, and iOS.
