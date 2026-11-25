# Interior Quotation and Proposal Module - Design Document

**Status:** Draft for sign-off
**Source of truth:** `Sravya Garu - ENQ-2026-062-003.pdf`
**Existing foundation:** PostgreSQL/Vercel backend, workspace-scoped finance tables, Flutter web/Android/iOS app

This document defines the implementation scope for configurable interior quotations. It does not implement the module until it is approved.

## 1. Objective

Create quotations for interior projects in a controlled, reusable, and auditable way.

The module must support:

- Hardware/package presets: Basic, Medium, and Luxury.
- Customer-specific package selection and package overrides.
- Multiple rooms and work components in one quotation.
- Length and height entry in millimeters for woodwork.
- Area, running-length, fixed-price, quantity, and lumpsum pricing models.
- Room-wise and service-wise bills of quantities (BOQ).
- Hardware, accessories, brands, finishes, and material specifications.
- Discounts, taxes, payment stages, terms, assumptions, revisions, and approvals.
- Branded proposal/PDF output on web, Android, and iOS.

## 2. Existing Project Integration

The current project already provides:

- Workspace-scoped quotation, proposal, invoice, template, and payment tables.
- PostgreSQL persistence through the Vercel API.
- Document numbering and financial settings.
- Proposal and quotation line items.
- Workspace roles and row-level isolation.
- HTML proposal and invoice generation.

The proposed module will extend this foundation. It should not create an unrelated database or duplicate the existing finance workflow.

## 3. Requirements From the Sample Proposal

The sample proposal contains:

- Enquiry and proposal metadata.
- Prepared-for/prepared-by information.
- Enquiry date, proposal date, validity date, site, project type, and assigned staff.
- Included and excluded scope.
- Room/service sections.
- Components with description, variant, dimensions, and amount.
- Accessories with brand, SKU/model, quantity, and amount.
- Other services with UOM, quantity, unit rate/amount.
- Room/service summaries.
- BOQ subtotal and discount.
- Grand total and amount in words.
- Material specifications and package inclusions.
- Terms, assumptions, payment stages, warranty, and site-readiness rules.
- A branded cover and footer.

Example services include false ceiling, electrical, painting, wooden ceiling, inspection, floor protection, transport, loading/unloading, and cleaning.

## 4. Recommended Domain Model

### 4.1 Hardware and Package Catalog

#### Package Template

Examples: Basic, Medium, Luxury.

Fields:

- Name and code.
- Description.
- Active status.
- Valid-from and valid-to dates.
- Currency.
- Default tax treatment.
- Default discount policy.
- Specification template.
- Included/excluded item rules.

Packages are presets, not immutable locked prices. A quoted package should snapshot its configuration and selected catalog prices at creation/revision time.

#### Package Inclusion

Each package may include or exclude:

- Carcass material and thickness.
- Shutter material and finish.
- Edge band.
- Hinges and lifting systems.
- Channels and drawers.
- Handles and locks.
- Legs and skirting.
- Gola or panel profiles.
- Brand selections.
- Included quantity or free limit.
- Additional-item pricing.

### 4.2 Catalog

Create reusable catalogs for:

- Room types.
- Component types.
- Service types.
- Materials.
- Finishes.
- Hardware brands.
- Hardware/accessory models.
- Brands and SKUs.
- UOMs.
- Specification templates.
- Terms templates.
- Payment schedules.

### 4.3 Quotation Header

Fields:

- Workspace, enquiry, project, customer, and site.
- Proposal number and revision number.
- Created date, validity date, and due date.
- Prepared by, handled by, and designed by.
- Project type.
- Subject.
- Included/excluded scope.
- Package template and override status.
- Currency and tax mode.
- Status.
- PDF/template selection.
- Discount and final totals.

### 4.4 BOQ Structure

Recommended hierarchy:

```text
Quotation
  Revision
    Section
      Room or service group
        Component/service line
          Dimension values
          Selected variant/material/finish
          Package
          Pricing rule
          Hardware selections
          Accessories
          Calculation snapshot
          Amount
        Room/subtotal
      Document subtotal
```

This hierarchy supports the room summary and separate woodwork/other-services layouts used in the sample.

## 5. Hardware Selection User Experience

The package tier should be selected first, then refined.

### Package Selection

