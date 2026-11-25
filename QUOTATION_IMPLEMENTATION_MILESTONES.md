# Interior Quotation Module - Implementation Milestones

**Status:** Design approved for implementation planning
**Backend:** Vercel Node.js API + Neon/PostgreSQL
**Client:** Flutter web, Android, and iOS
**PDF generation:** PDFKit server-side, MIT-licensed

This plan extends the existing workspace and finance modules. No implementation work is included until each milestone is approved and started.

## Target Architecture

- Flutter only collects and displays quotation data.
- The Vercel API performs validation, recalculation, revision management, authorization, and document numbering.
- PostgreSQL stores normalized catalog data and immutable revision snapshots.
- PDFKit renders a premium A4 proposal from a server-side template.
- Private Supabase Storage holds generated PDF artifacts.
- Public Flutter builds contain no database or service-role credentials.

---

## Milestone 1 - Database and Catalog Foundation

### Objective

Create the normalized PostgreSQL foundation for rooms, components, packages, hardware, materials, pricing, terms, and proposal templates.

### Deliverables

- Versioned migration for all quotation-catalog tables.
- Workspace-level row-level security for every table.
- Basic, Medium, and Luxury seed-package structure.
- Room and component seed catalogs.
- Hardware, brand, SKU, finish, material, and UOM catalogs.
- Package inclusion and exclusion records.
- Template for package specifications and proposal terms.
- API validation and versioned catalog reads/writes.
- Migration and RLS tests.

### Key Tables

- `quotation_packages`
- `quotation_package_inclusions`
- `catalog_rooms`
- `catalog_components`
- `catalog_services`
- `catalog_materials`
- `catalog_finishes`
- `catalog_hardware`
- `pricing_rules`
- `proposal_templates`
- `proposal_terms_templates`
- `proposal_payment_schedules`

### Acceptance Criteria

- A workspace can create, update, activate, and deactivate catalog records.
- Packages can contain independent hardware and material inclusions.
- Package and catalog updates create version history rather than silently changing approved quotations.
- Unauthorized workspaces cannot read or mutate catalog records.
- Every migration is reversible or has an explicit safe-forward procedure.

---

## Milestone 2 - Server-Side Calculation Engine

### Objective

Implement a complete and auditable quotation calculation service.

### Deliverables

- Pricing-rule engine for fixed, unit, point, lumpsum, area, running-length, and volume prices.
- Millimeter-to-square-foot and millimeter-to-running-foot conversion.
- Quantity, wastage, markup, minimum quantity, and rounding support.
- Package, finish, and hardware calculation rules.
- Room, section, BOQ, discount, tax, and grand-total calculation.
- Amount-in-words generation.
- Calculation snapshot/audit table.
- Currency and GST-ready totals.
- Unit tests for all pricing models and rounding boundaries.

### Pricing Snapshot

Each calculated line must retain:

- Package and catalog version.
- Pricing-rule version.
- Length, height, width/depth, and quantity.
- Converted billable quantity.
- Unit rate and base amount.
- Finish/package multipliers or overrides.
- Hardware selections and snapshot prices.
- Wastage or markup.
- Discount allocation.
- Tax treatment.
- Final amount.
- Calculator version.

### Acceptance Criteria

- A 5362 mm × 900 mm area is converted and rounded exactly according to the configured rule.
- One unit, point, square-foot, running-foot, volume, and lumpsum calculation is verified.
- Floating-point currency values cannot affect the final two-decimal result.
- Flutter cannot override trusted totals.
- Any catalog or package change produces a traceable recalculation.
- Rounding, discounts, and taxes match in API and PDF output.

---

## Milestone 3 - Quotation Core API

### Objective

Build workspace quotation revisions and immutable commercial records.

### Deliverables

- Create quotation and revision endpoints.
- Atomic quotation and proposal numbering.
- Room and service BOQ hierarchy.
- Component, accessory, and hardware line records.
- Draft, pending approval, approved, rejected, and revision states.
- Optimistic concurrency and duplicate-save protection.
- Revision history and snapshot restoration.
- Approval/rejection and role authorization.
- Existing finance-document conversion support.
- API tests for numbering, revisions, concurrency, and permissions.

