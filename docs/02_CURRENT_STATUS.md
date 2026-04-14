# 現在の実装状況

**最終更新**: 2026-04-14

このドキュメントは、販売アシスト1号の現在の実装状況を記録します。

> **注意**: 画面IDの詳細一覧は `SCREEN_IDS.md` を参照してください。このファイルは実コードから自動抽出された画面IDデータベースです。

---

## 📱 実装済み画面一覧（実コードから抽出）

### ⚠️ 重複ID警告（解決済み）
以下の画面IDの重複を解決しました。新規画面追加時はこれらと重複しないように注意してください。

- ✅ `M1`: データベースリストア → `DB`:データベースリストア（解決済み）
- ✅ `WH`: 倉庫ダッシュボード → `WD`:倉庫ダッシュボード（解決済み）
- ✅ `ST`: スタッフ管理 → `SM`:スタッフ管理（解決済み）
- ✅ `S1`: テーマ設定 → `TH`:テーマ設定（解決済み）
- ✅ `S1`: 高速検索 → `FS`:高速検索（解決済み）
- ✅ `P2`: UIパフォーマンス最適化 → `UP`:UIパフォーマンス最適化（解決済み）
- ✅ `C1`: 資金繰り → `CF`:資金繰り（解決済み）
- ✅ `C1`: カスタムフィールド設定 → `CS`:カスタムフィールド設定（解決済み）
- ✅ `A1`: 売上分析 → `SA`:売上分析（解決済み）
- ✅ `A1`: 集計分析 → `AA`:集計分析（解決済み）
- ✅ `A1`: 監査ログ → `AL`:監査ログ（解決済み）
- ✅ `P1`: 粗利分析 → `GP`:粗利分析（解決済み）
- ✅ `P1`: パフォーマンス最適化 → `PO`:パフォーマンス最適化（解決済み）
- ✅ `R1`: 在庫評価額レポート → `IR`:在庫評価額レポート（解決済み）
- ✅ `SD`: フォーク修復 → `FK`:フォーク修復（解決済み）
- ✅ `SD`: Google Drive バックアップ → `GD`:Google Drive バックアップ（解決済み）
- ✅ `SD`: お局様検出設定 → `MD`:お局様検出設定（解決済み）
- ✅ `CH`: 母艦チャット → `MC`:母艦チャット（解決済み）
- ✅ `IV`: 在庫一覧 → `IL`:在庫一覧（解決済み）
- ⚠️ `SM`: メール設定、`S8`:メール設定（機能重複、統合検討中）
- ⚠️ `Q1`: 見積入力、`ES`:見積入力（機能重複、統合検討中）

### 01. マスタ管理

| 画面ID | 画面名 | ファイル | 状態 |
|--------|--------|----------|------|
| WH | 倉庫マスター | `warehouse_master_screen.dart` | ✅ 確認 |
| WD | 倉庫ダッシュボード | `warehouse_dashboard_screen.dart` | ✅ 確認（旧ID: WH） |
| ST | 担当者マスター | `staff_master_screen.dart` | ✅ 確認 |
| SM | スタッフ管理 | `staff_management_screen.dart` | ✅ 確認（旧ID: ST） |
| DB | データベースリストア | `restore_screen.dart` | ✅ 確認（旧ID: M1） |

### 02. 販売管理

| 画面ID | 画面名 | ファイル | 状態 |
|--------|--------|----------|------|
| Q1 | 見積入力 | `quotation_input_screen.dart` | ✅ 確認 |
| ES | 見積入力 | `estimate_input_screen.dart` | ✅ 確認（機能重複） |
| O1 | 受注入力 | `order_input_screen.dart` | ✅ 確認 |
| SA | 売上分析 | `sales_analysis_screen.dart` | ✅ 確認（旧ID: A1） |
| AA | 集計分析 | `analytics_dashboard_screen.dart` | ✅ 確認（旧ID: A1） |
| AL | 監査ログ | `audit_log_screen.dart` | ✅ 確認（旧ID: A1） |
| SA | 売上分析 | `dashboard_screen.dart`（一部） | ✅ 確認 |
| F1 | 販売フロー管理 | `sales_flow_management_screen.dart` | ✅ 確認 |
| P2 | 支払登録 | `payment_register_screen.dart` | ✅ 確認 |
| UP | UIパフォーマンス最適化 | `ui_performance_screen.dart` | ✅ 確認（旧ID: P2） |
| IV | 請求書発行 | `invoice_issue_screen.dart` | ✅ 確認 |
| IL | 在庫一覧 | `inventory_list_screen.dart` | ✅ 確認（旧ID: IV） |

