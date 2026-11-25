# Raams CRM - Manual Deployment Guide

This runbook describes how to deploy and operate the current application without automated Git deployments.

## 1. Current deployment layout

The application is split across two Vercel projects:

| Purpose | Current URL |
|---|---|
| Flutter web app | `https://raams-crm-web.vercel.app` |
| Node.js API | `https://raams-crm.vercel.app` |
| Supabase project | `https://gnsaejlsgqtowutfkpte.supabase.co` |
| PostgreSQL | Neon |

The browser app calls `/api/...` on its own domain. Vercel routes those requests to the API project. This same-origin arrangement is important: it avoids cross-origin browser errors.

The API uses Supabase JWT authentication, Neon PostgreSQL, and private Supabase Storage. Flutter builds must never contain a Neon URL, Supabase service-role key, integration encryption key, SMTP password, or WhatsApp access token.

## 2. Important security preparation

Some database and Supabase credentials were shared in chat during setup. Before using this deployment with real customer data:

1. Rotate the Neon database password in Neon.
2. Replace the Supabase service-role key in Supabase.
3. Update the new values in the Vercel API project's Production environment.
4. Update local `.env.local` if local API development is needed.
5. Redeploy the API after changing Production environment variables.
6. Never add a secret to this document, source code, a Flutter `--dart-define`, or Git.

Use different Neon branches/projects and different Supabase projects for development, staging, and production. The previously supplied Neon URL was used for both migration and production setup; create environment separation before storing real customer data.

## 3. Required accounts and local tools

Install or have access to:

- Node.js 22 or newer and npm.
- Flutter stable SDK compatible with the repository's Dart SDK.
- Git.
- Vercel account and Vercel CLI.
- Neon account.
- Supabase account.
- Android Studio/Android SDK for Android builds.
- macOS with Xcode for iOS signing and release builds.

Check local versions:

```powershell
node --version
npm.cmd --version
C:\flutter\bin\flutter.bat --version
npx.cmd --yes vercel --version
```

In the following commands, run PowerShell from the repository root:

```powershell
cd C:\Users\HP\AndroidStudioProjects\Raams_CRM
```

## 4. Configure Neon PostgreSQL

### 4.1 Create separate environments

In Neon:

1. Create a development project/branch.
2. Create a staging branch.
3. Create a production branch.
4. Keep credentials and database URLs separate.
5. Prefer the pooled endpoint for application runtime.
6. Keep the unpooled endpoint for database administration when a direct connection is needed.

Do not paste connection strings into GitHub, source files, screenshots, or Flutter build commands.

### 4.2 Configure local development

Create the ignored file `.env.local` in the repository root:

```text
APP_ENV=development
DATABASE_URL=<development Neon pooled PostgreSQL URL>
SUPABASE_URL=<development Supabase project URL>
SUPABASE_SERVICE_ROLE_KEY=<development server-only service role key>
SUPABASE_INVITE_REDIRECT_URL=http://localhost:3000/login-callback
INTEGRATION_ENCRYPTION_KEY=<base64 encoding of 32 random bytes>
POSTAL_SMTP_HOST=
POSTAL_SMTP_PORT=587
WHATSAPP_GRAPH_API_VERSION=
WHATSAPP_APP_SECRET=
WHATSAPP_VERIFY_TOKEN=
```

Generate a new encryption key locally:

```powershell
node -e "console.log(require('node:crypto').randomBytes(32).toString('base64'))"
```

Back up this key in an approved secrets manager. Losing it prevents decryption of previously saved provider credentials. Use the same key across API instances in one environment; use a different key in each environment.

Check that `.env.local` is ignored before adding any secret:

```powershell
git check-ignore -v .env.local
```

### 4.3 Apply migrations

Install dependencies and run the backend checks first:

```powershell
npm ci
npm.cmd run check:backend
```

For development:

```powershell
npm.cmd run db:migrate
```

The migration runner applies files sequentially and records them in `schema_migrations`. The current quotation schema includes migrations `0017_quotation_catalog_foundation.sql` and `0018_quotation_revision_foundation.sql`.

