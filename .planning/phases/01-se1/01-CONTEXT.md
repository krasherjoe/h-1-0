# Phase 1: SE1売上伝票バグ修正 - Context

**Gathered:** 2026-05-22
**Status:** Ready for planning

<domain>
## Phase Boundary

SE1（売上伝票）の保存後に再表示すると内容が空になるバグを修正する。原因は `SalesRepository` の `getSales()` / `getAllSales()` / `getSalesByInvoiceId()` が `sales_items` テーブルから明細を読み込んでいないこと。合わせて同パターンの `QuotationRepository.getAllQuotations()` も修正し、各修正箇所に Repository 単体テストを追加する。

**In scope:**
- `SalesRepository`: 3メソッド（getSales, getAllSales, getSalesByInvoiceId）に `_loadSalesItems` 呼び出しを追加
- `QuotationRepository`: getAllQuotations に明細読み込みを追加
- 各修正箇所の Repository 単体テスト

**Out of scope:**
- Widget テスト（後の Phase で対応）
- 他画面・他リポジトリの改修
- DB スキーマ変更
- UI 改修

</domain>

<decisions>
## Implementation Decisions

### 修正アプローチ
- **D-01:** 最小修正 — 既存の `_loadSalesItems` を各メソッドの `Sales.fromMap()` 呼び出し後に追加する。新規 private メソッドの作成やリファクタリングは行わない
- **D-02:** `SalesRepository.getSales()` — `Sales.fromMap()` 後に `_loadSalesItems()` を呼び出して items をセット
- **D-03:** `SalesRepository.getAllSales()` — 同様にループ内で各 Sales オブジェクトに明細をロード
- **D-04:** `SalesRepository.getSalesByInvoiceId()` — 同様にループ内で各 Sales オブジェクトに明細をロード
- **D-05:** `QuotationRepository.getAllQuotations()` — 同パターンで `quotation_items` から明細をロードする処理を追加
- **D-06:** `Sales.fromMap()` の `items: []` は変更しない（呼び出し元で明細をセットする設計を維持）

### テスト範囲
- **D-07:** Repository 単体テストを追加（修正箇所の明細読込が正しく動作することを確認）
- **D-08:** Widget テストはこの Phase では追加しない

### 波及範囲
- **D-09:** 他リポジトリ（invoice, purchase_order/return/entry）は既に正しく実装済みのため修正不要
- **D-10:** 子テーブルを持たないリポジトリは対象外

### Claude's Discretion
- テスト用の DB セットアップ方法（sqflite_common_ffi の使用）
- テストケースの具体的な内容
- エラーハンドリングの追加有無

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 修正対象ファイル
- `lib/services/sales_repository.dart` — 修正対象: getSales (L44), getAllSales (L17), getSalesByInvoiceId (L100), _loadSalesItems (L173)
- `lib/services/quotation_repository.dart` — 修正対象: getAllQuotations (L16), 子テーブル quotation_items
- `lib/models/sales_model.dart` — Sales.fromMap() は items: [] (L83)

### 参考実装（正しいパターン）
- `lib/services/purchase_order_repository.dart` — findById で _fetchItems を呼ぶ正しい実装パターン
- `lib/services/invoice_repository.dart` — getAllInvoices で invoice_items をロードする実装

### テスト参考
- 既存のテストファイルがあれば参考にする

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SalesRepository._loadSalesItems(String salesId)` — 既存メソッド、`sales_items` テーブルから明細をロードする。`getAllSalesWithItems()` で使用中
- `DocumentItem.fromMap()` — 明細行のマッピングに使用

### Established Patterns
- `purchase_order_repository.dart` の `_fetchItems()` パターン: `findById()` で `_fetchItems()` を呼び出して子テーブルをロード
- `invoice_repository.dart` のパターン: `getAllInvoices()` 内で `invoice_items` を一括クエリして各 Invoice オブジェクトに紐付け

### Integration Points
- 修正後は `sales` テーブルの問い合わせ結果に items が正しく含まれるようになる
- `SalesInputScreen._loadExisting()` が期待通り items を取得できるようになる
- `getAllSalesWithItems()` との重複に注意（二重ロードにならないか）

</code_context>

<specifics>
## Specific Ideas

バグの根本原因は `SalesRepository.getSales()` が `_loadSalesItems()` を呼んでいないこと。修正は `Sales.fromMap()` の呼び出し後に以下を追加する：

```dart
final sales = Sales.fromMap(map, customer);
sales.items = await _loadSalesItems(sales.id);
return sales;
```

同様の修正を `getAllSales()` と `getSalesByInvoiceId()` にも適用。

</specifics>

<deferred>
## Deferred Ideas

- Widget テストの追加 — 別 Phase で対応予定
- 全画面を通じたデータ整合性の検証 — Phase 3（残バグ監査・修正）で対応

</deferred>

---

*Phase: 1-SE1売上伝票バグ修正*
*Context gathered: 2026-05-22*