### 03. 在庫管理

| 画面ID | 画面名 | ファイル | 状態 |
|--------|--------|----------|------|
| IQ | 在庫照会 | `stock_inquiry_screen.dart` | ✅ 確認 |
| IM | 在庫移動 | `stock_transfer_screen.dart` | ✅ 確認 |
| IC | 棚卸入力 | `stocktake_input_screen.dart` | ✅ 確認 |
| I1 | 在庫管理 | `inventory_management_screen.dart` | ✅ 確認 |
| I4 | 在庫ロケーション | `inventory_location_screen.dart` | ✅ 確認 |
| I5 | 在庫移動・棚卸 | `inventory_movement_screen.dart` | ✅ 確認 |
| IR | 在庫評価額レポート | `inventory_value_report_screen.dart` | ✅ 確認（旧ID: R1） |

### 04. 集計分析

| 画面ID | 画面名 | ファイル | 状態 |
|--------|--------|----------|------|
| CS | 得意先別売上推移 | `customer_sales_trend_screen.dart` | ✅ 確認 |
| PA | 商品別粗利分析 | `product_profit_analysis_screen.dart` | ✅ 確認 |
| GP | 粗利分析 | `profit_analysis_screen.dart` | ✅ 確認（旧ID: P1） |
| PO | パフォーマンス最適化 | `performance_optimization_screen.dart` | ✅ 確認（旧ID: P1） |
| A2 | 詳細レポート | `report_detail_screen.dart` | ✅ 確認 |

### 05. システム設定

| 画面ID | 画面名 | ファイル | 状態 |
|--------|--------|----------|------|
| TH | テーマ設定 | `screen_s1_theme_selection.dart` | ✅ 確認（旧ID: S1） |
| FS | 高速検索 | `fast_search_screen.dart` | ✅ 確認（旧ID: S1） |
| S8 | メール設定 | `screen_s8_email_settings.dart` | ✅ 確認 |
| SM | メール設定 | `settings_screen.dart`（一部） | ✅ 確認（機能重複） |
| D1 | ダッシュボード | `dashboard_screen.dart` | ✅ 確認 |
| D2 | ダッシュボード設定 | `dashboard_menu_settings_screen.dart` | ✅ 確認 |
| CF | 資金繰り | `cash_flow_screen.dart` | ✅ 確認（旧ID: C1） |
| CS | カスタムフィールド設定 | `custom_field_settings_screen.dart` | ✅ 確認（旧ID: C1） |
| C3 | 表示順序の変更 | `custom_field_reorder_screen.dart` | ✅ 確認 |
| U1 | ユーザー管理 | `user_management_screen.dart` | ✅ 確認 |
| R1 | ロール管理 | `role_management_screen.dart` | ✅ 確認 |
| B1 | 業種設定 | `business_profile_lite_screen.dart` | ✅ 確認 |
| F2 | 自社情報 | `business_profile_screen.dart` | ✅ 確認 |
| S3 | 高度検索 | `advanced_search_screen.dart` | ✅ 確認 |
| S2 | センサー活用 | `sensor_utilization_screen.dart` | ✅ 確認 |
| S4 | 拡張センサー | `enhanced_sensor_screen.dart` | ✅ 確認 |
| T1 | 業種テンプレート選択 | `industry_template_screen.dart` | ✅ 確認 |
| T2 | 業種プレビュー | `template_preview_screen.dart` | ✅ 確認 |

### 06. 電子帳簿保存法

