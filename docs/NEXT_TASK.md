# 次のタスク

**最終更新**: 2026-03-09 09:28

---

## 🎯 今すぐ実行するタスク

### タスクID: LINT-FIX-002
**タスク名**: 残りのlint警告修正  
**優先度**: 🔴 高  
**担当**: SWE1.5  
**推定時間**: 30分  
**状態**: 🚧 実行予定

---

## 📝 タスク概要

STAGE-IVが完了したため、コード品質改善タスクを実行する。flutter analyzeで警告が残っている3ファイルのlint問題を修正し、コード品質を向上させる。

### 背景

- STAGE-IV実装完了後、flutter analyzeで警告が残っている
- 既存lintタスク（LINT-FIX-002）が待機中
- コード品質改善はPhase 0完了の必須条件

---

## 🎯 対象ファイル

1. `lib/screens/order_input_screen.dart`  
2. `lib/screens/sales_entry_screen.dart`  
3. `lib/screens/sales_return_input_screen.dart`  

---

## 📋 実行手順

1. **lint警告確認**
   - `flutter analyze`で警告内容を確認
2. **各ファイル修正**
   - 非推奨APIの置き換え
   - mountedチェック追加
   - コードスタイル修正
3. **検証**
   - `flutter analyze`で警告0件を確認
   - `flutter build apk --debug`でビルド成功

---

## ✅ 完了条件

- [ ] 対象3ファイルのlint警告が0件になる
- [ ] `flutter analyze`（新規差分で警告/エラーなし）
- [ ] `flutter build apk --debug` 成功
- [ ] `docs/PROGRESS.md` にLINT-FIX-002完了を追記し、日本語コミット実施

---

## 🔄 完了後の次タスク

このタスク完了後、`docs/NEXT_TASK.md` を次のタスクに更新：

**次のタスク**: TEST-ADD-001: 単体テスト追加

---

## 📚 参考ドキュメント

- `docs/TASK_QUEUE.md` LINT-FIX-002詳細
- 既存修正例: `docs/tasks/LINT-FIX-001.md`

---

## � 開始方法

```
1. flutter analyze で警告内容を確認
2. 各ファイルのlint警告を修正
3. 検証とコミット実施
```

---

## ⚠️ 注意事項

- 既存機能の動作を変更しないこと
- コード品質ルールを遵守すること
- 修正後は必ずビルドテストを実施すること

---

## 📝 完了報告テンプレート

- lint警告修正完了（3ファイル）
- `flutter analyze` 0件確認
- `flutter build` 成功
- 日本語コミット完了
- `docs/PROGRESS.md` へLINT-FIX-002追記済

---

このタスク完了後は、TEST-ADD-001（単体テスト追加）へ移行する。
