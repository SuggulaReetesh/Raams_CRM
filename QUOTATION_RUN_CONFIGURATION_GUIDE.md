# How to Configure and Run the Quotation Project

**Current local setup status**

- Neon migrations `0001` through `0018` have been applied and `/api/ready` reports the Neon database as connected.
- Vercel API project: `https://raams-crm.vercel.app`
- Public Flutter web project: `https://raams-crm-web.vercel.app`
- Supabase project URL and publishable key are configured in the production web build.
- Development and production server variables have been configured in Vercel.
- The public API health endpoint reports `status: ok, environment: production`.
- The public web app and `/login-callback` route both return HTTP 200.
- Database, Supabase service-role, and integration encryption values are kept out of Flutter builds.
- Neon migrations `0001` through `0018` have been applied to the development database.
- `.env.local` contains the local Neon and public Supabase development values and is ignored by Git.
- The Flutter web app is running in Chrome with the provided public Supabase values.
- A database password was shared in the conversation and must be rotated in Neon before production use.

This guide is written for someone who can use the project but does not need to understand the internal code.

## What is Already Implemented

The backend foundation is implemented:

- Quotation package catalog tables.
- Rooms, components, services, materials, finishes, and hardware tables.
- Quotation revision and calculation-audit tables.
- Server-side calculation for area, running length, volume, unit, point, fixed, and lumpsum pricing.
- Quotation, revision, submit, approve, and reject API endpoints.
- Basic package and length/height fields in the existing Flutter quotation editor.
- PDFKit server package and a basic PDF generation endpoint.
- Unit tests for calculator, catalog, revisions, and PDF generation.

The backend test suite currently passes 60 tests.

The Flutter quotation files also pass static analysis. The complete Flutter test command could not run because this Windows computer does not currently have a working Visual Studio C/C++ native build toolchain.

## What Still Needs Configuration or Completion

Before production use, complete these items:

1. Apply migrations 0017 and 0018 to a real Neon database.
2. Connect Supabase Auth and obtain a publishable key.
3. Create a Vercel deployment and configure the API environment variables.
4. Configure the Flutter API and Supabase values.
5. Add catalog seed data such as Basic, Medium, Luxury, rooms, components, hardware, and pricing rules.
6. Fully connect Flutter screens to the quotation APIs.
7. Complete the premium PDF layouts and private PDF storage.
8. Add proposal PDF email/WhatsApp delivery.
9. Link approved quotation revisions to invoices and reports.
10. Configure Android signing and iOS signing.
11. Run real web, Android, and iOS testing.

Do not treat the project as production-ready until the database, authentication, PDFs, and native builds have been verified live.

## Step 1 - Create Accounts and Projects

You need accounts in:

- Vercel for the Node.js API.
- Neon for PostgreSQL.
- Supabase for authentication and private file storage.
- Optional: Postal SMTP for email.
- Optional: Meta WhatsApp Business for WhatsApp delivery.

Keep the provider credentials secure. They must never be placed inside Flutter source code or Flutter `--dart-define` values.

## Step 2 - Create a Neon PostgreSQL Database

1. Sign in to Neon.
2. Create a project.
3. Create separate database branches or databases for development, staging, and production.
4. Copy the development PostgreSQL connection string.
5. The connection string must start with `postgres://` or `postgresql://`.

Never use the same database for development and production.

## Step 3 - Create a Supabase Project

1. Create a Supabase project.
2. Open Project Settings.
3. Open Authentication.
4. Configure email/password sign-in.
5. Add the web login callback URL.
6. Copy the project URL.
7. Create or copy the public publishable key.
8. Copy the project JWKS information; the API validates Supabase tokens through the configured URL.

For web, an example callback is:

```text
https://your-staging-domain.example/login-callback
```

For Android and iOS, use:

```text
raamscrm://login-callback/
```

Add this exact callback URL to Supabase Auth redirect settings.

## Step 4 - Create a Local API Environment File

In the project root, create `.env.local`.

Use this structure:

```text
APP_ENV=development
DATABASE_URL=postgresql://...
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-server-only-service-role-key
SUPABASE_INVITE_REDIRECT_URL=raamscrm://login-callback/
INTEGRATION_ENCRYPTION_KEY=generated-base64-32-byte-key
POSTAL_SMTP_HOST=
POSTAL_SMTP_PORT=587
WHATSAPP_GRAPH_API_VERSION=
WHATSAPP_APP_SECRET=
WHATSAPP_VERIFY_TOKEN=
```

Generate the integration encryption key in PowerShell:

```powershell
openssl rand -base64 32
```

Store this key securely. If it is lost or changed, previously stored integration credentials cannot be decrypted.

Do not commit `.env.local` or share it.

## Step 5 - Install the Backend

Open PowerShell in the project root:

```powershell
cd C:\Users\HP\AndroidStudioProjects\Raams_CRM
npm ci
npm.cmd run check:backend
```