### Key Tables

- `quotation_documents`
- `quotation_revisions`
- `quotation_sections`
- `quotation_lines`
- `quotation_line_dimensions`
- `quotation_line_hardware`
- `quotation_discounts`
- `quotation_calculation_audit`

### Acceptance Criteria

- Two simultaneous document creations cannot reuse a number.
- Editing an approved revision creates a new revision.
- An approved snapshot cannot be silently mutated.
- Submitted records require server-calculated totals.
- Every approval/rejection/revision action is audited.
- Workspace, role, and document permissions are enforced.

---

## Milestone 4 - Quotation Builder for Web

### Objective

Create the primary premium desktop quotation-building experience.

### Deliverables

- Quotation list and search.
- Customer/project/enquiry metadata.
- Left-side room/service navigation.
- BOQ section editor.
- Component selection and dimension entry.
- Length, height, and optional depth/width fields.
- Basic/Medium/Luxury package selector.
- Material, finish, brand, SKU, and hardware selector.
- Live server-calculated amount preview.
- Room and section summaries.
- Discount, tax, terms, exclusions, and payment-schedule controls.
- Review mode and PDF preview.
- Responsive web layout for wide, compact, and tablet screens.

### Acceptance Criteria

- Users can build a room-wise BOQ without spreadsheet-like manual work.
- Package and hardware selections show their cost impact before saving.
- Length and height changes recalculate within the UI and match the API.
- Invalid dimensions and incompatible selections are blocked.
- Unsaved changes are protected from accidental navigation.
- All actions work within current role permissions.

---

## Milestone 5 - Mobile Quotation Experience

### Objective

Provide editing and approval usability on Android and iOS.

### Deliverables

- Mobile quotation list.
- Expandable room cards.
- Expandable component cards.
- Numeric mobile keypads for dimensions and quantities.
- Package and hardware bottom-sheet selectors.
- Searchable catalogs.
- Mobile discount and terms review.
- Approval/rejection actions.
- PDF preview, download, share, and print where supported.

### Acceptance Criteria

- The same revision and calculation API is used for mobile and web.
- Android and iOS do not duplicate commercial calculation logic.
- Dimension entry and catalog selection remain usable on small screens.
- PDF preview and sharing work on both native platforms.
- Role restrictions match the web experience.

---

## Milestone 6 - Premium Proposal PDF

### Objective

Produce a premium branded A4 proposal matching the visual quality of a design studio document.

### Deliverables

- PDFKit server dependency and reusable rendering service.
- Premium cover page.
- Workspace logo and branded palette.
- Customer, enquiry, site, date, validity, and staff metadata.
- Subject and excluded-items section.
- Room-wise woodwork BOQ tables.
- Component descriptions, variants, and millimeter dimensions.
- Accessory tables with brand, SKU/model, quantity, and amount.
- False-ceiling and other-service tables with UOM and quantity.
- Room summary and total.
- Discount, grand total, tax, and amount in words.
- Material/specification pages.
- Terms, assumptions, payment milestones, warranty, and site-readiness pages.
- Repeatable headers, footers, page numbers, and page-break handling.
- Customer signature and date blocks.
- Revision date, document number, and confidentiality marking.
- Private PDF artifact generation and short-lived download URLs.

### Premium Design Requirements

- A4 portrait or section-specific A4 landscape tables.
- Consistent color, typography, spacing, icon-free clean hierarchy, and high-contrast tables.
- Elegant cover, understated accent lines, and a professional brand footer.
- No raw JSON, internal costs, internal margins, or implementation IDs.
- Strong table pagination without splitting a line unexpectedly.
- Empty and long-text states must remain readable.
- Preserve customer-facing text safely, including escaping and multi-language content.

### Acceptance Criteria

- The generated PDF visually matches the approved template and is usable without manual cleanup.
- PDF totals equal the server-calculated revision totals.
- Long room/component lists continue across pages correctly.
- The approved revision receives a single revision-specific PDF artifact.
- PDF access uses workspace authorization and short-lived signed URLs.
- Web, Android, and iOS download the same PDF artifact.

