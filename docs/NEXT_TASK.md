# 次のタスク

**最終更新**: 2026-03-08 21:37

---

## 🎯 今すぐ実行するタスク

### タスクID: STAGE-III
**優先度**: 🔴 高  
**担当**: SWE1.5  
**推定時間**: 6時間  
**状態**: ⏳ 待機中

---

## 📝 タスク概要

集計分析モジュールを実装する。売上・仕入・在庫などの各種データを横断的に集計し、ダッシュボードやレポートで可視化することで経営判断を支援する。

### 背景
購買・販売・在庫の基本機能は揃ったが、経営層が必要とする横断的な集計・分析機能が不足している。集計分析モジュールを実装し、売上状況や在庫回転率などを可視化することで意思決定を支援する。

---

## 🎯 対象ファイル

### モデル／サービス
1. `lib/models/analytics_summary_model.dart` - 集計結果モデル（新規）
2. `lib/services/analytics_repository.dart` - 集計ロジック（新規）

### 画面
1. `lib/screens/analytics_dashboard_screen.dart` - 集計ダッシュボード（新規）
2. `lib/screens/report_detail_screen.dart` - 詳細レポート画面（新規）

### メニュー・ルーティング
1. `lib/constants/menu_catalog.dart` - 集計メニュー追加
2. `lib/screens/dashboard_screen.dart` - ルーティング追加

---

## 📋 実行手順

詳細な手順は以下のファイルを参照してください：

👉 **`docs/tasks/STAGE-III.md`**

### 概要
1. 集計モデルとリポジトリを実装
2. 集計ダッシュボード画面を実装
3. 詳細レポート画面を実装
4. メニューとルーティングを更新
5. グラフ・チャートウィジェットを実装
6. `flutter analyze` と `flutter test` で確認

---

## ✅ 完了条件

- [ ] 集計用モデルとリポジトリの実装
- [ ] 集計ダッシュボード画面の実装
- [ ] 詳細レポート画面の実装
- [ ] グラフ・チャート表示の実装
- [ ] メニューとルーティングの更新
- [ ] `flutter analyze` エラー0件
- [ ] `flutter test` すべてパス
- [ ] `docs/PROGRESS.md` に完了報告を追記

---

## 🔄 完了後の次タスク

このタスク完了後、`docs/NEXT_TASK.md` を次のタスクに更新：

**次のタスク**: STAGE-IV（TBD）

---

## 📚 参考ドキュメント

### 必須
- **タスク詳細**: `docs/tasks/STAGE-III.md`
- **既存実装参考**: `lib/screens/cash_flow_screen.dart`
- **既存実装参考**: `lib/widgets/analytics_chart.dart`（新規）

### 補足
- **コーディング規約**: `docs/CODING_GUIDE.md`
- **進捗ログ**: `docs/PROGRESS.md`
- **自動進行ルール**: `docs/AUTO_PROGRESS.md`
- **クイックリファレンス**: `docs/QUICK_REF.md`

---

## 🚀 開始方法

SWE1.5は以下のコマンドで開始してください：

```
タスクSTAGE-IIIを開始します。
docs/tasks/STAGE-III.md を確認して実行します。
```

---

## ⚠️ 注意事項

- **画面IDのルール**: すべての画面タイトルはユニークな2文字IDから開始（例: A1:集計ダッシュボード）
- **StatefulWidget変換**: 非同期処理を含む画面はStatefulWidgetに変換しmountedチェックを追加
- **データベース整合性**: 支払データと仕入データの連携を適切に実装
- **既存パターンの活用**: 仕入管理や顧客管理の実装パターンを参考にする
- **質問禁止**: 実装パターンは確立済み、ドキュメントを参照して自己解決

---

このタスクを完了したら、必ず `docs/PROGRESS.md` に報告してください。