| 画面ID | 画面名 | ファイル | 状態 |
|--------|--------|----------|------|
| E1 | 電子帳簿管理 | `electronic_ledger_management_screen.dart` | ✅ 確認 |
| E2 | 電子帳簿検索 | `electronic_ledger_search_screen.dart` | ✅ 確認 |
| E3 | 電子帳簿設定 | `electronic_ledger_settings_screen.dart` | ✅ 確認 |

### 07. 母艦連携

| 画面ID | 画面名 | ファイル | 状態 |
|--------|--------|----------|------|
| CH | 履歴 | `customer_history_screen.dart` | ✅ 確認 |
| MC | 母艦チャット | `chat_screen.dart` | ✅ 確認（旧ID: CH） |
| FK | フォーク修復 | `screen_debug_fork_break.dart` | ✅ 確認（旧ID: SD） |
| GD | Google Drive バックアップ | `drive_backup_screen.dart` | ✅ 確認（旧ID: SD） |
| MD | お局様検出設定 | `mothership_discovery_settings_screen.dart` | ✅ 確認（旧ID: SD） |
| SB | バックアップ・リストア | `screen_sb_backup_settings.dart` | ✅ 確認 |

**合計**: 50画面以上（実コードから抽出）

---

## 🗄️ データベーステーブル一覧

### マスタテーブル

| テーブル名 | 用途 | 主要カラム |
|-----------|------|-----------|
| `customers` | 顧客マスタ | id, display_name, formal_name, title, department |
| `products` | 商品マスタ | id, name, unit_price, cost, barcode, category |
| `suppliers` | 仕入先マスタ | id, name, contact_person, tel, email |
| `warehouses` | 倉庫マスタ | id, name, location, latitude, longitude |
| `staff` | 担当者マスタ | id, name, email, role |
| `company_info` | 会社情報 | id, name, address, tel, email, seal_path |

### 伝票テーブル

| テーブル名 | 用途 | 主要カラム |
|-----------|------|-----------|
| `invoices` | 請求書・伝票 | id, invoice_number, date, customer_id, total, status |
| `invoice_items` | 伝票明細 | id, invoice_id, product_id, quantity, unit_price |
| `quotations` | 見積 | id, document_number, date, customer_id, total, status |
| `quotation_items` | 見積明細 | id, quotation_id, product_id, quantity, unit_price |
| `sales` | 売上 | id, document_number, date, customer_id, total, status |
| `sales_items` | 売上明細 | id, sales_id, product_id, quantity, unit_price |

### 在庫テーブル

| テーブル名 | 用途 | 主要カラム |
|-----------|------|-----------|
| `warehouse_stock` | 倉庫別在庫 | id, warehouse_id, product_id, quantity |
| `stock_transfers` | 在庫移動 | id, from_warehouse_id, to_warehouse_id, product_id, quantity |

### 仕入テーブル

| テーブル名 | 用途 | 主要カラム |
|-----------|------|-----------|
| `purchase_entries` | 仕入入力 | id, entry_date, supplier_id, total_amount |
| `purchase_receipts` | 支払予定 | id, supplier_id, amount, due_date, status |

### システムテーブル

| テーブル名 | 用途 | 主要カラム |
|-----------|------|-----------|
| `app_settings` | アプリ設定 | key, value |
| `app_gps_history` | GPS履歴 | id, latitude, longitude, timestamp |
| `chat_messages` | チャットメッセージ | id, message_id, body, created_at |
| `activity_log` | アクティビティログ | id, action, entity_type, entity_id, timestamp |

**データベースバージョン**: 33

---

## 🔧 実装済み機能

### コア機能

✅ **オフラインファースト設計**
- SQLiteによる完全なローカルデータ保存
- ネットワーク不要で全業務完結

✅ **汎用テンプレートシステム**
- `GenericListScreen<T>` - 150行で完全なリスト画面
- `DocumentCard` - 伝票カード表示
- `BaseDocument` - 共通伝票モデル

✅ **PDF生成・送信**
- 見積・納品・請求・領収書のPDF生成
- SMTP/デバイスメーラー両対応
- BCC自動送信

### 外部連携

✅ **Google連携（オプション）**
- Google Sign-In
- Google Drive自動バックアップ
- Gmail同期（チャット・伝票）