---

## Milestone 7 - Proposal Communication

### Objective

Connect approved proposals to the existing email and WhatsApp infrastructure.

### Deliverables

- Email proposal PDF with template text.
- Optional WhatsApp proposal link or provider-supported document action.
- Customer delivery status in quotation history.
- Delivery attempt/audit records.
- Existing workspace sender configuration integration.
- Re-send and de-duplicate controls.

### Acceptance Criteria

- PDF delivery uses server-side credentials only.
- The recipient and revision are recorded.
- Failed deliveries are visible and retryable.
- Only authorized users can send.
- Sharing never exposes a public permanent URL.

---

## Milestone 8 - Finance, Invoice, and Reporting Integration

### Objective

Complete the commercial workflow after approval.

### Deliverables

- Convert an approved proposal to an invoice.
- Approved proposal and invoice relationship.
- Protected invoice fields after posting.
- Payment milestone display and payment recording.
- Quotation conversion and acceptance reports.
- Package/hardware sales summaries.
- Discount and approval reports.
- PDF and CSV export.
- Existing finance dashboard integration.

### Acceptance Criteria

- Only approved proposals can be converted.
- An invoice cannot be created twice from the same revision unless explicitly versioned.
- Invoice totals remain consistent with the approved proposal.
- Reporting totals reconcile with quotation revisions and recorded payments.
- Invoice and proposal audit history remain linked.

---

## Milestone 9 - Quality, Security, and Performance

### Objective

Make the module production-ready across web and native platforms.

### Deliverables

- API unit and integration tests.
- Dart widget and repository tests.
- Calculation property tests.
- PDF golden-page tests for short, normal, and 20+ page proposals.
- Concurrent edit/document-number tests.
- Workspace isolation and RLS tests.
- Permission tests.
- Input fuzzing and malformed payload tests.
- Web, Android, and iOS build verification.
- PDF memory and artifact cleanup checks.
- Observability for calculation and PDF failures.
- Retry-safe PDF jobs and storage cleanup.

### Acceptance Criteria

- Database, API, and client test suites pass.
- There are no known P0/P1 defects.
- Workspace isolation is verified.
- Concurrent edits and numbering have no duplicate state.
- PDF rendering completes within the agreed production timeout.
- Failure responses are actionable and never expose secrets.
- Flutter web and native release builds start correctly.

---

## Milestone 10 - Production Configuration and Launch

### Objective

Complete deployment operations and release readiness.

### Deliverables

- Neon migration runbook.
- Staging and production catalog configuration.
- PDF storage bucket and private retention configuration.
- Workspace logo and brand asset setup.
- Standard GST/tax configuration.
- Default package, room, component, and hardware content.
- Terms and payment-schedule templates.
- Vercel environment and rate-limit configuration.
- Android release signing and iOS signing/Xcode configuration.
- Web domain and authentication redirect configuration.
- Backup and restore validation.
- Rollback procedure.
- Launch smoke-test checklist.

### Acceptance Criteria

- Staging and production use separate databases and credentials.
- PDFs are private and downloadable only by authorized workspace members.
- Signed release builds pass store/release requirements.
- Database rollback/migration recovery is documented.
- A complete sample quotation can be created, approved, emailed/shared, and converted to an invoice.
- No privileged secrets exist in Flutter build defines or source control.

---

## Recommended Implementation Sequence

1. Milestone 1 - Database and catalog foundation.
2. Milestone 2 - Server-side calculation engine.
3. Milestone 3 - Quotation core API.
4. Milestone 4 - Web quotation builder.
5. Milestone 5 - Mobile quotation experience.
6. Milestone 6 - Premium PDF.
7. Milestone 7 - Proposal communication.
8. Milestone 8 - Finance integration.
9. Milestone 9 - Quality and security.
10. Milestone 10 - Production configuration and launch.

Milestones 4 and 5 may share client domain/repository code, but commercial pricing remains server-side.
