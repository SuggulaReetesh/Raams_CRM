# Raams CRM Deployment Runbook

This is a fresh, step-by-step guide for manually releasing Raams CRM. It is
written for someone who is not a deployment engineer. The old
`MANUAL_DEPLOYMENT_GUIDE.md` is left unchanged; use this runbook for the
deployment steps below.

## 1. What is being deployed

The app has three hosted parts:

| Part | Service | Production address |
|---|---|---|
| Website | Vercel project `raams-crm-web` | `https://raams-crm-web.vercel.app` |
| API (the server) | Vercel project `raams-crm` | `https://raams-crm.vercel.app` |
| Database | Neon PostgreSQL | Private connection; do not put its URL in the app |
| Sign-in and private file storage | Supabase | Use the project URL and publishable key in the app |

The browser uses the web address for API calls. The web Vercel project forwards
`/api/...` requests to the API project. This is intentional; do not change the
web app's `API_BASE_URL` to the separate API host.

## 2. Important security steps

Credentials for Neon and Supabase were previously shared during setup. Before
using this deployment for real customer data:

1. Change the Neon database password.
2. Replace the Supabase service-role key.
3. Update the new values in the Vercel API project's Production environment.
4. Update the ignored local `.env.local` only if you use the local API.
5. Redeploy the API after changing its Production variables.

Never put database URLs, Supabase service-role keys, SMTP passwords, WhatsApp
tokens, or encryption keys in Flutter build commands, this document, or Git.
Only the Supabase project URL and publishable key belong in Flutter builds.

## 3. One-time setup

### On the Windows deployment computer

Install:

- Node.js 22 or newer and npm.
- Flutter stable SDK. The commands in this guide expect it at `C:\flutter`.
- Git.
- Android Studio and Android SDK if building Android.
- Vercel CLI access (the commands below run it using `npx`).

Check the tools:

```powershell
node --version
npm.cmd --version
C:\flutter\bin\flutter.bat --version
```

### In Supabase

For the correct production Supabase project:

1. Enable the sign-in methods the app will use.
2. Set the website URL to `https://raams-crm-web.vercel.app`.
3. Add these allowed sign-in redirects:
   - `https://raams-crm-web.vercel.app/login-callback`
   - `raamscrm://login-callback/`
4. In the Supabase SQL Editor, apply
   `supabase/migrations/20261117000100_private_project_files.sql` to the
   environment. Test on staging first, then apply it to production. It creates
   the private project-files bucket and its storage policies.
5. Confirm the private project-files bucket exists and is not public.
6. Keep the service-role key private. The Flutter app uses the publishable key.

If you use a custom domain later, add its exact callback URL and rebuild the
web app with the custom URL.

### In Vercel

The API and web app are two separate Vercel projects. Add these variables to
the **Production** environment of the `raams-crm` API project:

| Variable | Value |
|---|---|
| `APP_ENV` | `production` |
| `DATABASE_URL` | Production Neon pooled PostgreSQL URL |
| `SUPABASE_URL` | Production Supabase project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Production server-only key |
| `SUPABASE_INVITE_REDIRECT_URL` | `https://raams-crm-web.vercel.app/login-callback` |
| `INTEGRATION_ENCRYPTION_KEY` | Base64 encoding of 32 random bytes |

Set optional SMTP and WhatsApp values only if those integrations are enabled.
Use Vercel's encrypted environment-variable type for private values. Do not
put API server secrets in the `raams-crm-web` project.

Use separate Neon and Supabase projects/branches for development, staging,
and production. Avoid testing against production data.

## 4. Database migrations

Migrations update the database structure when the app adds or changes features.
They are not required for every app release.

Before a production migration:

1. Apply it to development first.
2. Test it on staging.
3. Make sure a current production backup exists.
4. Confirm the production Neon URL before running the production command.

The final section has the exact PowerShell commands. The migration runner
refuses production changes unless `APP_ENV` and
`CONFIRM_DATABASE_MIGRATION` are both set to `production`.

## 5. Deploy the API

The API is the server-side part. It connects to Neon and Supabase using the
private values saved in the Vercel `raams-crm` Production settings.

From the repository folder, run the API checks and deploy it using the
commands in Section 9. Wait for Vercel to report that the deployment is ready.
Then check:

- `https://raams-crm.vercel.app/api/health` should return HTTP 200.
- `https://raams-crm.vercel.app/api/ready` should return HTTP 200 and report
  that the database is connected.

Do not continue with a web release if the readiness check fails.

## 6. Deploy the website

Build the Flutter website with:

- `APP_ENV=production`
- `API_BASE_URL=https://raams-crm-web.vercel.app`
- The production Supabase URL and publishable key
- `AUTH_REDIRECT_URL=https://raams-crm-web.vercel.app/login-callback`

After building, run `npm.cmd run prepare:web-deploy`. This copies the Vercel
routing configuration into the generated website so `/api/...` requests reach
the API. Deploy the `build/web` folder to the separate Vercel project
`raams-crm-web`.

Check the website and its API connection:

- `https://raams-crm-web.vercel.app` should open the app.
- `https://raams-crm-web.vercel.app/api/health` should return health JSON.
- `https://raams-crm-web.vercel.app/api/ready` should report the database is
  connected.

