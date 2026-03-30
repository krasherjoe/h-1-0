---
# Order Input Implementation Breakdown

Structured task decomposition, dependencies, risks, and open questions for delivering the new Order Input (受注入力) feature.

## 1. Implementation Tracks & Tasks

### 1.1 Data & Repository Layer
1. **Schema Migration**
   - Add `DocumentType.order` enum entry and persistable mapping.
   - Extend `invoices` table with columns:
     - `order_status` (TEXT, default `draft`)
     - `promised_date` (INTEGER epoch)
     - `fulfilled_date` (INTEGER epoch)
     - `source_document_id` (TEXT)
     - `linked_delivery_id` (TEXT)
     - `linked_invoice_id` (TEXT)
   - Consider optional `reserved_stock_json` if stock reservation snapshot required.
2. **Repository Updates**
   - `InvoiceRepository` helpers: `getOrders`, `watchOrders`, `updateOrderStatus`, `convertQuotationToOrder`, `convertOrderToDelivery`, `markOrderFulfilled`.
   - Ensure stock adjustments: draft saves do not change stock; confirmed orders either decrement stock or record reservations (decision pending, see risks).
   - Extend `ActivityLogRepository` actions.
3. **Model Enhancements**
   - Update `Invoice` model + serialization for new fields.
   - Provide convenience getters (`isOrder`, `orderStatusLabel`, `hasLinkedDocs`).

### 1.2 UI / UX Layer
1. **Order List Screen Revamp (`OrderInputScreen`)**
   - State management for filters (status, customer, promised date).
   - Cards with customer, subject, status pill, promised date, total.
   - Empty, loading, and error states.
   - Swipe actions (duplicate, convert, share) hooking into repositories.
2. **Order Detail Screen**
   - Either adapt `InvoiceInputForm` or create dedicated `OrderEditor` wrapper.
   - Tabs/sections for header, schedule, line items, attachments, activity log.
   - Buttons: Save Draft, Preview PDF, Formalize (long-press dialog), Convert to Delivery/Invoice, Reopen Draft.
   - Permissions guard: limit edits based on status.
3. **Navigation Integration**
   - Drawer/menu entry, dashboard tile, FAB wiring, quotation detail CTA, deep links placeholder.
   - Route definitions + argument passing for editing existing orders.

### 1.3 Supporting Services
1. **PDF Template**
   - Define order-specific PDF layout or adapt existing generator with new theme toggle.
2. **Inventory Insights**
   - Display stock levels during item selection (requires repository query per product).
3. **Search & Analytics**
   - Include orders in global search, logging, and any BI exports.

### 1.4 Quality & Delivery
1. **Testing**
   - Unit tests: repository methods, migrations, status transitions.
   - Widget tests: list filters, detail actions, long-press dialog.
   - Integration tests: convert quotation → order → delivery.
2. **Documentation**
   - Update `PROGRESS.md`, `CODING_GUIDE.md`, onboarding docs with new workflow and compliance note.
   - Produce admin/runbook for migrating existing “納品書=受注” usage.
3. **Release Rollout**
   - Data migration dry-run on staging DB.
   - Feature flag or staged rollout plan if required.

## 2. Dependencies & Sequencing
1. Schema + model updates must land before UI revamp (feature flags can guard unfinished UI).
2. Repository methods are prerequisites for list/detail screens.
3. PDF + conversion flows depend on confirmed lifecycle logic.
4. Navigation wiring can occur once list screen MVP is ready.
5. Testing/documentation happen continuously but final pass after UI completion.

Suggested iteration order:
1. Migration + model updates.
2. Repository helpers + unit tests.
3. Order list MVP (read-only) using new filters.
4. Detail editor with draft save + preview.
5. Formalization + conversion flows.
6. Navigation/entry points + analytics.
7. Polish (swipe actions, stock hints) + docs/tests.

## 3. Risks & Mitigations
| Risk | Impact | Mitigation |
| --- | --- | --- |
| Inventory reservation semantics undecided (subtract vs reserve) | Data inconsistency, double-counting | Align with warehouse stakeholders; prototype both and hide behind config. |
| Partial fulfillment requirements unclear | Rework if multi-stage shipping needed | Document assumption (single fulfillment) and design extension points (multiple linked delivery IDs). |
| PDF template complexity | Delays in UI sign-off | Reuse invoice template temporarily with order-specific header until bespoke design ready. |
| Existing data using `DocumentType.delivery` for orders | Migration may misclassify | Provide script to map historical “order-like” deliveries via metadata (e.g., `notes` tag) or manual flag. |
| Long-press rule enforcement across new buttons | Compliance risk if missed | Centralize confirmation dialog in shared widget; add unit test verifying dialog text. |
| Performance with large order lists | UX degradation | Implement paging/lazy loading and caching; add DB indices on `document_type`, `order_status`, `promised_date`. |
| Offline edits conflicting with later conversions | Data loss | Ensure edit logs capture conflicts; display warning if order already confirmed elsewhere. |

## 4. Open Questions
1. Do we store promised/fulfilled dates per line item for partial shipments?
2. Should quotation → order conversion carry over attachments/comments automatically?
3. Is barcode/QR scanning required from day one?
4. How are order numbers formatted relative to existing invoice numbering rules?
5. Any integration hooks (API/web export) needed for ERP alignment?

## 5. Deliverables Checklist
- [ ] Migration scripts & version bump.
- [ ] Updated models/repos with tests.
- [ ] Order list screen with filters + actions.
- [ ] Order detail/editor with full lifecycle controls.
- [ ] Conversion flows (quotation <> order <> delivery/invoice).
- [ ] PDF template update.
- [ ] Navigation + dashboard integration.
- [ ] Documentation & training notes.
