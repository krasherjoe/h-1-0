# Roadmap: 販売アシスト 1号（お局様サーバー） — 安定化マイルストーン

## Overview

既存の販売管理アプリ（Flutter, 約86,500行, 50%実装済み）の安定化マイルストーン。既知のバグ（SE1売上伝票保存/読込、請求書インポート金額不一致）の修正から着手し、残バグの洗い出し、テスト追加、そして主要業務フロー（見積→受注→請求サイクル）の安定動作検証までを行う。

## Phases

- [ ] **Phase 1: SE1売上伝票バグ修正** - SE1（売上伝票）の編集保存後に内容が空になるバグを修正し、単体テストを追加
- [ ] **Phase 2: 請求書インポートバグ修正** - 請求書インポート時の合計金額不一致を修正し、Widgetテストを追加
- [ ] **Phase 3: 残バグ監査・修正** - 残りの既知バグ（3-5個）を洗い出し、修正、テストを追加
- [ ] **Phase 4: コアフロー安定化** - 主要業務フロー（見積→受注→請求サイクル）の安定動作を確認

## Phase Details

### Phase 1: SE1売上伝票バグ修正
**Goal**: SE1（売上伝票）が正しく保存・読込できるようになる
**Depends on**: Nothing (first phase)
**Requirements**: BUG-01, TST-01
**Success Criteria** (what must be TRUE):
  1. ユーザーが売上伝票を新規作成し、全項目（日付、得意先、明細、金額）を入力して保存できる
  2. 保存後に再表示しても、入力した内容が正しく保持されている（空にならない）
  3. 保存済みの売上伝票を編集し、再度保存しても内容が維持される
  4. 修正箇所の単体テストが追加され、`flutter test` が通過する
  5. `flutter analyze --no-fatal-infos` が通過する
**Plans**: 2 plans
**UI hint**: yes

**Plan list:**
- [x] 01-01-PLAN.md — SalesRepository + QuotationRepository: 明細ロード追加（Wave 1）
- [ ] 01-02-PLAN.md — Repository単体テスト追加（Wave 2）

### Phase 2: 請求書インポートバグ修正
**Goal**: 請求書から売上伝票へのインポート時の合計金額が正しく計算される
**Depends on**: Phase 1
**Requirements**: BUG-02, TST-02
**Success Criteria** (what must be TRUE):
  1. ユーザーが請求書を選択して売上伝票にインポートした際、インポート元の請求書と合計金額が一致する
  2. インポート後の売上伝票の小計・税額・合計がすべて正しく計算される
  3. 複数明細の請求書をインポートしても金額が一致する
  4. 修正箇所の Widget テストが追加され、`flutter test` が通過する
  5. `flutter analyze --no-fatal-infos` が通過する
**Plans**: TBD
**UI hint**: yes

### Phase 3: 残バグ監査・修正
**Goal**: 残りの既知バグ（3-5個）が洗い出され、修正され、テストも追加されている
**Depends on**: Phase 2
**Requirements**: BUG-03
**Success Criteria** (what must be TRUE):
  1. 既存画面（見積入力、受注入力、在庫照会など主要画面）を操作してデータ保存/読込の一貫性が確認できる
  2. バグ監査で発見された各バグが修正され、該当機能が正しく動作する
  3. 各修正に対して単体テストまたは Widget テストが追加されている
  4. `flutter test` が全テスト通過する
  5. `flutter analyze --no-fatal-infos` が通過する
**Plans**: TBD
**UI hint**: yes

### Phase 4: コアフロー安定化
**Goal**: 主要業務フロー（見積→受注→請求サイクル）が安定して動作することが確認される
**Depends on**: Phase 3
**Requirements**: STB-01
**Success Criteria** (what must be TRUE):
  1. 見積書の作成から保存、再表示までの一連の流れがエラーなく動作する
  2. 見積書から受注伝票への変換が正しく動作する
  3. 受注伝票から請求書発行までの流れが正しく動作する
  4. 上記フローを通じてデータの整合性が維持される（金額が一致する）
  5. 上記フローを3回連続で実行してもエラーが発生しない
**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:** Sequential (1 → 2 → 3 → 4)

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. SE1売上伝票バグ修正 | 1/2 | In Progress | 2026-05-22 |
| 2. 請求書インポートバグ修正 | 0/0 | Not started | - |
| 3. 残バグ監査・修正 | 0/0 | Not started | - |
| 4. コアフロー安定化 | 0/0 | Not started | - |