## 7. Deploy Android

Android releases can be built on Windows. Before the release build:

1. Create a production Android application ID.
2. Create and safely back up a release keystore.
3. Set the five Android signing environment variables shown in Section 9.
4. Build the Android App Bundle (`.aab`).
5. Upload it to the Play Console internal testing track and test it before
   promoting it to production.

The keystore and its passwords must not be committed to the repository.

## 8. Deploy iOS

iOS signing and App Store submission require a Mac with Xcode. On the Mac:

1. Set the production Bundle Identifier and Apple Developer Team in Xcode.
2. Configure signing and confirm the `raamscrm` URL scheme is registered.
3. Build the signed IPA using the command in Section 9.
4. Test on a physical iPhone, especially sign-in and its redirect.
5. Upload the IPA to App Store Connect with Transporter or Xcode.

## 9. Copy/paste commands for a release

These commands are in release order. Run PowerShell commands from
`C:\Users\HP\AndroidStudioProjects\Raams_CRM`. Replace every quoted
`<placeholder>` with a real value before running that command. Do not paste
private secrets into Flutter commands.

### 9.1 Sign in and link Vercel (first time on this computer only)

```powershell
cd C:\Users\HP\AndroidStudioProjects\Raams_CRM
npx.cmd --yes vercel login
npx.cmd --yes vercel link
```

When asked, select the Vercel account/team and the **`raams-crm` API project**.
The website command below explicitly selects `raams-crm-web`.

### 9.2 Check the project before deploying

```powershell
npm ci
npm.cmd run check:backend
```

If either command reports an error, stop and fix it before deployment.

### 9.3 Run a production database migration only if there is a new migration

Use the production pooled Neon connection URL. Run this only after the
migration has been tested on staging and a production backup is available:

```powershell
$env:APP_ENV = 'production'
$env:CONFIRM_DATABASE_MIGRATION = 'production'
$env:DATABASE_URL = '<production Neon pooled connection URL>'
npm.cmd run db:migrate
```

After the command completes, clear the URL from this PowerShell window:

```powershell
Remove-Item Env:\DATABASE_URL
Remove-Item Env:\CONFIRM_DATABASE_MIGRATION
Remove-Item Env:\APP_ENV
```

### 9.4 Deploy the API and check it

Before running this, confirm the `raams-crm` Vercel Production environment
contains the API variables from Section 3:

```powershell
npx.cmd --yes vercel deploy --prod --yes
curl.exe -i https://raams-crm.vercel.app/api/health
curl.exe -i https://raams-crm.vercel.app/api/ready
```

Wait for the deployment to be ready. Both checks should return HTTP 200, and
readiness should say the database is connected.

### 9.5 Build and deploy the website

The two Supabase values below are public client settings. Do not substitute a
service-role key or a database URL.

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

Then verify the deployed website and its API proxy:

```powershell
curl.exe -I https://raams-crm-web.vercel.app
curl.exe -i https://raams-crm-web.vercel.app/api/health
curl.exe -i https://raams-crm-web.vercel.app/api/ready
```

### 9.6 Build Android when releasing the Android app

Set these values in the same PowerShell window. Use your real signing values;
do not save passwords in this document:

```powershell
$env:APP_ANDROID_APPLICATION_ID = '<production Android application ID>'
$env:ANDROID_KEYSTORE_PATH = '<absolute path to release keystore>'
$env:ANDROID_KEYSTORE_PASSWORD = '<keystore password>'
$env:ANDROID_KEY_ALIAS = '<key alias>'
$env:ANDROID_KEY_PASSWORD = '<key password>'
$supabaseUrl = '<production Supabase project URL>'
$supabasePublishableKey = '<production Supabase publishable key>'
```

Then build:

```powershell
C:\flutter\bin\flutter.bat pub get
C:\flutter\bin\flutter.bat build appbundle --release `
  --dart-define=APP_ENV=production `
  --dart-define=API_BASE_URL=https://raams-crm-web.vercel.app `
  --dart-define=SUPABASE_URL=$supabaseUrl `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=$supabasePublishableKey `
  --dart-define=AUTH_REDIRECT_URL=raamscrm://login-callback/
```

The `.aab` is normally written under
`build\app\outputs\bundle\release\`. Upload it to the Play Console internal
testing track first. Keep the signing environment variables in the current
PowerShell window only; close the window when finished.

### 9.7 Build iOS when releasing the iOS app

Run this on a Mac after Xcode signing has been configured. Replace the two
Supabase placeholders with public production values:

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

## 10. If something goes wrong

- **API health fails:** Check the API Vercel deployment and its function logs.
- **Readiness fails:** Check the production `DATABASE_URL` and Neon status.
- **Website works, but API health fails on the website domain:** Rebuild the
  website, run `npm.cmd run prepare:web-deploy`, and deploy the web project
  again.
- **Sign-in redirect fails:** Check the exact callback URLs in Supabase and
  rebuild with the matching `AUTH_REDIRECT_URL`.
- **A command fails:** Stop there. Do not continue to the next release step.
- **A new deployment is broken:** In Vercel, promote the last known-good
  deployment back to Production, then recheck health and readiness.

After every release, sign in and test the important app flows before
announcing it. Do not disable application authentication to work around a
deployment problem.
