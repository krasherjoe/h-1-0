# Discussion Log: Phase 2 — 請求書インポートバグ修正

## Overview
- **Date:** 2026-05-22
- **Mode:** --chain (interactive discuss → auto plan+execute)
- **Total questions asked:** 1

## Questions Asked

### Q1: Gray area selection
- **Options presented:**
  - 修正アプローチ — import 時の unitPrice 丸め vs _loadExisting 保存
  - DBスキーマ変更 — カラム追加の是非
  - テスト方針 — Widget test vs Unit test
  - _calculate 統一 — import と通常の計算パス統一の是非
- **User selection:** "わからん" (freeform — unsure)
- **Follow-up:** Clarified the bug chain and proposed minimal fix approach
- **Resolution:** User delegated ("まかせる") → Claude discretion applied

## Decisions Made

### Fix approach (D-01〜D-05)
- Add `savedSubtotal` field to `_LineItem`
- `_loadExisting` → store `DocumentItem.subtotal` in `savedSubtotal`
- `_calculate()` → prefer `savedSubtotal` when set
- `_save()` → prefer `savedSubtotal` for DocumentItem.subtotal
- No DB schema changes
- No changes to `_performImport()`

### Test approach (D-06〜D-07)
- Widget tests for import flow
- Unit tests for `_calculate()` logic

### Scope (D-08〜D-10)
- No unification of import/normal calculation paths
- No UI changes
- Other document types out of scope

## Deferred Ideas
None

## Artifacts
- `02-CONTEXT.md` — Implementation decisions for downstream agents