If `npm.cmd run check:backend` passes, the backend syntax and test suite are healthy.

## Step 6 - Apply Database Migrations

Confirm the local migration runner is connected to Neon:

```powershell
npm.cmd run db:migrate
```

The runner applies migrations sequentially and records each migration in `schema_migrations`.

For staging or production, set:

```text
APP_ENV=staging
CONFIRM_DATABASE_MIGRATION=staging
DATABASE_URL=the-staging-Neon-url
```

Or:

```text
APP_ENV=production
CONFIRM_DATABASE_MIGRATION=production
DATABASE_URL=the-production-Neon-url
```

The production migration command must be used only after the migration has been reviewed on development and staging.

Verify these are recorded:

- `0017_quotation_catalog_foundation.sql`
- `0018_quotation_revision_foundation.sql`

## Step 7 - Configure the API on Vercel

Import the repository into Vercel.

Set server environment variables separately for Preview and Production:

```text
APP_ENV=staging
DATABASE_URL=Neon staging URL
SUPABASE_URL=Supabase project URL
SUPABASE_SERVICE_ROLE_KEY=server-only key
SUPABASE_INVITE_REDIRECT_URL=web callback or mobile callback
INTEGRATION_ENCRYPTION_KEY=base64 32-byte key
POSTAL_SMTP_HOST=Postal SMTP host
POSTAL_SMTP_PORT=587
WHATSAPP_GRAPH_API_VERSION=v24.0
WHATSAPP_APP_SECRET=Meta app secret
WHATSAPP_VERIFY_TOKEN=private random verify token
```

Never enter service-role credentials into a Flutter build.

Deploy and verify:

- `https://your-api.example/api/health`
- `https://your-api.example/api/ready`

The ready endpoint should confirm PostgreSQL is connected.

## Step 8 - Configure the Flutter App

For local web development:

```powershell
C:\flutter\bin\flutter.bat run -d chrome `
  --dart-define=APP_ENV=development `
  --dart-define=API_BASE_URL=http://localhost:3000 `
  --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-public-publishable-key `
  --dart-define=AUTH_REDIRECT_URL=http://localhost:3000/login-callback
```

For staging web:

```powershell
C:\flutter\bin\flutter.bat run -d chrome `
  --dart-define=APP_ENV=staging `
  --dart-define=API_BASE_URL=https://your-staging-api.example `
  --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-public-publishable-key `
  --dart-define=AUTH_REDIRECT_URL=https://your-staging-domain.example/login-callback
```

For Android and iOS, use the mobile callback:

```text
AUTH_REDIRECT_URL=raamscrm://login-callback/
```

The publishable Supabase key is public and safe to include in the app. It is not authorization by itself.

## Step 9 - Add Initial Catalog Data

Before creating quotation lines, the database needs configuration data:

1. Basic package.
2. Medium package.
3. Luxury package.
4. Rooms such as Kitchen, Living Room, Bedrooms, Pooja Room, and Dining.
5. Components such as Base Unit, Wall Unit, Loft Unit, Wardrobe, and Study Unit.
6. Services such as False Ceiling, Electrical, Painting, Transport, and Cleaning.
7. Hardware brands and models.
8. One or more pricing rules.
9. Terms and proposal template records.

Use `/api/quotation-catalog` only through an authorized workspace session. The API requires:

- `X-Workspace-Id`.
- A valid Supabase access token.
- `manageFinancials` permission for writes.

The initial package and catalog UI is not yet fully wired to the API. API catalog records must be created before the complete builder can use live server rates.

## Step 10 - Test the Backend APIs

1. Sign in and obtain a Supabase JWT.
2. Create or select a workspace.
3. Pass `X-Workspace-Id`.
4. Read `/api/quotation-catalog`.
5. Save a package through `PUT /api/quotation-catalog`.
6. Call `POST /api/quotation?action=calculate` with a valid pricing-rule ID.
7. Create a quotation through `POST /api/quotation`.
8. Submit, approve, or reject it using the action and document ID parameters.
9. Call `/api/quotation-pdf` to download the PDF.

Example calculate request shape:

```json
{
  "title": "Kitchen and Wardrobe Proposal",
  "currencySymbol": "₹",
  "taxRate": 18,
  "discountPercent": 10,
  "validityDate": "2026-12-31",
  "sections": [
    {
      "type": "room",
      "name": "Modular Kitchen",
      "roomId": "kitchen",
      "lines": [
        {
          "description": "Kitchen Base Unit",
          "quantity": 1,
          "lengthMm": 5362,
          "heightMm": 900,
          "pricingRuleId": "woodwork-area",
          "packageId": "medium",
          "hardware": []
        }
      ]
    }
  ]
}
```

Do not expect uncreated IDs such as `kitchen` or `woodwork-area` to work. They must exist in your workspace catalog database.

