# 画面ID管理データベース
# AIセッション開始時に必ず読み込んでください
# 最終更新: 2026-04-14

---
# 画面ID定義ルール
rules:
  format: "XX:画面名"
  length: "2文字（英大文字+数字）"
  unique: true
  duplicate_check: "新規追加時は必ず既存IDと重複しないことを確認"
  category: "カテゴリ別に整理（マスタ管理、販売管理、仕入管理、在庫管理、集計分析、システム設定、母艦連携、その他）"

---
# 画面ID一覧（実ファイルから抽出）
screen_ids:
  # マスタ管理
  P1:
    name: 商品マスター
    file: lib/screens/product_master_screen.dart
    status: 推定（ファイル未確認）
    category: マスタ管理
  C1:
    name: 得意先マスター
    file: lib/screens/customer_master_screen.dart
    status: 推定（ファイル未確認）
    category: マスタ管理
  SI:
    name: 仕入先マスター
    file: lib/screens/supplier_master_screen.dart
    status: 推定（ファイル未確認）
    category: マスタ管理
  WH:
    name: 倉庫マスター
    file: lib/screens/warehouse_master_screen.dart
    status: 確認
    category: マスタ管理
  WH_DASH:
    name: 倉庫ダッシュボード
    file: lib/screens/warehouse_dashboard_screen.dart
    status: 確認
    note: "WHと重複ID"
    category: マスタ管理
  ST:
    name: 担当者マスター
    file: lib/screens/staff_master_screen.dart
    status: 確認
    category: マスタ管理
  ST_MGMT:
    name: スタッフ管理
    file: lib/screens/staff_management_screen.dart
    status: 確認
    note: "STと重複ID"
    category: マスタ管理
  M1:
    name: マスター管理ハブ
    file: lib/screens/settings_screen.dart（一部）
    status: 確認
    note: "restore_screen.dartでもM1:データベースリストアとして使用（重複ID）"
    category: マスタ管理

  # 販売管理
  Q1:
    name: 見積入力
    file: lib/screens/quotation_input_screen.dart
    status: 確認
    category: 販売管理
  ES:
    name: 見積入力
    file: lib/screens/estimate_input_screen.dart
    status: 確認
    note: "Q1と重複ID"
    category: 販売管理
  O1:
    name: 受注入力
    file: lib/screens/order_input_screen.dart
    status: 確認
    category: 販売管理
  A1_SALES:
    name: 売上分析
    file: lib/screens/sales_analysis_screen.dart
    status: 確認
    note: "他のA1と重複ID"
    category: 販売管理
  A1_ANALYTICS:
    name: 集計分析
    file: lib/screens/analytics_dashboard_screen.dart
    status: 確認
    note: "他のA1と重複ID"
    category: 販売管理
  A1_AUDIT:
    name: 監査ログ
    file: lib/screens/audit_log_screen.dart
    status: 確認
    note: "他のA1と重複ID"
    category: 販売管理
  SA:
    name: 売上分析
    file: lib/screens/dashboard_screen.dart（一部）
    status: 確認
    category: 販売管理
  F1:
    name: 販売フロー管理
    file: lib/screens/sales_flow_management_screen.dart
    status: 確認
    category: 販売管理
  P2_PAY:
    name: 支払登録
    file: lib/screens/payment_register_screen.dart
    status: 確認
    category: 販売管理
  P2_UI:
    name: UIパフォーマンス最適化
    file: lib/screens/ui_performance_screen.dart
    status: 確認
    note: "P2_PAYと重複ID"
    category: 販売管理
  IV_INV:
    name: 請求書発行
    file: lib/screens/invoice_issue_screen.dart
    status: 確認
    category: 販売管理
  IV_INV_LIST:
    name: 在庫一覧
    file: lib/screens/inventory_list_screen.dart
    status: 確認
    note: "IV_INVと重複ID"
    category: 販売管理

  # 仕入管理
  U2:
    name: 仕入入力
    file: lib/screens/purchase_entries_screen.dart
    status: 推定（ファイル未確認）
    category: 仕入管理

  # 在庫管理
  IQ:
    name: 在庫照会
    file: lib/screens/stock_inquiry_screen.dart
    status: 確認
    category: 在庫管理
  IM:
    name: 在庫移動
    file: lib/screens/stock_transfer_screen.dart
    status: 確認
    category: 在庫管理
  IC:
    name: 棚卸入力
    file: lib/screens/stocktake_input_screen.dart
    status: 確認
    category: 在庫管理
  I1:
    name: 在庫管理
    file: lib/screens/inventory_management_screen.dart
    status: 確認
    category: 在庫管理
  I4:
    name: 在庫ロケーション
    file: lib/screens/inventory_location_screen.dart
    status: 確認
    category: 在庫管理
  I5:
    name: 在庫移動・棚卸
    file: lib/screens/inventory_movement_screen.dart
    status: 確認
    category: 在庫管理
  R1_INV:
    name: 在庫評価額レポート
    file: lib/screens/inventory_value_report_screen.dart
    status: 確認
    note: "他のR1と重複ID"
    category: 在庫管理

  # 集計分析
  CS:
    name: 得意先別売上推移
    file: lib/screens/customer_sales_trend_screen.dart
    status: 確認
    category: 集計分析
  PA:
    name: 商品別粗利分析
    file: lib/screens/product_profit_analysis_screen.dart
    status: 確認
    category: 集計分析
  P1_PROFIT:
    name: 粗利分析
    file: lib/screens/profit_analysis_screen.dart
    status: 確認
    note: "他のP1と重複ID"
    category: 集計分析
  P1_PERF:
    name: パフォーマンス最適化
    file: lib/screens/performance_optimization_screen.dart
    status: 確認
    note: "他のP1と重複ID"
    category: 集計分析
  A2:
    name: 詳細レポート
    file: lib/screens/report_detail_screen.dart
    status: 確認
    category: 集計分析

  # システム設定
  S1_THEME:
    name: テーマ設定
    file: lib/screens/screen_s1_theme_selection.dart
    status: 確認
    note: "他のS1と重複ID"
    category: システム設定
  S1_SEARCH:
    name: 高速検索
    file: lib/screens/fast_search_screen.dart
    status: 確認
    note: "他のS1と重複ID"
    category: システム設定
  S8:
    name: メール設定
    file: lib/screens/screen_s8_email_settings.dart
    status: 確認
    category: システム設定
  SM:
    name: メール設定
    file: lib/screens/settings_screen.dart（一部）
    status: 確認
    note: "S8と重複ID"
    category: システム設定
  D1:
    name: ダッシュボード
    file: lib/screens/dashboard_screen.dart
    status: 確認
    category: システム設定
  D2:
    name: ダッシュボード設定
    file: lib/screens/dashboard_menu_settings_screen.dart
    status: 確認
    category: システム設定
  C1_CASH:
    name: 資金繰り
    file: lib/screens/cash_flow_screen.dart
    status: 確認
    note: "他のC1と重複ID"
    category: システム設定
  C1_CUSTOM:
    name: カスタムフィールド設定
    file: lib/screens/custom_field_settings_screen.dart
    status: 確認
    note: "他のC1と重複ID"
    category: システム設定
  C3:
    name: 表示順序の変更
    file: lib/screens/custom_field_reorder_screen.dart
    status: 確認
    category: システム設定
  U1:
    name: ユーザー管理
    file: lib/screens/user_management_screen.dart
    status: 確認
    category: システム設定
  R1_ROLE:
    name: ロール管理
    file: lib/screens/role_management_screen.dart
    status: 確認
    note: "他のR1と重複ID"
    category: システム設定
  B1:
    name: 業種設定
    file: lib/screens/business_profile_lite_screen.dart
    status: 確認
    category: システム設定
  F2:
    name: 自社情報
    file: lib/screens/business_profile_screen.dart
    status: 確認
    category: システム設定
  S3:
    name: 高度検索
    file: lib/screens/advanced_search_screen.dart
    status: 確認
    category: システム設定
  S2:
    name: センサー活用
    file: lib/screens/sensor_utilization_screen.dart
    status: 確認
    category: システム設定
  S4:
    name: 拡張センサー
    file: lib/screens/enhanced_sensor_screen.dart
    status: 確認
    category: システム設定
  T1:
    name: 業種テンプレート選択
    file: lib/screens/industry_template_screen.dart
    status: 確認
    category: システム設定
  T2:
    name: 業種プレビュー
    file: lib/screens/template_preview_screen.dart
    status: 確認
    category: システム設定

  # 電子帳簿保存法
  E1:
    name: 電子帳簿管理
    file: lib/screens/electronic_ledger_management_screen.dart
    status: 確認
    category: 電子帳簿保存法
  E2:
    name: 電子帳簿検索
    file: lib/screens/electronic_ledger_search_screen.dart
    status: 確認
    category: 電子帳簿保存法
  E3:
    name: 電子帳簿設定
    file: lib/screens/electronic_ledger_settings_screen.dart
    status: 確認
    category: 電子帳簿保存法

  # 母艦連携
  CH_HIST:
    name: 履歴
    file: lib/screens/customer_history_screen.dart
    status: 確認
    note: "CHと重複ID"
    category: 母艦連携
  CH_CHAT:
    name: 母艦チャット
    file: lib/screens/chat_screen.dart
    status: 確認
    note: "CH_HISTと重複ID"
    category: 母艦連携
  SD_FORK:
    name: フォーク修復 - HASH チェーン管理
    file: lib/screens/screen_debug_fork_break.dart
    status: 確認
    note: "他のSDと重複ID"
    category: 母艦連携
  SD_DRIVE:
    name: Google Drive バックアップ
    file: lib/screens/drive_backup_screen.dart
    status: 確認
    note: "他のSDと重複ID"
    category: 母艦連携
  SD_DISCOVERY:
    name: お局様検出設定
    file: lib/screens/mothership_discovery_settings_screen.dart
    status: 確認
    note: "他のSDと重複ID"
    category: 母艦連携
  SB:
    name: バックアップ・リストア
    file: lib/screens/screen_sb_backup_settings.dart
    status: 確認
    category: 母艦連携

  # その他
  SUP:
    name: サポート窓口
    file: lib/screens/support_desk_screen.dart
    status: 推定（ファイル未確認）
    category: その他
  BARCODE:
    name: バーコードスキャン
    file: lib/screens/barcode_scanner_screen.dart
    status: 推定（ファイル未確認）
    category: その他
  GPS:
    name: GPS履歴
    file: lib/screens/gps_history_screen.dart
    status: 推定（ファイル未確認）
    category: その他
  ACTIVITY:
    name: アクティビティログ
    file: lib/screens/activity_log_screen.dart
    status: 推定（ファイル未確認）
    category: その他