For staging/production, use that environment's connection string and explicitly confirm the target. For example, from a temporary trusted PowerShell session:

```powershell
$env:APP_ENV = 'staging'
$env:CONFIRM_DATABASE_MIGRATION = 'staging'
$env:DATABASE_URL = '<staging Neon URL>'
npm.cmd run db:migrate
```

For production, change both environment values to `production` and set the production URL. Run a production migration only after the same migrations were tested on staging and a current backup exists. Clear temporary variables after the command:

```powershell
Remove-Item Env:\DATABASE_URL
Remove-Item Env:\CONFIRM_DATABASE_MIGRATION
Remove-Item Env:\APP_ENV
```

Do not run a production migration against the URL used for development by mistake. Verify the migration version in Neon before deploying application code.

## 5. Configure Supabase Auth and Storage

In the Supabase dashboard for the environment:

1. Confirm email/password sign-in is enabled.
2. Configure email confirmation and password recovery behavior.
3. Set the Site URL to the web application domain.
4. Add exact redirect URLs to Authentication URL Configuration:
   - Production web: `https://raams-crm-web.vercel.app/login-callback`
   - Local web, if used: `http://localhost:3000/login-callback`
   - Android/iOS: `raamscrm://login-callback/`
5. Confirm the private project-files Storage bucket and policies are deployed.
6. Copy the project URL and public publishable key for Flutter builds.
7. Copy the service-role key only to the API server's secret environment.

When using a custom web domain, add its exact callback URL and rebuild the Flutter web application with that URL.

The publishable key is public, but it does not grant data access by itself. Database and storage authorization must remain enforced by the API and policies.

## 6. Deploy the API to Vercel manually

### 6.1 Link the repository

Install/authorize Vercel CLI once:

```powershell
npx.cmd --yes vercel login
npx.cmd --yes vercel link
```

Choose the API project named `raams-crm` in the correct Vercel account/team. Check the link:

```powershell
npx.cmd --yes vercel project ls
```

If creating a new project, use a lowercase project name. The API project must not be the static Flutter web project.

### 6.2 Add API environment variables in the Vercel dashboard

Open the `raams-crm` Vercel project, then **Settings → Environment Variables**. Configure these in Development, Preview/Staging, and Production with values for the matching environment:

| Variable | Required | Notes |
|---|---:|---|
| `APP_ENV` | Yes | `development`, `staging`, or `production` |
| `DATABASE_URL` | Yes | Matching Neon pooled PostgreSQL URL |
| `SUPABASE_URL` | Yes | Matching Supabase project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Yes | Server-only secret |
| `SUPABASE_INVITE_REDIRECT_URL` | Yes | Exact callback URL allowed by Supabase |
| `INTEGRATION_ENCRYPTION_KEY` | Yes | Base64 for 32 random bytes; stable per environment |
| `POSTAL_SMTP_HOST` | Optional | Required only when SMTP sending is configured |
| `POSTAL_SMTP_PORT` | Optional | Usually `587` or provider-specific TLS port |
| `WHATSAPP_GRAPH_API_VERSION` | Optional | Required for WhatsApp |
| `WHATSAPP_APP_SECRET` | Optional | Meta webhook signature verification |
| `WHATSAPP_VERIFY_TOKEN` | Optional | Meta webhook verification token |

Use Vercel's encrypted/secret variable type for private values. Do not copy production secrets into Preview/Development.

### 6.3 Deploy

From the repository root, after reviewing the diff and passing tests:

```powershell
npm ci
npm.cmd run check:backend
npx.cmd --yes vercel deploy --prod --yes
```

The CLI must report a `READY` deployment. If the deployment fails because the upload exceeds Vercel's file limit, check `.vercelignore`; do not include `.git`, `node_modules`, Flutter platform build directories, or generated native build output in the API deployment.

Production API deployment URL:

```text
https://raams-crm.vercel.app
```

The API must be publicly reachable by the Flutter app. Keep authentication and authorization in the API; do not enable Vercel login-only deployment protection for a public customer-facing API.

