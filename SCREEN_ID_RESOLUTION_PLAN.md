# 画面ID重複解決計画

## 新旧IDマッピング

### M1 重複
- 旧: M1:マスタ管理ハブ (settings_screen.dart) → 新: **MH**:マスタ管理ハブ
- 旧: M1:データベースリストア (restore_screen.dart) → 新: **DB**:データベースリストア

### WH 重複
- 旧: WH:倉庫マスター (warehouse_master_screen.dart) → 新: **WH**:倉庫マスター（維持）
- 旧: WH:倉庫ダッシュボード (warehouse_dashboard_screen.dart) → 新: **WD**:倉庫ダッシュボード

### ST 重複
- 旧: ST:担当者マスター (staff_master_screen.dart) → 新: **ST**:担当者マスター（維持）
- 旧: ST:スタッフ管理 (staff_management_screen.dart) → 新: **SM**:スタッフ管理

### S1 重複
- 旧: S1:テーマ設定 (screen_s1_theme_selection.dart) → 新: **TH**:テーマ設定
- 旧: S1:高速検索 (fast_search_screen.dart) → 新: **FS**:高速検索

### P2 重複
- 旧: P2:支払登録 (payment_register_screen.dart) → 新: **P2**:支払登録（維持）
- 旧: P2:UIパフォーマンス最適化 (ui_performance_screen.dart) → 新: **UP**:UIパフォーマンス最適化

### C1 重複
- 旧: C1:得意先マスター (customer_master_screen.dart) → 新: **C1**:得意先マスター（維持）
- 旧: C1:資金繰り (cash_flow_screen.dart) → 新: **CF**:資金繰り
- 旧: C1:カスタムフィールド設定 (custom_field_settings_screen.dart) → 新: **CS**:カスタムフィールド設定

### A1 重複
- 旧: A1:売上分析 (sales_analysis_screen.dart) → 新: **SA**:売上分析
- 旧: A1:集計分析 (analytics_dashboard_screen.dart) → 新: **AA**:集計分析
- 旧: A1:監査ログ (audit_log_screen.dart) → 新: **AL**:監査ログ

### P1 重複
- 旧: P1:商品マスター (product_master_screen.dart) → 新: **P1**:商品マスター（維持）
- 旧: P1:粗利分析 (profit_analysis_screen.dart) → 新: **PA**:粗利分析（PAは既存と重複 → **GP**:粗利分析）
- 旧: P1:パフォーマンス最適化 (performance_optimization_screen.dart) → 新: **PO**:パフォーマンス最適化

### R1 重複
- 旧: R1:ロール管理 (role_management_screen.dart) → 新: **R1**:ロール管理（維持）
- 旧: R1:在庫評価額レポート (inventory_value_report_screen.dart) → 新: **IR**:在庫評価額レポート

### SD 重複
- 旧: SD:フォーク修復 (screen_debug_fork_break.dart) → 新: **FK**:フォーク修復
- 旧: SD:Google Drive バックアップ (drive_backup_screen.dart) → 新: **GD**:Google Drive バックアップ
- 旧: SD:お局様検出設定 (mothership_discovery_settings_screen.dart) → 新: **MD**:お局様検出設定

### CH 重複
- 旧: CH:履歴 (customer_history_screen.dart) → 新: **CH**:履歴（維持）
- 旧: CH:母艦チャット (chat_screen.dart) → 新: **MC**:母艦チャット

### IV 重複
- 旧: IV:請求書発行 (invoice_issue_screen.dart) → 新: **IV**:請求書発行（維持）
- 旧: IV:在庫一覧 (inventory_list_screen.dart) → 新: **IL**:在庫一覧

### SM 重複（S8と機能重複）
- 旧: S8:メール設定 (screen_s8_email_settings.dart) → 新: **S8**:メール設定（維持）
- 旧: SM:メール設定 (settings_screen.dart) → 新: **EM**:メール設定（削除推奨、S8に統合）

---

## 優先順位
1. 高頻度使用画面のIDを維持（C1, P1, ST, WH, IV, CH）
2. 機能重複は統合（SM → S8）
3. デバッグ画面はDBG接頭辞推奨（FK → DBG_FK）