---
# 重複ID警告
duplicate_warnings:
  - "M1: マスター管理ハブ と M1:データベースリストア が重複"
  - "WH: 倉庫マスター と WH:倉庫ダッシュボード が重複"
  - "ST: 担当者マスター と ST:スタッフ管理 が重複"
  - "S1: テーマ設定、S1:高速検索 が重複"
  - "P2: 支払登録、P2:UIパフォーマンス最適化 が重複"
  - "C1: 得意先マスター、C1:資金繰り、C1:カスタムフィールド設定 が重複"
  - "A1: 売上分析、A1:集計分析、A1:監査ログ が重複"
  - "P1: 商品マスター、P1:粗利分析、P1:パフォーマンス最適化 が重複"
  - "R1: ロール管理、R1:在庫評価額レポート が重複"
  - "Q1: 見積入力、ES:見積入力 が機能重複"
  - "SD: フォーク修復、SD:Google Drive バックアップ、SD:お局様検出設定 が重複"
  - "CH: 履歴、CH:母艦チャット が重複"
  - "IV: 請求書発行、IV:在庫一覧 が重複"
  - "SM: メール設定、S8:メール設定 が機能重複"

---
# 未確認ファイル（docs/02_CURRENT_STATUS.mdに記載されているが実ファイル未確認）
unconfirmed:
  - P1: 商品マスター（product_master_screen.dart）
  - C1: 得意先マスター（customer_master_screen.dart）
  - SI: 仕入先マスター（supplier_master_screen.dart）
  - M1: マスター管理ハブ（master_hub_page.dart）
  - Q1: 見積入力（quotation_input_screen.dart）
  - O1: 受注入力（order_input_screen.dart）
  - A1: 売上入力（sales_entry_screen.dart）
  - SR1: 売上返品入力（sales_return_input_screen.dart）
  - INV1: 請求書発行（invoice_issue_screen.dart）
  - DOC1: 伝票入力（invoice_input_screen.dart）
  - A2: 伝票一覧（invoice_history_screen.dart）
  - U2: 仕入入力（purchase_entries_screen.dart）
  - SUP: サポート窓口（support_desk_screen.dart）
  - BARCODE: バーコードスキャン（barcode_scanner_screen.dart）
  - GPS: GPS履歴（gps_history_screen.dart）
  - ACTIVITY: アクティビティログ（activity_log_screen.dart）