### 6.4 Verify API and database

```powershell
curl.exe -i https://raams-crm.vercel.app/api/health
curl.exe -i https://raams-crm.vercel.app/api/ready
```

Expected:

- Health: HTTP 200, `{"status":"ok","environment":"production"}`
- Ready: HTTP 200, `{"status":"ready","database":"connected"}`

Do not continue with a web release if readiness reports `503`.

## 7. Build and deploy Flutter web manually

The web app is deployed separately from the API as the `raams-crm-web` Vercel project. The tracked `vercel.web.json` file configures:

- Same-origin `/api/*` proxy to `https://raams-crm.vercel.app/api/*`.
- Static file handling.
- Flutter single-page-app route fallback.

### 7.1 Build the app

Use the production API base as the web app domain, not the API domain. This makes browser API requests same-origin and prevents CORS failures:

```powershell
C:\flutter\bin\flutter.bat pub get
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat build web --release `
  --dart-define=APP_ENV=production `
  --dart-define=API_BASE_URL=https://raams-crm-web.vercel.app `
  --dart-define=SUPABASE_URL=<production Supabase project URL> `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<production publishable key> `
  --dart-define=AUTH_REDIRECT_URL=https://raams-crm-web.vercel.app/login-callback
```

The publishable key is the only Supabase key allowed in this command. Never add the service-role key or a database URL.

### 7.2 Copy the Vercel web routing configuration

Every Flutter build recreates `build\web`; copy the tracked proxy configuration after each build:

```powershell
npm.cmd run prepare:web-deploy
```

Verify the generated file exists:

```powershell
Get-Content build\web\vercel.json
```

It must proxy `/api/(.*)` to the API project before the SPA fallback.

### 7.3 Deploy the web output

Link the web output to the separate `raams-crm-web` Vercel project in the Vercel dashboard/CLI. Then deploy only `build\web`:

```powershell
npx.cmd --yes vercel deploy build/web --prod --yes --project raams-crm-web
```

Confirm the deploy is `READY` and the public alias is:

```text
https://raams-crm-web.vercel.app
```

Do not run the Flutter web deployment from the API project's root configuration. Do not add a blanket `/api` SPA fallback that sends API requests to `index.html`.

### 7.4 Verify web and same-origin API

```powershell
curl.exe -I https://raams-crm-web.vercel.app
curl.exe -I https://raams-crm-web.vercel.app/login-callback
curl.exe -i https://raams-crm-web.vercel.app/api/health
curl.exe -i https://raams-crm-web.vercel.app/api/ready
```

Expected:

- Web and login callback: HTTP 200.
- Health: HTTP 200 with environment `production`.
- Ready: HTTP 200 with database `connected`.

In browser developer tools, confirm app requests use `https://raams-crm-web.vercel.app/api/...`, not a separate cross-origin API hostname.

## 8. Manual Flutter local development

Local development uses the local API and development services. Start the Vercel API in one PowerShell window:

```powershell
npx.cmd --yes vercel dev --listen 3000 --yes
```

If Vercel CLI reports permission errors creating symlinks, enable Windows Developer Mode or run the CLI in an approved environment that permits symlinks. Do not work around the issue by disabling API authentication.

In another PowerShell window, run Flutter web:

```powershell
C:\flutter\bin\flutter.bat run -d chrome `
  --dart-define=APP_ENV=development `
  --dart-define=API_BASE_URL=http://localhost:3000 `
  --dart-define=SUPABASE_URL=<development Supabase project URL> `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<development publishable key> `
  --dart-define=AUTH_REDIRECT_URL=http://localhost:3000/login-callback
