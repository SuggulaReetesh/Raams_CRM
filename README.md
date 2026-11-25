# Raams CRM

Flutter CRM client for web, Android, and iOS. The selected backend is a Vercel
API, Neon PostgreSQL for CRM records, and Supabase Auth and private Storage.
Development defaults to local `SharedPreferences`; staging and production use
the authenticated remote workspace API and never fall back to local data.

## Flutter development

```powershell
flutter pub get
flutter run
flutter analyze
flutter test
```

Non-development builds require the API URL, Supabase project URL, and the
public Supabase publishable key. These are build-time settings, not service-role
secrets:

```powershell
flutter build web --dart-define=APP_ENV=staging --dart-define=API_BASE_URL=https://your-staging-api.example --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_... --dart-define=AUTH_REDIRECT_URL=https://your-staging-app.example/
```

For Android and iOS, set `AUTH_REDIRECT_URL=raamscrm://login-callback/` instead
and register each callback in the Supabase Auth redirect allowlist. Email
confirmation and password recovery use this configured redirect. The native
scheme is registered in both platform projects.

The app checks that the API environment matches the build and that Neon is
ready before allowing sign-in. Sign-up, sign-in, sign-out, password recovery,
and remote workspace persistence are wired to Supabase Auth and the Vercel API.
Supabase email confirmation settings must be configured in the project before
those flows can be used in a deployed app.

Android release builds no longer fall back to debug signing. Configure
`APP_ANDROID_APPLICATION_ID`, `ANDROID_KEYSTORE_PATH`,
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD`
when building a signed release. Keep signing credentials in the build
environment, never in source control. Configure the iOS bundle identifier and
signing through Xcode on macOS.

## Backend

Use Node.js 22 or newer:

```powershell
npm ci
npm run check:backend
```

Vercel API endpoints:

- `GET /api/health` reports API liveness and deployment environment.
- `GET /api/ready` probes the Neon database.
- `GET /api/workspace` loads the authenticated owner's workspace.
- `GET /api/workspace?collection=...&limit=100&offset=0` loads an authorized,
  paged workspace collection with a revision marker.
- `PUT /api/workspace` saves the workspace with optimistic revision checks.
- `GET`, `PUT`, and `DELETE /api/integrations` manage per-workspace Postal and
  WhatsApp sender accounts. Credentials are encrypted by the API and are never
  returned to the client.
- `POST /api/communications` sends email or WhatsApp messages from the
  connected workspace account and records provider delivery status.
- `POST` and `DELETE /api/project-files` authorize project-file access through
  the workspace and project roles, then issue short-lived Supabase Storage
  upload/download URLs.
- `GET` and `PUT /api/quotation-catalog` read or save workspace quotation
  packages, rooms, components, services, materials, finishes, hardware,
  and pricing rules.
- `GET`, `POST`, and `PUT /api/quotation` manage server-calculated quotation
  revisions, submission, approval, rejection, and totals.
- `POST /api/quotation-pdf` renders and downloads the current revision as a
  premium PDF document using PDFKit.
- `GET` and `POST /api/webhooks/whatsapp` verify and process WhatsApp webhook
  events. Configure this URL in the Meta app.

The API validates Supabase JWTs using the project's JWKS endpoint. A signed-in
user can belong to multiple organizations; every workspace operation requires
an explicit `X-Workspace-Id` and active membership, and executes Neon queries
under PostgreSQL row-level security. Never put
`DATABASE_URL`, a Supabase service-role key, or any other privileged secret in
Flutter build defines or source control. The Supabase publishable key is public
and is not a substitute for authorization.
Authenticated workspace reads/writes, integration settings, and communications
sends use per-user PostgreSQL rate limits and return `429` with `Retry-After`
when exceeded. Configure edge-level limits separately for unauthenticated
traffic and provider webhooks.

## Environment setup

Configure each development, staging, and production environment separately in
Vercel, Neon, and Supabase. `.env.example` lists local server variables; use the
provider dashboards for deployed secrets. Do not copy one environment's
database URL or Supabase project settings into another environment.

For local API work, put development-only values in the ignored `.env.local`:
`APP_ENV`, `DATABASE_URL`, and `SUPABASE_URL`. The Flutter app's public
Supabase URL/key and API URL are supplied with `--dart-define`.
Configure sender integrations only on the server:

- `SUPABASE_SERVICE_ROLE_KEY`: server-only credential used to send organization
  invitations through Supabase Auth and issue project-file Storage URLs. Never
  expose this key in Flutter or the browser.
- `SUPABASE_INVITE_REDIRECT_URL`: HTTPS web callback or the registered
  `raamscrm://login-callback/` mobile callback. Add the exact URL to Supabase
  Auth's allowed redirect URLs.
- `INTEGRATION_ENCRYPTION_KEY`: canonical base64 for 32 random bytes; generate
  with `openssl rand -base64 32`. Keep a secure backup because losing this key
  makes saved sender credentials undecryptable.
- `POSTAL_SMTP_HOST` and `POSTAL_SMTP_PORT`: SMTP host and TLS port for the
  self-hosted Postal server. Individual workspace SMTP usernames, passwords,
  and sender identities are entered in the authenticated app and encrypted in
  Neon.
- `WHATSAPP_GRAPH_API_VERSION`, `WHATSAPP_APP_SECRET`, and
  `WHATSAPP_VERIFY_TOKEN`: Meta Graph API/webhook configuration. Each workspace
  supplies its WhatsApp phone-number ID and access token in the app.

Never put these server secrets in Flutter build defines or commit them. Configure
them separately in each Vercel environment. Provider project setup, DNS,
webhook subscription, and live delivery checks remain required before release.

Database changes are versioned in `database/migrations/`. Apply them to
development with `npm run db:migrate`. Staging and production require setting
`CONFIRM_DATABASE_MIGRATION` to the matching `APP_ENV`. Review and apply
migrations in order; a live migration still requires a provisioned Neon
database.

## Region and mail decisions

- Neon currently lists Singapore as its nearest region to India and does not
  list an India region. Supabase supports Mumbai. Decide whether to use
  Singapore for both services or accept cross-region Neon/Supabase resources
  before provisioning. Region selection is not a regulatory-compliance review.
- Postal is the selected self-hosted open-source mail delivery platform.
  Production use still requires a VM, sending domain/subdomain, DNS records,
  outbound SMTP access, deliverability monitoring, and an operator.
- Per-workspace Postal and WhatsApp credential APIs, encrypted storage,
  outbound delivery, and WhatsApp webhook handlers are implemented. Postal
  hosting, Meta setup, server environment values, and live delivery checks are
  not configured yet.

## Current implementation boundaries

- CRM repositories use the server-backed workspace API in staging/production;
  development continues to use local storage.
- The server stores workspace entities as workspace-scoped records and rejects
  stale writes rather than silently overwriting another device's changes.
- The client loads the workspace through bounded collection pages and exposes
  manual refresh; pages from mixed workspace revisions are rejected. There is
  no offline write queue or realtime subscription in v1.
- Cloud projects, region selection, DNS, production secrets, release signing,
  and live integration checks have not been provisioned.
- Native auth callbacks are registered as `raamscrm://login-callback/`.
- API responses include a generated `X-Request-Id` header for correlating
  sanitized server-side error logs.