1. Select Basic, Medium, or Luxury.
2. Review included materials and hardware.
3. Review base specifications.
4. Add optional hardware or replace included items.
5. Preview package impact on the selected component and quotation total.

Package changes must be explicit. The system must show added, removed, upgraded, downgraded, or overridden items.

### Component Selection

For a woodwork component:

1. Select room.
2. Select component, for example Kitchen Base Unit or Wardrobe.
3. Select package/variant.
4. Enter length and height in millimeters.
5. Enter quantity.
6. Select finish/material.
7. Select accessories and hardware.
8. Review calculated amount.
9. Save the line.

Width may be required where the configured calculation uses depth, volume, or a depth-sensitive rate.

## 6. Dimensional and Pricing Rules

The server must own all pricing calculations. The UI is only a preview.

### Supported Pricing Models

| Model | Required inputs | Example UOM |
|---|---|---|
| `DIMENSION_AREA` | Length, height, quantity | Sq. ft |
| `DIMENSION_RUNNING` | Length or height, quantity | Rft |
| `VOLUME` | Length, width, height, quantity | Cu. ft |
| `UNIT` | Quantity | No |
| `POINT` | Quantity | Point |
| `LUMP_SUM` | Quantity, usually 1 | Lumpsum |

### Calculation Formula

The active pricing rule should define:

- Source dimension(s).
- Input unit.
- Output UOM.
- Conversion factor.
- Base rate.
- Minimum billable quantity.
- Rounding rule.
- Optional wastage percentage.
- Optional quantity or area threshold.

Example for millimeter dimensions and square feet:

```text
billableArea = length_mm * height_mm / 929030.4
billableArea = roundUp(billableArea, configuredDecimals)
baseAmount = billableArea * quantity * unitRate
hardwareAmount = sum(hardwareQuantity * hardwareUnitRate)
lineAmount = round(baseAmount + hardwareAmount, 2)
```

The exact conversion factor must be configuration, not a hidden constant. A different region, UOM, or commercial rule must be selectable without changing code.

### Package and Hardware Amounts

A component line may use either:

1. A component/package base rate plus selected accessories; or
2. A fixed component amount plus selected accessories.

The quote must retain:

- Component base rate.
- Applied package.
- Applied finish/material multiplier or override.
- Area/running length/quantity used.
- Hardware list and snapshot unit rates.
- Wastage/markup.
- Base amount.
- Discount allocation.
- Tax treatment.
- Final line amount.

## 7. Totals and Financial Rules

The server will calculate:

```text
BOQ subtotal = sum(room/group/subsection subtotals)
Discount amount = round(BOQ subtotal * discount percentage, 2)
Taxable amount = BOQ subtotal - discount + taxable charges
Tax amount = round(taxable amount * tax rate, 2)
Grand total = round(taxable amount + tax amount, 2)
Amount in words = generated from grand total and currency
```

Define discount scope in advance:

- BOQ subtotal.
- Selected room.
- Selected service.
- Selected line.

Never permit the client to submit trusted totals. PostgreSQL/Node.js API validation must verify or recompute all totals.

Tax can vary by scope. The MVP may use one document tax rate for woodwork and other services, but the design should allow per-line tax flags because the sample states separate treatment for woodwork and other work.

## 8. Proposal/PDF Layout

The output must preserve the visual order and hierarchy of the sample:

1. Proposal cover.
2. Enquiry/customer/project metadata.
3. Subject and exclusions.
4. Room-wise woodwork BOQ.
5. Component and accessory tables.
6. Other-services BOQ.
7. BOQ summary.
8. Discount and grand total.
9. Amount in words.
10. Material specifications.
11. Terms, notes, assumptions, and payment stages.
12. Warranty and site-readiness information.
13. Brand footer.

Templates must support:

- Company logo and brand details.
- Accent color.
- Section visibility and order.
- Page breaks.
- Table repeat headers.
- Page numbering.
- Optional cover.
- Optional customer signature block.
- Optional internal-only notes.

The PDF should use server-side generation so every platform receives the same premium proposal.

### PDF Technology

