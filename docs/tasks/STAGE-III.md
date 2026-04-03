# STAGE-III: 集計分析モジュール

**タスクID**: STAGE-III  
**優先度**: 🔴 高  
**担当**: SWE1.5  
**推定時間**: 6時間  
**作成日**: 2026-03-08

---

## 📝 タスク概要

販売・仕入・在庫など各モジュールのデータを集計し、ダッシュボードやレポート画面で可視化できるようにする。経営層が日次／月次の数値を素早く把握できることが目標。

### 背景
STAGE-I/IIで購買モジュールが完成したが、全体のKPIを俯瞰する機能が不足している。集計分析モジュールでは、売上推移、仕入推移、在庫回転率などを可視化し、資金繰りや生産計画に活かせるレポートを提供する。

---

## ✅ 前提条件確認

- [x] 売上・仕入・在庫データが取得できること
- [x] `DatabaseHelper` に集計用のビュー／SQLを追加できること
- [x] 画面IDルールを遵守していること
- [ ] グラフ描画ライブラリ（Flutter標準ウィジェット＋自前コンポーネント）の設計方針が整理済みであること

---

## 🎯 対象ファイル

### モデル
1. `lib/models/analytics_summary_model.dart`
2. `lib/models/analytics_metric_model.dart`

### サービス／リポジトリ
1. `lib/services/analytics_repository.dart`
2. `lib/services/analytics_cache_service.dart`（必要に応じて）

### 画面
1. `lib/screens/analytics_dashboard_screen.dart`
2. `lib/screens/report_detail_screen.dart`

### ウィジェット
1. `lib/widgets/analytics_chart.dart`
2. `lib/widgets/metric_card.dart`

### メニュー・設定
1. `lib/constants/menu_catalog.dart`
2. `lib/screens/dashboard_screen.dart`
3. `lib/config/app_config.dart`

### ドキュメント
1. `docs/NEXT_TASK.md`
2. `docs/PROGRESS.md`

---

## 📋 実行手順

### Step 1: 集計モデルの実装

`analytics_summary_model.dart` に以下を定義：
- 期間・カテゴリー別の売上／仕入／在庫指標
- JSON/Map 変換、`copyWith`, 表示用フォーマッタ

`analytics_metric_model.dart` に単一指標（例: 売上合計、前年比）の構造体を定義し、`MetricType` 列挙を持たせる。

### Step 2: 集計リポジトリの実装

`analytics_repository.dart` で SQL 集計を実装：
- `Future<AnalyticsSummary> fetchDailySummary(DateTime date)`
- `Future<List<AnalyticsMetric>> fetchMonthlyTrends({required MetricType type, int months = 6})`
- `Future<List<AnalyticsMetric>> fetchTopSuppliers({int limit = 5})`
- `Future<List<AnalyticsMetric>> fetchTopCustomers({int limit = 5})`

必要に応じてキャッシュ層を用意（`analytics_cache_service.dart`）。

### Step 3: グラフ・カードウィジェットの実装

- `AnalyticsChart`：折れ線／棒グラフ切替、アニメーション表示
- `MetricCard`：アイコン、タイトル、数値、前年比/差分バッジを表示

### Step 4: 集計ダッシュボード画面

`analytics_dashboard_screen.dart`
- 画面ID: `A1:集計分析`
- `GenericListScreen` 相当のレイアウトでダッシュボードを構築
- KPIカード、トレンドチャート、トップ仕入先／顧客セクション
- 詳細レポート画面へのナビゲーションボタン

### Step 5: 詳細レポート画面

`report_detail_screen.dart`
- 画面ID: `A2:詳細レポート`
- 期間フィルタ、カテゴリフィルタ
- テーブル表示＋エクスポート（CSVダミー）ボタン

### Step 6: メニュー・ルーティング更新

- `menu_catalog.dart` に集計メニューを追加（ID: `analytics_dashboard`, `analytics_report`）
- `dashboard_screen.dart` にルーティング追加
- `AppConfig.enableAnalyticsModule` を参照し、メニュー表示制御

### Step 7: DatabaseHelper 更新

- 集計に必要なビュー／インデックスを追加
- 例: `CREATE VIEW sales_with_purchase AS ...`
- バージョン番号を +1

### Step 8: 動作確認

1. `flutter analyze`
2. `flutter test`
3. `flutter build apk --debug`
4. 成功後、日本語で `git commit`

### Step 9: ドキュメント更新

- `docs/PROGRESS.md` に STAGE-III 完了ログ
- `docs/NEXT_TASK.md` を次タスク（STAGE-IV）に更新

---

## ✅ 完了条件

- [ ] 集計モデル／リポジトリ実装
- [ ] グラフ・カードウィジェット実装
- [ ] 集計ダッシュボード画面
- [ ] 詳細レポート画面
- [ ] メニュー＆ルーティング更新
- [ ] DBスキーマ更新（バージョン+1）
- [ ] `flutter analyze` エラー0件
- [ ] `flutter test` すべてパス
- [ ] `flutter build apk --debug` 成功
- [ ] 日本語で `git commit`
- [ ] `docs/PROGRESS.md` 更新
- [ ] `docs/NEXT_TASK.md` 更新

---

## 🔧 トラブルシューティング

| 事象 | 原因 | 対処 |
| --- | --- | --- |
| グラフが描画されない | データ形式不正 | 日付順にソートし、`DateTime` → `double` 変換を確認 |
| SQL 集計が遅い | インデックス不足 | 必要な列へインデックス追加 |
| 画面ID重複 | QUICK_REF未参照 | `docs/QUICK_REF.md` でID確認 |

---

## 📚 参考資料

- `lib/screens/cash_flow_screen.dart`（カード／チャート構成参考）
- `lib/widgets/document_card.dart`（カードデザイン参考）
- `docs/CODING_GUIDE.md`
- `docs/QUICK_REF.md`

---

## 🔄 次のタスク

完了後は `docs/NEXT_TASK.md` を STAGE-IV（TBD）に更新する。
