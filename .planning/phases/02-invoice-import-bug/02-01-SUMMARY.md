---
phase: 02-invoice-import-bug
plan: 01
subsystem: ui
tags: sales_input, invoice_import, rounding_error, subtotal
requires: []
provides:
  - "_LineItem.savedSubtotal フィールドによる復元明細の小計保持"
  - "savedSubtotal を _calculate() と _save() で優先使用するパターン"
affects: []
tech-stack:
  added: []
  patterns:
    - "_LineItem に savedSubtotal (int?) フィールドを追加し、DB 読み込み時に DocumentItem.subtotal を保持"
    - "_calculate() / _save() で savedSubtotal != null を最優先の分岐条件として使用"
key-files:
  created: []
  modified:
    - lib/screens/sales_input_screen.dart
key-decisions:
  - "savedSubtotal は final int?（null 許容）— _loadExisting() のみ値が入り、新規・インポート明細では null"
  - "_calculate() の isFromInvoice / !isFromInvoice 分岐は維持し、savedSubtotal チェックのみ先頭に追加"
  - "DB スキーマ変更不要 — _LineItem は UI 状態クラスのため"
patterns-established: []
requirements-completed:
  - BUG-02
duration: 3min
completed: 2026-05-22
---

# Phase 02 Plan 01: 請求書インポート金額不一致修正 Summary

**savedSubtotal フィールド追加により、請求書インポート→保存→再表示の合計金額不一致バグを修正**

## Performance

- **Duration:** 3 min
- **Started:** 2026-05-22T06:22:18Z
- **Completed:** 2026-05-22T06:25:06Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

- `_LineItem` クラスに `savedSubtotal` フィールドを追加し、`_loadExisting()` で DB から読み込んだ小計値を保持するようにした
- `_calculate()` の小計計算冒頭に `savedSubtotal != null` チェックを追加（`isFromInvoice` 分岐より優先）
- `_save()` の `DocumentItem.subtotal` 計算に `savedSubtotal ??` フォールバックチェーンを追加
- `isFromInvoice` 分岐構造は維持、`_performImport()` は未変更

## Task Commits

Each task was committed atomically:

1. **Task 1: _LineItem に savedSubtotal フィールドを追加し _loadExisting() で保存する** - `59e8373`
2. **Task 2: _calculate() と _save() で savedSubtotal を優先使用する** - `8f2908f`

**Plan metadata:** (pending final commit)

## Files Created/Modified

- `lib/screens/sales_input_screen.dart` — _LineItem に savedSubtotal フィールド追加、constructor param 追加、_loadExisting() で保存、_calculate() 優先条件、_save() フォールバックチェーン。5箇所の変更。

## Decisions Made

- `savedSubtotal` は `final int?`（null 許容）— `_loadExisting()` でのみ値が設定され、新規追加明細やインポート明細では `null` のまま動作
- `_calculate()` は既存の `isFromInvoice` / `!isFromInvoice` 分岐構造を維持し、`savedSubtotal` チェックのみ先頭に追加（D-08 遵守）
- `_save()` の三項演算子の分岐構造も維持し、`savedSubtotal ??` のみ先頭に追加
- DB スキーマ変更なし（UI 状態クラスのフィールド追加のみ）
- `_performImport()` は一切変更せず

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - すべてスムーズに実装・検証完了。

## User Setup Required

None - no external service configuration required.

## Self-Check: PASSED

- [x] `_LineItem` class has `final int? savedSubtotal` — line 600
- [x] `_loadExisting()` has `savedSubtotal: item.subtotal` — line 92
- [x] `_calculate()` has `savedSubtotal != null` priority check — line 267
- [x] `_save()` has `savedSubtotal ??` fallback chain — line 328
- [x] `_performImport()` unchanged — 2 references maintained
- [x] `isFromInvoice` / `!isFromInvoice` branch structure intact
- [x] `flutter analyze --no-fatal-infos` passes (598 info-level issues, none in our file)
- [x] `flutter test` — 63 passed, 7 pre-existing failures (unrelated test files)
- [x] Both commits exist: `59e8373`, `8f2908f`
- [x] `lib/screens/sales_input_screen.dart` exists with 610+ lines

## Next Phase Readiness

Phase 02 complete. Ready for testing phase (BUG-02 に対するテスト追加) or moving to next bug fix.