- Use PDFKit in the Vercel/Node.js API as the primary PDF package.
- PDFKit is a free, MIT-licensed PDF generation package and supports custom typography, vectors, tables, branding, page breaks, headers, footers, and page numbering.
- Generate the PDF only after the API has recomputed and validated the quotation totals.
- Store a revision-specific PDF artifact in private workspace storage.
- Return a short-lived download URL to Flutter web, Android, and iOS.
- Use a single premium A4 template for consistent output across platforms.
- Syncfusion PDF may be considered later if advanced features such as digital signatures or enterprise PDF forms become required, subject to its licensing terms.

## 9. Revision and Approval Workflow

### Statuses

```text
Draft -> Pending approval -> Approved
                         -> Rejected
Draft/Approved -> Revision -> Draft
```

Recommended behavior:

- Every approval creates an immutable approved snapshot.
- Editing an approved quotation creates a new revision, not a silent update.
- Revision history retains customer, catalog, package, dimensions, terms, and totals.
- Rejected quotations cannot be edited in place; a revision is required.
- Once approved and invoiced, protected commercial fields become read-only.

### Permissions

- Sales/quotation owner: create, edit, submit.
- Approver: approve or reject.
- Viewer: read.
- Finance: taxes, discounts, payment stages, invoice.
- Workspace admin: catalog and template administration.

## 10. Screen Design

### Desktop/Web

- Quotation list with status, customer, project, number, total, validity, and revision.
- Quotation builder with left-side room navigation and central BOQ table.
- Package/hardware side panel.
- Live summary panel.
- Dimension entry with live amount preview.
- Material and specification tabs.
- Terms/payment schedule editor.
- Review and PDF preview.

### Android/iOS

- Use the same underlying models and API.
- Mobile presentation should use stacked room cards and expandable component cards.
- Numeric fields must use numeric keyboards.
- Package/hardware selection uses searchable sheets.
- PDF preview uses the platform's document viewer/share flow.
- Editing and approval actions must respect permissions.

## 11. Database Design

Use PostgreSQL normalized tables and JSON snapshots.

Suggested tables:

- `quotation_packages`
- `quotation_package_inclusions`
- `catalog_rooms`
- `catalog_components`
- `catalog_services`
- `catalog_materials`
- `catalog_finishes`
- `catalog_hardware`
- `pricing_rules`
- `quotation_documents`
- `quotation_revisions`
- `quotation_sections`
- `quotation_lines`
- `quotation_line_dimensions`
- `quotation_line_hardware`
- `quotation_discounts`
- `proposal_templates`
- `proposal_terms_templates`
- `proposal_payment_schedules`
- `proposal_pdf_artifacts`
- `quotation_calculation_audit`

The existing `finance_documents`, `finance_line_items`, `finance_document_templates`, and invoice/payment tables will remain the commercial-document foundation.

Every table must include workspace isolation and appropriate PostgreSQL RLS policies.

### Audit Requirements

Each calculation snapshot must record:

- Pricing rule version.
- Catalog and package versions.
- Input dimensions.
- Quantity.
- UOM.
- Unit rate.
- Applied multipliers.
- Hardware selections and quantities.
- Discount.
- Tax.
- Subtotal and final line amount.
- Calculator version.

## 12. API Design

Recommended endpoints:

```text
GET    /api/catalog/packages
PUT    /api/catalog/packages/{id}
GET    /api/catalog/components
GET    /api/catalog/hardware
POST   /api/quotations
GET    /api/quotations/{id}
PUT    /api/quotations/{id}/revisions/{revisionId}
POST   /api/quotations/{id}/revisions
POST   /api/quotations/{id}/calculate
POST   /api/quotations/{id}/submit
POST   /api/quotations/{id}/approve
POST   /api/quotations/{id}/reject
POST   /api/quotations/{id}/pdf
GET    /api/quotations/{id}/pdf/{revisionId}
POST   /api/quotations/{id}/convert-to-proposal
```

All mutation endpoints must:

- Validate workspace membership.
- Validate role permission.
- Recalculate totals server-side.
- Use optimistic concurrency/revision checks.
- Preserve audit history.
- Generate IDs and document numbers atomically.

## 13. Validation Rules