```

Use a local development database/project only. Never run this command with `APP_ENV=production` for routine development.

## 9. Android release deployment

Android builds can be created on Windows with Android Studio/Android SDK installed.

### 9.1 Prepare signing

Create a release keystore securely and back it up. Set the following in the release build environment; do not commit them:

```powershell
$env:APP_ANDROID_APPLICATION_ID = '<your production Android application ID>'
$env:ANDROID_KEYSTORE_PATH = '<absolute path to your release keystore>'
$env:ANDROID_KEYSTORE_PASSWORD = '<keystore password>'
$env:ANDROID_KEY_ALIAS = '<key alias>'
$env:ANDROID_KEY_PASSWORD = '<key password>'
```

Use the same application ID consistently for the Play Store. Keep the signing key backed up offline and in an approved secrets vault.

### 9.2 Build and verify

```powershell
C:\flutter\bin\flutter.bat pub get
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat build appbundle --release `
  --dart-define=APP_ENV=production `
  --dart-define=API_BASE_URL=https://raams-crm-web.vercel.app `
  --dart-define=SUPABASE_URL=<production Supabase project URL> `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<production publishable key> `
  --dart-define=AUTH_REDIRECT_URL=raamscrm://login-callback/
```

Output is normally under `build\app\outputs\bundle\release\`. Test the signed artifact on a physical Android device before uploading to Play Console.

### 9.3 Play Console

1. Create/choose the app using the configured application ID.
2. Complete store listing, privacy, content rating, data-safety, and app-access forms.
3. Upload the signed AAB to an internal testing track.
4. Test login, email confirmation, password recovery, workspace access, file operations, and links.
5. Promote through closed testing and production according to the release policy.

## 10. iOS release deployment

iOS signing and App Store submission require macOS and Xcode; this cannot be completed from Windows.

1. Open `ios/Runner.xcworkspace` in Xcode on macOS.
2. Set the production Bundle Identifier and Apple Developer Team.
3. Configure signing certificate and provisioning profile.
4. Confirm the `raamscrm` URL scheme is registered.
5. Add `raamscrm://login-callback/` to Supabase's allowed redirect URLs.
6. Build with production `APP_ENV`, API URL, Supabase URL, publishable key, and mobile redirect URL.
7. Test on a physical iPhone, including login callback, password recovery, PDF/file sharing, and workspace permissions.
8. Archive, validate, and upload through Xcode/Transporter.
9. Complete App Store privacy, metadata, and review requirements.

## 11. Optional email and WhatsApp deployment

Do not configure these until their provider accounts and compliance requirements are ready.

### Email

1. Provision and operate Postal or another approved SMTP service.
2. Configure DNS records and sender-domain authentication.
3. Add SMTP host/port at the API project environment level.
4. Configure per-workspace SMTP credentials in the authenticated app.
5. Send test messages and verify delivery, bounce handling, and logs.

### WhatsApp

1. Configure a Meta Business/WhatsApp application and phone number.
2. Set API-side `WHATSAPP_GRAPH_API_VERSION`, `WHATSAPP_APP_SECRET`, and `WHATSAPP_VERIFY_TOKEN`.
3. Register `https://raams-crm.vercel.app/api/webhooks/whatsapp` with Meta.
4. Configure the workspace phone-number ID and access token in the app.
5. Verify webhook signature handling, event delivery, and message sending.

Proposal PDF email attachments and WhatsApp document delivery must be separately verified before promising this capability to customers.

## 12. Release validation checklist

Complete this checklist for each production release:

- [ ] Neon production branch backup is current.
- [ ] Migrations were applied and verified on staging first.
- [ ] Supabase Production callback allowlist includes the production web and mobile redirects.
- [ ] Vercel API Production variables point only to production services.
- [ ] `npm.cmd run check:backend` passes.
- [ ] API deployment is `READY`.
- [ ] `/api/health` returns the expected environment.
- [ ] `/api/ready` returns database connected.
- [ ] Flutter web build uses the web app URL as `API_BASE_URL`.
- [ ] `npm.cmd run prepare:web-deploy` was run after the web build.
- [ ] Web deployment is `READY`.
- [ ] `/login-callback` returns the Flutter SPA, not an API response.
- [ ] `/api/health` and `/api/ready` through the web domain return JSON, not `index.html`.
- [ ] Web sign-up/sign-in/password recovery works.
- [ ] Workspace isolation and role permissions are verified.
- [ ] Android release is signed and tested if releasing Android.
- [ ] iOS release is signed and tested if releasing iOS.
- [ ] No server credentials are in the client bundle, repository, or release notes.

