# Phase 3: 残バグ監査・修正 - Context

**Gathered:** 2026-05-22
**Status:** Ready for planning

<domain>
## Phase Boundary

主要画面（見積入力、受注入力、在庫照会など）のコード監査を実施し、Phases 1-2 と同パターンのバグ（子テーブル未読込、割引損失）を修正する。DB スキーマ変更は行わない。

</domain>

<decisions>
## Implementation Decisions

### Bug Audit Results
- **Bug 1 (CLEAN):** SalesRepository — Phase 1 で修正済み ✅
- **Bug 2 (CLEAN):** QuotationRepository — Phase 1 で修正済み ✅
- **Bug 3 (DESIGN GAP / SKIP):** DeliveryRepository — `delivery_items` テーブルが存在せず（DB スキーマ変更が必要）、修正対象外
- **Bug 4 (DESIGN GAP / SKIP):** PurchaseRepository — `purchase_items` テーブルが存在せず、修正対象外
- **Bug 5 (BUG / FIX):** `InvoiceRepository.convertInvoiceToSales()` — 割引損失＋subtotal null 問題

### Fix Approach (D-01〜D-04)
- **D-01:** `convertInvoiceToSales()` で `item['subtotal']` は `invoice_items` テーブルに存在しないため、`quantity * unit_price` から計算する（割引が適用されている場合は `quantity * unit_price - coalesce(discount_amount, 0)` を使用する）
- **D-02:** 請求書ヘッダーの `total_discount_amount` / `total_discount_rate` は sales テーブルに該当カラムがないため適用しない（DB スキーマ変更禁止）
- **D-03:** 請求書の `total_amount` を sales.total にそのまま設定する（合計金額一致）
- **D-04:** テスト追加 — `convertInvoiceToSales()` のユニットテスト

### Scope Constraints
- **D-05:** DB スキーマ変更は行わない（v45維持）
- **D-06:** DeliveryRepository / PurchaseRepository は未対応
- **D-07:** `sales_items` テーブルに discount カラムは追加しない

</decisions>

<specifics>
## Specific Ideas

- Bug 5 は `convertInvoiceToSales()` が `invoice_items.subtotal` カラム（存在しない）を参照していることによる null 問題
- 加えて `invoice_items.unit_price` をそのまま使っており、割引が反映されていない
- 修正: `unit_price * quantity - discount_amount` で subtotal を計算

</specifics>

<canonical_refs>
## Canonical References

- `lib/services/invoice_repository.dart:1086` — `convertInvoiceToSales()` 修正対象
- `lib/services/database_helper.dart:2414` — `invoice_items` テーブルスキーマ（subtotal カラムなし）
- `lib/services/sales_repository.dart` — Phase 1 修正例（参考実装）
</canonical_refs>

<deferred>
## Deferred Ideas
- DeliveryRepository / PurchaseRepository の子テーブル対応は DB スキーマ変更が必要なため、別 Phase

</deferred>

---

*Phase: 03-bug-audit*
*Context gathered: 2026-05-22*