- Length and height must be positive and within configurable limits.
- Quantity must be greater than zero.
- Package must belong to the workspace.
- Hardware SKU/brand must belong to the same workspace and be compatible with the component.
- Dimensions must match the selected pricing model.
- Rate changes require a new package/catalog revision or explicit override approval.
- Discount cannot be negative and cannot exceed the allowed percentage.
- Discount scope must match existing lines.
- Totals and tax calculations must match server output.
- Validity date cannot be before proposal date.
- PDF generation must not expose internal cost or margin fields.
- Internal notes must not appear in customer-facing PDFs.
- Approved snapshots cannot be changed.

## 14. Security and Privacy

- Use workspace RLS for all catalog and quotation records.
- Restrict PDF artifacts to workspace members.
- Use signed, short-lived PDF download URLs.
- Encrypt or mask provider credentials, but not public workspace documents.
- Do not trust package prices or totals submitted by Flutter.
- Log approvals, revisions, discounts, and catalog/rate changes.
- Export/audit data according to workspace retention policies.

## 15. Acceptance Criteria

The module is ready only when:

- Basic, Medium, and Luxury packages can be maintained.
- Hardware and materials can be assigned to packages.
- A quotation can contain rooms, components, dimensions, hardware, services, and notes.
- Length/height calculations produce the same result in web and mobile clients.
- Package and hardware changes update totals correctly.
- Discounts and taxes are calculated consistently by the server.
- Document numbering and revisions are unique and concurrency-safe.
- PDF output includes all room/service totals and the branded layout.
- Approved and historical revisions are immutable.
- Unauthorized workspace users cannot read or mutate records.
- Material/specification/terms templates can be reused.

## 16. Implementation Milestones

### Milestone A: Catalog and Package Foundation

Build room/component/service catalogs, pricing rules, hardware, materials, finishes, and package templates.

### Milestone B: Calculation Engine

Implement server-side dimensional, running-length, unit, point, and lumpsum calculators with audit snapshots.

### Milestone C: Quotation Builder

Implement the web/mobile quotation editor, room hierarchy, package selection, hardware selection, live preview, and validation.

### Milestone D: Revision and Approval

Add revisions, immutable snapshots, approval states, permissions, and change history.

### Milestone E: Proposal and PDF

Add template sections, specifications, terms, payment schedule, summary, discount, amount-in-words, branded PDF, and private storage.

### Milestone F: Finance Integration and Hardening

Convert approved proposals to invoices, test concurrent revisions/document numbers, add export/reporting, performance optimization, and production verification.

The detailed, implementation-ready milestone breakdown is maintained in [QUOTATION_IMPLEMENTATION_MILESTONES.md](./QUOTATION_IMPLEMENTATION_MILESTONES.md).

## 17. Open Decisions Requiring Sign-Off

The following values need business approval before implementation:

- Default package inclusions for Basic, Medium, and Luxury.
- Canonical room/component catalog.
- Dimension unit: millimeters versus feet/inches.
- Woodwork pricing method: square feet, running foot, component fixed rate, or configurable mix.
- Whether panel dimensions use length × height or include depth/width.
- Whether hardware is included, optional, or separately charged.
- Default package upgrade/downgrade behavior.
- Whether Wicker/other item prices vary by size and should be re-priced automatically.
- Tax treatment: one tax rate or per-line tax rules.
- Discount scope and maximum discount/approval level.
- GST and HSN/SAC requirements.
- Currency and currency-symbol format.
- Validity period and revision-number format.
- PDF approval/signature behavior.
- Whether a customer can approve or reject proposals online.
- Whether WhatsApp/email sending is required at proposal approval.
- Retention period for revisions and PDF artifacts.

## 18. Sign-Off Checklist

Approve the document only when all items are confirmed:

- [ ] Package structure and inclusions.
- [ ] Room/component catalog.
- [ ] Hardware and accessory catalog.
- [ ] Pricing formulas and UOM.
- [ ] Tax and discount rules.
- [ ] Revision and approval workflow.
- [ ] PDF layout and template sections.
- [ ] Terms, warranties, and payment stages.
- [ ] Role permissions.
- [ ] Mobile editing scope.
- [ ] Implementation milestones and sequence.

## 19. Final Recommendation

The recommended MVP is to implement configurable package presets over the existing PostgreSQL finance model, with the server-owned calculation engine as the core component.

Do not initially hard-code Basic/Medium/Luxury rules in Flutter. Store package, catalog, price, and calculation definitions in PostgreSQL, snapshot them in revisions, and enforce authorization and totals on the API.