## 13. Rollback

### Vercel

1. Open the relevant Vercel project.
2. Go to Deployments.
3. Select the last known-good deployment.
4. Promote/assign it to Production using the dashboard.
5. Re-run health/readiness and web callback checks.

Do not delete the currently working deployment until the rollback is verified.

### Database

- Database migrations are forward-only; do not edit an applied migration.
- Use a Neon backup/branch restore if a migration corrupts data.
- For a schema correction, create and review a new forward migration.
- Restore to a new branch first when possible, verify application compatibility, then switch the production database URL deliberately.

## 14. Troubleshooting

### “Could not reach /api/health”

1. Open `https://raams-crm.vercel.app/api/health` and inspect the response.
2. Open `https://raams-crm-web.vercel.app/api/health`.
3. If the API URL works but web-domain URL does not, rebuild the web app and run `npm.cmd run prepare:web-deploy` before deploying `build/web`.
4. Confirm `vercel.web.json` proxies `/api/(.*)` before filesystem and SPA fallback routes.
5. Confirm the production web build uses `API_BASE_URL=https://raams-crm-web.vercel.app`.
6. Hard-refresh the browser and inspect Network requests.

### Health works but readiness fails

1. Verify the API Vercel Production `DATABASE_URL`.
2. Confirm the Neon database is active and the URL is for the correct environment.
3. Verify outbound database access and SSL configuration.
4. Inspect Vercel function logs using the request ID.
5. Do not deploy the web build until `/api/ready` succeeds.

### Sign-in redirect fails

1. Check the Supabase Auth allowed redirect list for an exact match.
2. Check the Flutter build's `AUTH_REDIRECT_URL`.
3. For web, use `https://raams-crm-web.vercel.app/login-callback`.
4. For Android/iOS, use `raamscrm://login-callback/`.

### Vercel deployment is protected

Public API and web deployments must not require a Vercel login page. Remove Vercel deployment protection for customer-facing Production deployments; keep authentication in Supabase/API authorization. Never disable application-level authentication.

## 15. Current deployment reference

The last verified production URLs are:

- Web: `https://raams-crm-web.vercel.app`
- API: `https://raams-crm.vercel.app`
- Same-origin health: `https://raams-crm-web.vercel.app/api/health`
- Same-origin readiness: `https://raams-crm-web.vercel.app/api/ready`
- Supabase: `https://gnsaejlsgqtowutfkpte.supabase.co`

If changing any project URL, update the Vercel rewrite in `vercel.web.json`, Flutter build values, Supabase callback allowlist, and this runbook; then rebuild, copy the web Vercel config, deploy, and re-run all release checks.

## 16. Quick deployment commands (plain-language version)

This is the short, step-by-step command list for a normal release. It assumes
you are using Windows PowerShell, are signed in to Vercel, and have already
configured the Vercel API environment variables and Supabase redirect URLs as
described above. Run the commands from the repository folder. Replace the
quoted `<...>` placeholders with the correct values before running a block;
never paste a database URL or server secret into a Flutter command.

If this is the first deployment from this computer, sign in and link the
repository to the API Vercel project once:

```powershell
npx.cmd --yes vercel login
npx.cmd --yes vercel link
```

When asked, select the Vercel account/team and the `raams-crm` API project.
Do not link the repository to the `raams-crm-web` project; the web deployment
command below names that project explicitly.

### A. Open the project and check it

These commands enter the project folder, download the packages it needs, and
run the backend checks:

```powershell
cd C:\Users\HP\AndroidStudioProjects\Raams_CRM
npm ci
npm.cmd run check:backend
```

Stop if a command reports an error. Fix the issue before deploying.

### B. Update the production database, only when there are new migrations

First make sure the migration was tested on staging and that a current
production backup exists. Then set the production database URL in this
temporary PowerShell window and run the migration:

```powershell
$env:APP_ENV = 'production'
$env:CONFIRM_DATABASE_MIGRATION = 'production'
$env:DATABASE_URL = '<production Neon pooled connection URL>'
npm.cmd run db:migrate
```

