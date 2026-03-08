# 次のタスク

**最終更新**: 2026-03-08 20:10

---

## 🎯 今すぐ実行するタスク

### タスクID: LINT-FIX-002
**優先度**: 🔴 高  
**担当**: SWE1.5  
**推定時間**: 30分  
**状態**: ⏳ 待機中

---

## 📝 タスク概要

残りのlint警告を修正する（StatefulWidget変換とmountedチェック追加）

### 背景
`quotation_input_screen.dart` で実施したのと同じパターンで、残り3つの画面ファイルを修正します。lint警告は「StatelessWidgetのbuildメソッド内で非同期処理後にcontextを使用している」というもので、StatefulWidgetに変換して`mounted`チェックを追加することで解決します。

---

## 🎯 対象ファイル

1. `lib/screens/order_input_screen.dart` - 受注入力画面
2. `lib/screens/sales_entry_screen.dart` - 売上入力画面
3. `lib/screens/sales_return_input_screen.dart` - 売上返品入力画面

---

## 📋 実行手順

詳細な手順は以下のファイルを参照してください：

👉 **`docs/tasks/LINT-FIX-002.md`**

### 概要
1. 各ファイルをStatefulWidgetに変換
2. 非同期処理後のUI更新前に`if (!mounted) return;`を追加
3. `flutter analyze`でエラー0件を確認
4. `docs/PROGRESS.md`に完了報告

---

## ✅ 完了条件

- [ ] `order_input_screen.dart` をStatefulWidgetに変換
- [ ] `sales_entry_screen.dart` をStatefulWidgetに変換
- [ ] `sales_return_input_screen.dart` をStatefulWidgetに変換
- [ ] すべてのファイルでmountedチェックを適切に追加
- [ ] `flutter analyze` エラー0件
- [ ] `docs/PROGRESS.md` に完了報告を追記

---

## 🔄 完了後の次タスク

このタスク完了後、`docs/NEXT_TASK.md` を以下に更新してください：

**次のタスク**: TEST-ADD-001（単体テスト追加）

---

## 📚 参考ドキュメント

### 必須
- **タスク詳細**: `docs/tasks/LINT-FIX-002.md`
- **完了済み参考**: `lib/screens/quotation_input_screen.dart`

### 補足
- **コーディング規約**: `docs/CODING_GUIDE.md`
- **進捗ログ**: `docs/PROGRESS.md`
- **自動進行ルール**: `docs/AUTO_PROGRESS.md`

---

## 🚀 開始方法

SWE1.5は以下のコマンドで開始してください：

```
タスクLINT-FIX-002を開始します。
docs/tasks/LINT-FIX-002.md を確認して実行します。
```

---

## ⚠️ 注意事項

- **パターンの一貫性**: `quotation_input_screen.dart`と同じパターンを適用
- **mountedチェックの位置**: 非同期処理（await）の直後、UI更新の直前
- **context.mounted vs mounted**: StatefulWidgetでは`mounted`プロパティを使用
- **質問禁止**: パターンは確立済み、ドキュメントを参照して自己解決

---

このタスクを完了したら、必ず `docs/PROGRESS.md` に報告してください。