## Step 11 - Verify PDF Output

Until private PDF storage is complete, the PDF endpoint returns the PDF directly.

Verify:

- The `%PDF` file signature.
- Document number and revision number.
- Room names and line descriptions.
- Dimensions in millimeters.
- Package and hardware details.
- Subtotal, discount, tax, and grand total.
- Amount in words.
- Page headers and no broken text.

The PDF is server-generated, so web, Android, and iOS receive the same revision.

## Step 12 - Configure Email

To enable email:

1. Install/configure the Postal SMTP server or use an approved SMTP provider.
2. Set `POSTAL_SMTP_HOST`.
3. Set `POSTAL_SMTP_PORT`.
4. In the app integration settings, enter the workspace SMTP username/password and sender identity.
5. Test one email inside the CRM.
6. Add PDF attachment support before customer proposal delivery.

The SMTP credentials are encrypted and must stay on the server.

## Step 13 - Configure WhatsApp

To enable WhatsApp:

1. Create or use a Meta WhatsApp Business setup.
2. Set `WHATSAPP_GRAPH_API_VERSION`.
3. Set `WHATSAPP_APP_SECRET`.
4. Set `WHATSAPP_VERIFY_TOKEN`.
5. Register the API webhook URL in Meta.
6. Enter the workspace phone-number ID and access token in the app integration settings.
7. Send and verify one test message.

For sending a PDF, it must be stored privately and provided as an authorized or provider-supported document action; do not make the PDF publicly accessible.

## Step 14 - Android Configuration

Configure:

```text
APP_ANDROID_APPLICATION_ID
ANDROID_KEYSTORE_PATH
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_ALIAS
ANDROID_KEY_PASSWORD
```

The release build must use these values. Never commit the keystore or passwords.

Build:

```powershell
C:\flutter\bin\flutter.bat build apk --release `
  --dart-define=APP_ENV=production `
  --dart-define=API_BASE_URL=https://your-production-api.example `
  --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-public-publishable-key `
  --dart-define=AUTH_REDIRECT_URL=raamscrm://login-callback/
```

Test on a real Android device with:

- Login.
- Workspace selection.
- Quotation editing.
- Dimension entry.
- Approval actions.
- PDF preview/share.

## Step 15 - iOS Configuration

iOS signing requires macOS and Xcode.

Configure:

- Bundle ID.
- Apple Team.
- Signing certificate.
- Provisioning profile.
- Registered `raamscrm://login-callback/` redirect.
- Camera/photo/document permissions only if required.
- App privacy and store metadata.

Build:

```text
flutter build ipa
```

Test on a real iPhone with login, quotation editing, approval, PDF preview, and file sharing.

## Step 16 - Web Configuration

Use HTTPS for staging and production.

Configure:

- Production domain.
- Vercel custom domain.
- HTTPS certificate.
- Supabase redirect allowlist.
- API CORS/allowed origin settings.
- Browser storage and authentication behavior.
- Production web build:

```powershell
C:\flutter\bin\flutter.bat build web --release `
  --dart-define=APP_ENV=production `
  --dart-define=API_BASE_URL=https://your-production-api.example `
  --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-public-publishable-key `
  --dart-define=AUTH_REDIRECT_URL=https://your-domain.example/login-callback
```

## Step 17 - Before Launch

Run the following checks:

```powershell
npm.cmd run check:backend
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat pub get
```

On a machine with the Visual Studio C++ toolchain repaired, also run:

```powershell
C:\flutter\bin\flutter.bat test
```

Then verify manually:

1. Register and sign in.
2. Create a workspace.
3. Select the workspace.
4. Create a Basic, Medium, and Luxury package.
5. Create rooms and components.
6. Add hardware and pricing rules.
7. Enter length and height.
8. Confirm the server total.
9. Save a quotation.
10. Create a revision.
11. Submit and approve.
12. Generate a PDF.
13. Review every PDF page.
14. Email or WhatsApp the PDF.
15. Convert the approved proposal to an invoice.
16. Record a payment.
17. Test access denial from another workspace.
18. Test concurrent document edits.
19. Test web, Android, and iOS builds.

## Required Values Checklist

Ask the project owner or platform administrator for:

- Neon development, staging, and production database URLs.
- Supabase project URL and publishable key.
- Supabase service-role key.
- Supabase invite callback URL.
- Vercel project and custom domain.
- Integration encryption key.
- Postal SMTP host and credentials.
- WhatsApp phone-number ID and access token.
- WhatsApp app secret and verify token.
- Android application ID and keystore values.
- iOS team, bundle ID, certificate, and provisioning profile.
- GST/tax rules.
- Package definitions.
- Room/component catalog.
- Hardware brands and prices.
- Discount approval limits.
- Standard payment schedule.
- Standard terms, warranty, and exclusion text.
- Company logo and brand colors.