If the migration succeeds, clear the temporary URL and confirmation values:

```powershell
Remove-Item Env:\DATABASE_URL
Remove-Item Env:\CONFIRM_DATABASE_MIGRATION
Remove-Item Env:\APP_ENV
```

Do not run this step for every release; run it only when the database schema
has a new migration to apply.

### C. Send the API to Vercel

The API is the server-side part of the app. It uses the secret settings already
saved in the Vercel `raams-crm` project's Production environment:

```powershell
npx.cmd --yes vercel deploy --prod --yes
```

Wait for Vercel to report that the deployment is ready, then check that the
API and database are responding:

```powershell
curl.exe -i https://raams-crm.vercel.app/api/health
curl.exe -i https://raams-crm.vercel.app/api/ready
```

Continue only if both return HTTP 200 and readiness says the database is
connected.

### D. Build the website and send it to Vercel

The Supabase URL and publishable key below are public client settings. Find
them in the Supabase project settings and replace the example values. Do not
put a service-role key or database URL here.

```powershell
$supabaseUrl = '<production Supabase project URL>'
$supabasePublishableKey = '<production Supabase publishable key>'
C:\flutter\bin\flutter.bat pub get
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat build web --release `
  --dart-define=APP_ENV=production `
  --dart-define=API_BASE_URL=https://raams-crm-web.vercel.app `
  --dart-define=SUPABASE_URL=$supabaseUrl `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=$supabasePublishableKey `
  --dart-define=AUTH_REDIRECT_URL=https://raams-crm-web.vercel.app/login-callback
npm.cmd run prepare:web-deploy
npx.cmd --yes vercel deploy build/web --prod --yes --project raams-crm-web
```

The `prepare:web-deploy` command adds the routing file that lets the website
reach the API. Do not skip it. Once Vercel says the web deployment is ready,
check the website and its API connection:

```powershell
curl.exe -I https://raams-crm-web.vercel.app
curl.exe -i https://raams-crm-web.vercel.app/api/health
curl.exe -i https://raams-crm-web.vercel.app/api/ready
```

### E. Build a mobile release when needed

For Android, first set up the release signing values described in Section 9,
then run this from the project folder. Replace the two Supabase placeholders
with the production public values:

```powershell
$supabaseUrl = '<production Supabase project URL>'
$supabasePublishableKey = '<production Supabase publishable key>'
C:\flutter\bin\flutter.bat pub get
C:\flutter\bin\flutter.bat build appbundle --release `
  --dart-define=APP_ENV=production `
  --dart-define=API_BASE_URL=https://raams-crm-web.vercel.app `
  --dart-define=SUPABASE_URL=$supabaseUrl `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=$supabasePublishableKey `
  --dart-define=AUTH_REDIRECT_URL=raamscrm://login-callback/
```

Upload the resulting signed Android App Bundle to the Play Console internal
testing track first. Set the Android signing environment variables from
Section 9 in the same PowerShell window before building.

For iOS, use a Mac with Xcode and Flutter installed. After completing the
signing setup in Section 10, run these commands from the repository folder in
Terminal. Replace the two Supabase placeholders with the production public
values:

```sh
flutter pub get
flutter analyze
flutter build ipa --release \
  --dart-define=APP_ENV=production \
  --dart-define=API_BASE_URL=https://raams-crm-web.vercel.app \
  --dart-define=SUPABASE_URL='<production Supabase project URL>' \
  --dart-define=SUPABASE_PUBLISHABLE_KEY='<production Supabase publishable key>' \
  --dart-define=AUTH_REDIRECT_URL=raamscrm://login-callback/
```

Upload the resulting IPA to App Store Connect with Transporter or Xcode.

### F. What to do if a command fails

Do not continue to the next deployment step after an error. Read the error,
check the matching troubleshooting section above, fix the problem, and rerun
the failed check. After deployment, sign in and test the important app flows
before announcing the release. Never paste passwords, private keys, or full
connection strings into a support message or source file.
