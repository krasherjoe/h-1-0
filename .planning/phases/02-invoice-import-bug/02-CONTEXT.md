# Phase 2: 請求書インポートバグ修正 - Context

**Gathered:** 2026-05-22
**Status:** Ready for planning

<domain>
## Phase Boundary

請求書から売上伝票へのインポート時の合計金額不一致を修正する。具体的には、請求書明細を売上伝票にインポート→保存→再表示した際の合計金額が元の請求書と一致しないバグを修正し、Widget テストを追加する。

ROADMAP の範囲を超えない — インポート機能自体の拡張やリファクタリングは含まない。

</domain>

<decisions>
## Implementation Decisions

### Fix Approach
- **D-01:** `_LineItem` に `savedSubtotal` (`int?`) フィールドを追加する
  - 画面読み込み時 (`_loadExisting`) に `DocumentItem.subtotal` の値を `savedSubtotal` に保持
  - DBスキーマ変更不要 — `_LineItem` は UI 状態クラスのため
- **D-02:** `_calculate()` で `savedSubtotal` が設定されている場合は常にそれを使用する
  - `isFromInvoice` による分岐より優先
  - これにより import 由来の明細も通常明細も丸め誤差なく正しい subtotal を表示
- **D-03:** 保存時 (`_save()`) も `savedSubtotal` を優先して `DocumentItem.subtotal` に設定する
- **D-04:** DB スキーマは変更しない（v45 維持、DB migration 不要）
- **D-05:** `_performImport()` のインポートコードは変更しない — 現在の import 表示ロジックは正しく動作している

### Test Approach
- **D-06:** テスト種類 — Widget テスト（import→金額確認）と `_calculate()` 単体テスト
  - Widget テスト: `SalesInputScreen` を開き、請求書インポート後に合計金額が請求書と一致することを確認
  - 単体テスト: `_calculate()` のロジックを imported/normal items それぞれで検証
- **D-07:** 既存テストパターンを踏襲 — `sqflite_common_ffi` を使用したインメモリ DB テスト

### Scope Constraints
- **D-08:** `_calculate()` の import 明細と通常明細の計算パスの統一は行わない（現状維持）
- **D-09:** インポート機能の UI 変更は行わない
- **D-10:** 他のドキュメントタイプ（見積、受注等）のインポートは対象外

### Claude's Discretion
- テストファイルの具体的な配置と構造
- `_LineItem` の `savedSubtotal` 初期値（`null` で問題なし）
- Widget テストの具体的なセットアップ詳細

</decisions>

<specifics>
## Specific Ideas

- "import して保存したら金額が合わない" というユーザー報告が発端
- Phase 1（SE1明細ロードバグ）と関連が深いが、こちらは Repository ではなく Screen 内の状態管理の問題
- インポート→保存→再表示のサイクルで壊れるのが特徴

</specifics>

<canonical_refs>
## Canonical References

### Source files (MUST read before planning)
- `lib/screens/sales_input_screen.dart` — 全修正対象コード（_performImport L222, _calculate L261, _loadExisting L57, _save L291, _LineItem L585）
- `lib/models/base_document.dart` — DocumentItem モデル（savedSubtotal 相当のフィールドはなし）
- `lib/models/invoice_models.dart` — InvoiceItem, Invoice モデル（import 元データ構造）
- `lib/services/sales_repository.dart` — データ保存・読込（Phase 1 で修正済み）

### Related artifacts
- `.planning/phases/01-se1/01-01-SUMMARY.md` — Phase 1 修正内容（明細ロードパターンの参考）
- `.planning/phases/01-se1/01-02-SUMMARY.md` — Phase 1 テストパターン

### No external specs
外部仕様書なし — 上記コードが唯一の仕様

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `_LineItem` クラス (`sales_input_screen.dart:585`) — 修正対象、フィールド追加のみ
- `_calculate()` メソッド (`sales_input_screen.dart:261`) — 修正対象、savedSubtotal 優先分岐追加
- `_loadExisting()` メソッド (`sales_input_screen.dart:57`) — 修正対象、savedSubtotal 保存追加
- `_save()` メソッド (`sales_input_screen.dart:291`) — 修正対象、savedSubtotal 保存優先

### Established Patterns
- Phase 1 の最小修正パターンを踏襲 — `_loadExisting` に「savedSubtotal フィールド追加＋計算で優先使用」のみ
- Widget テストは `sqflite_common_ffi` で DB をモック

### Integration Points
- `SalesInputScreen` と `InvoicePickerModal` の連携（インポート元選択）
- `SalesRepository` を経由した永続化（Phase 1 で修正済み、本Phaseでは不変）

</code_context>

<deferred>
## Deferred Ideas

なし — 議論はフェーズ範囲内に収まった

</deferred>

---

*Phase: 02-invoice-import-bug*
*Context gathered: 2026-05-22*
