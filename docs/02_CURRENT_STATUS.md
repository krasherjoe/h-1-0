# 現在の実装状況

**最終更新**: 2026-03-07

このドキュメントは、販売アシスト1号の現在の実装状況を記録します。

---

## 📱 実装済み画面一覧

### 01. マスタ管理

| 画面ID | 画面名 | ファイル | 状態 |
|--------|--------|----------|------|
| P1 | 商品マスター | `product_master_screen.dart` | ✅ 完成 |
| C1 | 得意先マスター | `customer_master_screen.dart` | ✅ 完成 |
| SI | 仕入先マスター | `supplier_master_screen.dart` | ✅ 完成 |
| WH | 倉庫マスター | `warehouse_master_screen.dart` | ✅ 完成 |
| ST | 担当者マスター | `staff_master_screen.dart` | ✅ 完成 |
| M1 | マスター管理ハブ | `master_hub_page.dart` | ✅ 完成 |

### 02. 販売管理

| 画面ID | 画面名 | ファイル | 状態 |
|--------|--------|----------|------|
| Q1 | 見積入力 | `quotation_input_screen.dart` | ✅ 完成 |
| O1 | 受注入力 | `order_input_screen.dart` | ✅ 完成 |
| A1 | 売上入力 | `sales_entry_screen.dart` | ✅ 完成 |
| SR1 | 売上返品入力 | `sales_return_input_screen.dart` | ✅ 完成 |
| INV1 | 請求書発行 | `invoice_issue_screen.dart` | ✅ 完成 |
| DOC1 | 伝票入力 | `invoice_input_screen.dart` | ✅ 完成 |
| A2 | 伝票一覧 | `invoice_history_screen.dart` | ✅ 完成 |

### 03. 仕入管理

| 画面ID | 画面名 | ファイル | 状態 |
|--------|--------|----------|------|
| U2 | 仕入入力 | `purchase_entries_screen.dart` | ✅ 完成 |
| - | 支払予定管理 | `purchase_receipts_screen.dart` | ✅ 完成 |

### 04. 在庫管理

| 画面ID | 画面名 | ファイル | 状態 |
|--------|--------|----------|------|
| IQ | 在庫照会 | `stock_inquiry_screen.dart` | ✅ 完成 |
| IM | 在庫移動 | `stock_transfer_screen.dart` | ✅ 完成 |
| IC | 棚卸入力 | `stocktake_input_screen.dart` | ✅ 完成 |
| WH | 倉庫ダッシュボード | `warehouse_dashboard_screen.dart` | ✅ 完成 |

### 05. 集計分析

| 画面ID | 画面名 | ファイル | 状態 |
|--------|--------|----------|------|
| - | 売上日報 | `sales_report_screen.dart` | ✅ 完成 |
| CS | 得意先別売上推移 | `customer_sales_trend_screen.dart` | ✅ 完成 |
| PA | 商品別粗利分析 | `product_profit_analysis_screen.dart` | ✅ 完成 |

### 06. システム設定

| 画面ID | 画面名 | ファイル | 状態 |
|--------|--------|----------|------|
| S1 | 設定 | `settings_screen.dart` | ✅ 完成 |
| SM | メール設定 | `email_settings_screen.dart` | ✅ 完成 |
| D2 | ダッシュボード設定 | `dashboard_menu_settings_screen.dart` | ✅ 完成 |
| - | 事業プロフィール | `business_profile_screen.dart` | ✅ 完成 |
| - | 会社情報 | `company_info_screen.dart` | ✅ 完成 |

### 07. 母艦連携

| 画面ID | 画面名 | ファイル | 状態 |
|--------|--------|----------|------|
| CH | 母艦チャット | `chat_screen.dart` | ✅ 完成 |
| - | お局様検出設定 | `mothership_discovery_settings_screen.dart` | ✅ 完成 |
| - | 管理画面 | `management_screen.dart` | ✅ 完成 |

### 08. その他

| 画面ID | 画面名 | ファイル | 状態 |
|--------|--------|----------|------|
| SUP | サポート窓口 | `support_desk_screen.dart` | ✅ 完成 |
| - | バーコードスキャン | `barcode_scanner_screen.dart` | ✅ 完成 |
| - | GPS履歴 | `gps_history_screen.dart` | ✅ 完成 |
| - | アクティビティログ | `activity_log_screen.dart` | ✅ 完成 |

**合計**: 40画面以上

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
