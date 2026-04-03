---
# Order Input (受注入力) Target Experience & Requirements

Define the desired end-to-end experience, functional scope, and data rules for the dedicated order input feature ahead of implementation.

## 1. Guiding Principles & Goals
- **Single source of truth**: Orders must be persisted via the existing `Invoice` model to leverage repositories, edit logs, and PDF flows while clearly distinguished via `DocumentType.order` (new) instead of reusing `delivery`.
- **Draft-first workflow**: Users capture orders quickly on-site (mobile) or at desks (tablet/desktop) and can refine before confirming. Formalization obeys the same long-press + Electronic Bookkeeping Act warning rule as other documents.
- **Inventory awareness**: Saving/confirming an order should reserve stock (soft lock at draft, hard lock when confirmed) to avoid over-selling before delivery or invoicing.
- **Cross-document continuity**: Orders become the bridge between quotations and deliveries/invoices. Copying from quotation and converting to delivery/invoice must be a one-tap action with traceability logs.

## 2. Primary Personas & Context
1. **営業 (Sales rep)**: Captures verbal PO details during client visits using tablet, needs offline resilience and quick duplicate-from-quotation actions.
2. **営業事務 (Sales ops)**: Reviews pending orders, enriches them with promised dates, ensures customer master data accuracy, and finalizes for downstream fulfillment.
3. **倉庫担当 (Fulfillment)**: Needs a filtered list of confirmed orders to schedule picking/delivery (may only require read access initially, but we should expose export/printable summary).

## 3. Core Journeys
1. **新規作成**
   - Entry: FAB on Order list, Dashboard tile, or "Convert to Order" from Quotation detail.
   - Steps: select customer → auto-fill contact snapshot → add line items via master → set delivery promise & notes → save draft (no PDF) or formalize (requires long-press warning) → optional PDF/Share.
2. **編集/更新**
   - Draft orders editable inline. Confirmed orders locked except for logistics fields (e.g., scheduled ship date). Provide explicit "Reopen draft" action with audit log.
3. **変換/連携**
   - From Quotation: copy items, subject, and notes; link source ID for traceability.
   - To Delivery/Invoice: once inventory prepared, allow generating downstream documents with shared items and references.
4. **閲覧/検索**
   - List filters: status (Draft/Confirmed/Fulfilled/Archived), customer, date range, promised date overdue.
   - Sorting: latest update, promised date soonest, customer name.

## 4. Functional Requirements
### 4.1 Order List Screen (revamp of `OrderInputScreen`)
- Replace current placeholder listing with: segmented controls for quick status filter, search box, and chips for saved filters.
- Each card shows:
  - Customer name (bold) + badge for linked quotation/invoice counts.
  - Subject & order number (use deterministic ID or `INV-<yyyyMMdd>-<seq>` style derived from `Invoice.id`).
  - Status pill (Draft/Confirmed/Fulfilled).
  - Promised date + relative label (e.g., "3日以内").
  - Total amount with tax indicator.
- Swipe actions: duplicate, convert to delivery, share PDF.
- Empty state should promote creating from quotation if available.

### 4.2 Order Detail / Editor
- Tabs or collapsible sections for: Header (customer, subject, contact), Schedule (order date, promised shipment, fulfillment notes), Line Items, Attachments.
- Item editor reuses `InvoiceInputForm` components but defaults to order-specific copy: allow quantity reservations and show stock balance next to each selected product (requires repository helper).
- Support undo/redo history and edit log timeline similar to invoice input.
- Buttons:
  - Save Draft.
  - Generate PDF preview (reuses `InvoicePdfPreviewPage` but with order template).
  - Formalize (long-press + warning dialog text updated to mention order immutability & compliance).
  - Convert to Delivery / Invoice (enabled only when confirmed & stock available).

### 4.3 Status & Lifecycle Logic
- `DocumentType` enum: add `order` entry to distinguish in DB and analytics.
- Status field: either reuse `Invoice.isDraft` + `isLocked` OR add `orderStatus` (enum). Proposed states:
  1. Draft (default): editable, no stock lock.
  2. Confirmed: requires long-press; locks line items & customer; reserves stock via existing repository logic.
  3. Fulfilled: set when delivery created or manual toggle; read-only except completion metadata.
- Need `promisedDate`, `fulfilledDate`, `sourceQuotationId`, `linkedDeliveryId`, `linkedInvoiceId` fields (nullable) stored in `invoices` table via new columns or meta JSON.
- Edit log must include transitions with user + timestamp.

### 4.4 Validation Rules
- Customer mandatory.
- At least one item with positive quantity.
- Promised date cannot precede order date.
- Once confirmed, only logistics fields editable (unless reopened by privileged role, tracked in logs).
- Prevent deletion once confirmed; allow archive flag instead.

## 5. Navigation & Surface Integration
1. **Drawer/Menu**: Add entry under Sales operations (ensure label begins with `O1:受注入力`).
2. **Dashboard**: Tile showing counts (draft, overdue, fulfilled). Tap → list filtered accordingly.
3. **Quotation Detail**: Add CTA "受注へ変換" that pushes Order editor with pre-filled data.
4. **Global Search**: Include orders in typeahead results (prefix with `O-`).
5. **Deep Links**: Allow `myapp://orders/<id>` to open detail for cross-feature navigation (optional stretch).

## 6. Data & Persistence Rules
- Schema updates (proposal):
  - `invoices` table: add columns `order_status`, `promised_date`, `fulfilled_date`, `source_document_id`, `linked_delivery_id`, `linked_invoice_id`.
  - `DocumentType` new value `order` stored as integer/enum mapping.
  - Migration updates `_databaseVersion` to next number and ensures defaults (null) for existing rows.
- Repository enhancements:
  - `InvoiceRepository.getAllInvoices` should accept filters for `DocumentType.order` and status fields.
  - Add specialized methods: `watchOrders()`, `getOrdersByStatus`, `convertFromQuotation`, `markOrderFulfilled`.
  - Ensure stock reservation logic differentiates between draft vs confirmed orders (draft should not reduce physical stock; consider `reserved_quantity` column or metadata).
- Analytics/logging: extend `ActivityLogRepository` actions (`CREATE_ORDER`, `CONFIRM_ORDER`, `FULFILL_ORDER`).

## 7. UI/UX Considerations
- Maintain existing typography system but use order-specific accent color (teal) for highlights.
- Provide guidance chips (e.g., "よく使う取引先" suggestions) leveraging `CustomerRepository` stats.
- Support offline: queue order saves when database available even without network; sync remains future work but design should not preclude.
- Accessibility: ensure long lists support keyboard navigation and screen readers (aria labels via `Semantics`).

## 8. Risks & Open Questions (to validate next)
1. How to handle partial fulfillment? (Possible requirement for multi-delivery orders.)
2. Do we need barcode scanning for item entry at MVP?
3. Inventory reservation semantics: do we subtract stock at confirmation or track reserved quantity separately? Requires alignment with warehouse process.
4. Should order PDFs follow existing template or a new dedicated layout? (Impacts `PdfGenerator`.)

## 9. Acceptance Criteria Snapshot
- Requirement doc reviewed with stakeholders.
- New `DocumentType` entry + schema impact approved.
- UX mock or wire depiction of list + detail screens produced (even low-fidelity) before coding.
- Identified blockers (inventory reservation, partial fulfillment) have decisions or placeholders captured.

## 10. Next Actions
1. Review & sign-off on this requirement doc.
2. Finalize schema/migration approach (see Data rules).
3. Start UI prototyping (Figma or built-in widget sketches) aligning with requirements.
