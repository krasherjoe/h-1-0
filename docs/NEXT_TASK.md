# 次のタスク

**最終更新**: 2026-03-09 09:35

---

## 🎯 今すぐ実行するタスク

### タスクID: TEST-ADD-001
**タスク名**: 単体テスト追加  
**優先度**: 🔴 高  
**担当**: SWE1.5  
**推定時間**: 2時間  
**状態**: 🚧 実行予定

---

## 📝 タスク概要

LINT-FIX-002が完了したため、テストカバレッジ向上タスクを実行する。モデルクラス、リポジトリクラス、基本的なウィジェットの単体テストを追加し、コード品質と信頼性を向上させる。

### 背景

- STAGE-IVで新規モデルとリポジトリを追加
- 既存コードのテストカバレッジが不足
- Phase 0完了の必須条件としてテスト整備が必要

---

## 🎯 対象ファイル

### 新規テスト作成
1. `test/unit/models/business_profile_model_test.dart`（新規）  
2. `test/unit/models/inventory_location_model_test.dart`（新規）  
3. `test/unit/services/business_profile_repository_test.dart`（新規）  
4. `test/unit/services/inventory_location_repository_test.dart`（新規）  

### 既存テスト拡充
5. `test/unit/models/`（既存モデルテスト拡充）  
6. `test/unit/widgets/`（基本ウィジェットテスト追加）

---

## 📋 実行手順

1. **テスト環境確認**
   - `flutter test`で既存テストを確認
2. **新規テスト作成**
   - BusinessProfileモデルの単体テスト
   - InventoryLocationモデルの単体テスト
   - リポジトリクラスの単体テスト
3. **既存テスト拡充**
   - カバレッジ不足のモデルテスト追加
   - 基本ウィジェットテスト追加
4. **検証**
   - `flutter test`ですべてパスを確認
   - `flutter build apk --debug`でビルド成功

---

## ✅ 完了条件

- [ ] 新規モデル・リポジトリの単体テストが追加される
- [ ] 既存テストのカバレッジが向上する
- [ ] `flutter test` すべてパス
- [ ] `flutter build apk --debug` 成功
- [ ] `docs/PROGRESS.md` にTEST-ADD-001完了を追記し、日本語コミット実施

---

## 🔄 完了後の次タスク

このタスク完了後、`docs/NEXT_TASK.md` を次のタスクに更新：

**次のタスク**: TBD（Phase 0残タスクまたはPhase 1準備）

---

## 📚 参考ドキュメント

- `docs/TASK_QUEUE.md` TEST-ADD-001詳細
- 既存テスト: `test/unit/` ディレクトリ
- テストガイド: Flutter公式ドキュメント

---

## 🚀 開始方法

```
1. flutter test で既存テスト状況を確認
2. 新規モデル・リポジトリの単体テストを作成
3. 既存テストを拡充しカバレッジ向上
4. 検証とコミット実施
```

---

## ⚠️ 注意事項

- テストは独立して実行できること
- モック依存を最小限にすること
- 重要なビジネスロジックを優先的にテストすること
- テストコードもコード品質ルールを遵守すること

---

## 📝 完了報告テンプレート

- 単体テスト追加完了（新規4ファイル＋既存拡充）
- `flutter test` すべてパス確認
- `flutter build` 成功
- 日本語コミット完了
- `docs/PROGRESS.md` へTEST-ADD-001追記済

---

このタスク完了後は、Phase 0残タスクの整理かPhase 1準備へ移行する。
