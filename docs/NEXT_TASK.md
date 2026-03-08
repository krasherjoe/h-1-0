# 次のタスク

**最終更新**: 2026-03-08 21:37

---

## 🎯 今すぐ実行するタスク

### タスクID: STAGE-II
**優先度**: 🔴 高  
**担当**: SWE1.5  
**推定時間**: 6時間  
**状態**: ⏳ 待機中

---

## 📝 タスク概要

支払管理モジュールを完成させる。支払予定管理、支払実績登録、支払消込、資金繰り表の各機能を実装し、仕入先への支払業務を完全に自動化する。

### 背景
STAGE-Iで仕入モジュールを実装完了したが、支払管理機能が未実装のため、仕入先への支払状況を把握できない。支払管理モジュールを実装することで、仕入から支払までの完全な購買管理サイクルを完成させる。

---

## 🎯 対象ファイル

### 支払モデル
1. `lib/models/payment_model.dart` - 支払モデル（新規作成）
2. `lib/models/payment_schedule_model.dart` - 支払予定モデル（新規作成）

### 支払リポジトリ
1. `lib/services/payment_repository.dart` - 支払リポジトリ（新規作成）
2. `lib/services/payment_schedule_repository.dart` - 支払予定リポジトリ（新規作成）

### 支払画面
1. `lib/screens/payment_schedule_screen.dart` - 支払予定一覧画面（新規作成）
2. `lib/screens/payment_register_screen.dart` - 支払実績登録画面（新規作成）
3. `lib/screens/cash_flow_screen.dart` - 資金繰り表画面（新規作成）

### メニュー更新
1. `lib/constants/menu_catalog.dart` - メニューカタログに支払関連を追加

---

## 📋 実行手順

詳細な手順は以下のファイルを参照してください：

👉 **`docs/tasks/STAGE-II.md`**

### 概要
1. 支払モデルと支払予定モデルを実装
2. 支払リポジトリと支払予定リポジトリを実装
3. 支払予定一覧画面を実装
4. 支払実績登録画面を実装
5. 資金繰り表画面を実装
6. メニューに支払関連項目を追加
7. データベーススキーマを更新
8. `flutter analyze` と `flutter test` で確認

---

## ✅ 完了条件

- [ ] 支払モデルと支払予定モデルの実装
- [ ] 支払リポジトリと支払予定リポジトリの実装
- [ ] 支払予定一覧画面の実装
- [ ] 支払実績登録画面の実装
- [ ] 資金繰り表画面の実装
- [ ] メニューに支払関連項目を追加
- [ ] データベーススキーマの更新
- [ ] `flutter analyze` エラー0件
- [ ] `flutter test` すべてパス
- [ ] `docs/PROGRESS.md` に完了報告を追記

---

## 🔄 完了後の次タスク

このタスク完了後、`docs/NEXT_TASK.md` を次のタスクに更新：

**次のタスク**: STAGE-III（集計分析モジュール）

---

## 📚 参考ドキュメント

### 必須
- **タスク詳細**: `docs/tasks/STAGE-II.md`
- **既存実装参考**: `lib/models/purchase_model.dart`
- **既存実装参考**: `lib/models/supplier_model.dart`

### 補足
- **コーディング規約**: `docs/CODING_GUIDE.md`
- **進捗ログ**: `docs/PROGRESS.md`
- **自動進行ルール**: `docs/AUTO_PROGRESS.md`
- **クイックリファレンス**: `docs/QUICK_REF.md`

---

## 🚀 開始方法

SWE1.5は以下のコマンドで開始してください：

```
タスクSTAGE-IIを開始します。
docs/tasks/STAGE-II.md を確認して実行します。
```

---

## ⚠️ 注意事項

- **画面IDのルール**: すべての画面タイトルはユニークな2文字IDから開始（例: P1:支払予定）
- **StatefulWidget変換**: 非同期処理を含む画面はStatefulWidgetに変換しmountedチェックを追加
- **データベース整合性**: 支払データと仕入データの連携を適切に実装
- **既存パターンの活用**: 仕入管理や顧客管理の実装パターンを参考にする
- **質問禁止**: 実装パターンは確立済み、ドキュメントを参照して自己解決

---

このタスクを完了したら、必ず `docs/PROGRESS.md` に報告してください。
