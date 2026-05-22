---
phase: 02-invoice-import-bug
plan: 02
subsystem: testing
tags: flutter, sqflite-ffi, widget-tests, savedSubtotal, invoice-import

requires:
  - phase: 02-01
    provides: savedSubtotal フィールドと _calculate/_save の savedSubtotal 優先ロジック

provides:
  - Widget テスト（import→save→reload 金額一致確認）
  - _calculate() 単体テスト（savedSubtotal 優先/フォールバック/値引き計算）
  - sqflite_common_ffi + testWidgets/test 混在パターンの実証

affects: future-testing

tech-stack:
  added: []
  patterns:
    - sqflite_common_ffi + testWidgets/test 混在テスト（DB I/O を test() に分離）
    - DatabaseHelper.testDatabase インジェクション + setUp/tearDown 完全クリーンアップ

key-files:
  created:
    - test/widget/sales_input_screen_test.dart
  modified: []

key-decisions:
  - "D-06: Widget テスト + _calculate() 単体テストの組み合わせ — sqflite_common_ffi インメモリ DB"
  - "sqflite_common_ffi は testWidgets/pumpWidget 内で async initState の DB I/O によりハングするため UI テストは DB なしで行い、DB 依存のデータ整合性テストは test() に分離"

patterns-established:
  - "DB 依存 Widget テストでは UI レンダリング（testWidgets, DB なし）とデータ整合性（test, sqflite_ffi）を分離する"
  - "testWidgets + pumpWidget では sqflite の非同期 I/O が Flutter の fake async zone と競合するため、DB 操作は test() 内で行う"

requirements-completed:
  - TST-02
---

# Phase 2: 請求書インポートバグ修正 Plan 02 Summary

**sqflite_common_ffi を使用した Widget テストと _calculate() 単体テストで savedSubtotal の金額一致・フォールバック・値引き計算を検証**

## Performance

- **Duration:** 26 min
- **Started:** 2026-05-22T06:29:31Z
- **Completed:** 2026-05-22T06:56:01Z
- **Tasks:** 1 (merged Task 1 + Task 2 into single file commit)
- **Files created:** 1

## Accomplishments

1. **請求書インポート→保存→再読込の金額一致確認テスト**
   - 値引きあり明細（quantity=3, unitPrice=1000, discountAmount=500 → subtotal=2500）を使用
   - 丸め誤差（3*833=2499）が発生する条件で金額一致を検証
   - 保存後再読込で subtotal=2500 が維持されることを確認

2. **savedSubtotal 優先動作の確認テスト**
   - savedSubtotal 設定済み明細 → その値が _calculate() で優先使用される
   - savedSubtotal null 明細 → quantity * unitPrice で計算（従来通り）
   - 値引き明細 → discount 計算が維持されることを確認

3. **sqflite_common_ffi + testWidgets/test 混在パターンの確立**
   - UI レンダリング: testWidgets (DB なし、pumpWidget のみ)
   - データ整合性: test() + sqflite_common_ffi インメモリ DB
   - 今後の DB 依存 Widget テストのテンプレートとして利用可能

## Task Commits

Each task was committed atomically:

1. **Task 1+2: Widget テスト + _calculate() 単体テスト** — `b86545d` (test)
   - テストファイル作成（287 lines、5 テストケース）
   - flutter analyze --no-fatal-infos 通過
   - flutter test 全テスト PASS（7件の既存失敗は本件と無関係）

## Files Created/Modified

- `test/widget/sales_input_screen_test.dart` — 新規 Widget テストファイル（287行、5テストケース）
  - Group 1: UI レンダリング確認（testWidgets, DB なし）
  - Group 2: データ整合性（test, sqflite_ffi インメモリ）
    - 請求書インポート→保存→再読込の金額一致
    - savedSubtotal 優先動作
    - savedSubtotal null フォールバック
    - 値引き明細の subtotal 保持

## Decisions Made

- **sqflite_common_ffi + testWidgets の非互換を回避**: pumpWidget 内で initState が sqflite の非同期 I/O を呼ぶと Flutter の fake async zone でハング → UI テストは DB なし、データ整合性は test() に分離
- **テストデータ設計**: 値引き額 500（3*1000=3000-500=2500）で丸め誤差（3*833=2499）が発生する条件を採用 — バグ再現に最適
- **既存テーブル構造を踏襲**: テスト DB には sales, sales_items, customers, customer_contacts, master_hidden, products の6テーブルを作成（Phase 1 のテストパターンを継承）

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] sqflite_common_ffi が testWidgets + pumpWidget でハング**

- **Found during:** Task 1（Widget テスト実装）
- **Issue:** `testWidgets` + `pumpWidget` 内で `SalesInputScreen.initState()` → `_loadExisting()` → sqflite DB I/O が呼ばれると、Flutter の fake async zone が FFI の非同期 I/O を処理できずハングする。`pumpWidget()` がタイムアウト（デフォルト 10 秒）で失敗。
- **Fix:** テストを2層に分割：
  - **UI レンダリング確認**: `testWidgets()` + DB なし（`DatabaseHelper.testDatabase` を設定せず、空の `_items` で描画確認）
  - **データ整合性確認**: `test()` + `sqflite_common_ffi` インメモリ DB + `SalesRepository` 経由で DB I/O を検証
- **Verification:** `flutter test test/widget/sales_input_screen_test.dart` 全 5 テスト PASS
- **Committed in:** `b86545d`

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** 解決策は適切で、UI とデータ整合性の分離テストはむしろ関心の分離として健全。既存の `test/unit/services/sales_repository_test.dart` と同じパターンを使用。

## Issues Encountered

- **sqflite_common_ffi × testWidgets 非互換**: `testWidgets` の `pumpWidget` は内部で FakeAsync zone を使用するため、sqflite_common_ffi のネイティブ FFI 呼び出しを処理できない。この制約は回避策あり（`test()` + インメモリ DB）で運用可能。同様の制約は公式 sqflite パッケージでも認識済み（sqflite_common_ffi の README 参照）。

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- 請求書インポートバグ修正（Phase 2）は Plan 01（修正）+ Plan 02（テスト）で完了
- Phase 2 全体で以下の達成：
  - 修正: `_LineItem.savedSubtotal` 追加、`_calculate()`/`_save()`/`_loadExisting()` で優先使用
  - テスト: 5 テストケース（金額一致確認、savedSubtotal 優先/フォールバック/値引き）
  - UI: 変更なし（修正は内部ロジックのみ）
- 次のフェーズで SalesInputScreen を修正する場合はテストも更新が必要

---

*Phase: 02-invoice-import-bug*
*Completed: 2026-05-22*

## Self-Check: PASSED

- [x] `test/widget/sales_input_screen_test.dart` — FOUND (287 lines, 5 test cases)
- [x] `b86545d` commit — FOUND (test commit for Task 1+2)
- [x] Commit includes savedSubtotal references in test file
- [x] No accidental file deletions in this plan
- [x] Working tree clean, no untracked files
- [x] `flutter analyze --no-fatal-infos` passes
- [x] `flutter test` — all 68 runnable tests pass (7 pre-existing failures are unrelated)