✅ **母艦「お局様」連携**
- LAN直接通信
- Gmail経由同期
- GPS位置ベース自動切り替え
- チャット機能

### モバイル機能

✅ **GPS機能**
- 位置情報記録
- 顧客訪問記録
- 母艦自動検出

✅ **バーコードスキャン**
- 商品検索
- 在庫照会

✅ **カメラ連携**
- 商品写真撮影
- バーコードスキャン

### データ管理

✅ **バックアップ・リストア**
- Google Drive自動バックアップ（24時間ごと）
- 手動バックアップ
- 初回起動時リストア提案

✅ **同期機能**
- Gmail同期（エンベロープ形式）
- LAN直接同期
- 自動切り替え

---

## 📊 実装状況サマリー

### 画面実装率

| カテゴリ | 実装済み | 合計 | 達成率 |
|---------|---------|------|--------|
| マスタ管理 | 6 | 6 | 100% |
| 販売管理 | 7 | 7 | 100% |
| 仕入管理 | 2 | 2 | 100% |
| 在庫管理 | 4 | 4 | 100% |
| 集計分析 | 3 | 3 | 100% |
| システム設定 | 5 | 5 | 100% |
| 母艦連携 | 3 | 3 | 100% |
| その他 | 4 | 4 | 100% |
| **合計** | **34** | **34** | **100%** |

### 機能実装率

| 機能カテゴリ | 状態 |
|-------------|------|
| 基本販売管理 | ✅ 100% |
| PDF生成・送信 | ✅ 100% |
| マスタ管理 | ✅ 100% |
| 在庫管理 | ✅ 100% |
| 集計分析 | ✅ 100% |
| Google連携 | ✅ 100% |
| 母艦連携 | ✅ 100% |
| バックアップ | ✅ 100% |

---

## 🚧 未実装機能

### 計画中の機能

以下の機能は設計済みですが、未実装です：

1. **業種カスタマイズ機能**
   - 業種プロファイル設定
   - カスタムフィールド機能
   - 業種別テンプレート

2. **電子帳簿保存法対応**
   - イベントソーシング
   - ハッシュチェーン
   - 検索機能強化
   - 7年保存管理

3. **スマホ性能活用機能**
   - マルチスレッド処理（Isolate）
   - 高速検索（FTS）
   - リアルタイム分析
   - 音声メモ機能

詳細は `docs/05_FUTURE_PLANS.md` を参照してください。

---

## 📝 技術スタック

### フレームワーク・言語
- Flutter 3.x
- Dart

### データベース
- SQLite (`sqflite`)
- データベース名: `gemi_invoice.db`
- バージョン: 33

### 主要パッケージ
- `pdf` / `printing` - PDF生成
- `mailer` - SMTP送信
- `google_sign_in` - Google認証
- `googleapis` - Google API
- `mobile_scanner` - バーコードスキャン
- `geolocator` - GPS位置情報
- `image_picker` - カメラ・写真

### アーキテクチャ
- リポジトリパターン
- StatefulWidget + setState
- 汎用テンプレートシステム

---

## 🔄 最近の主要変更

### 2026-03-07
- ✅ 汎用販売管理システム完成
- ✅ Q1:見積入力、A1:売上入力、SR1:売上返品入力を実装
- ✅ GenericListScreen テンプレート活用
- ✅ 各画面を150行程度で実装完了

### 2026-03-06
- ✅ 在庫移動機能実装
- ✅ 棚卸入力画面作成
- ✅ 請求書発行機能実装

### 2026-03-05
- ✅ Google Drive自動バックアップ実装
- ✅ BCC設定UI改善
- ✅ Gmail同期機能強化

---

## 📈 コード統計

### 画面数
- 合計: 40画面以上

### コード行数（推定）
- `lib/screens/`: 約30,000行
- `lib/services/`: 約15,000行
- `lib/models/`: 約5,000行
- `lib/widgets/`: 約3,000行
- **合計**: 約53,000行

### テスト
- ✅ `flutter analyze` でエラー0件
- ✅ `flutter test` で全テスト通過

---

このドキュメントは実装状況の変化に応じて随時更新されます。
