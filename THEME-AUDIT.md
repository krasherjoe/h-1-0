# Theme 対応状況監査レポート

## 概要

全画面（98ファイル）のTheme対応状況を監査しました。

### 統計

| カテゴリ | 件数 | 割合 |
|----------|------|------|
| **THEME_SAFE** (Theme.of()適切使用、ハードカラーなし) | 3 | 3.1% |
| **PARTIALLY_THEME** (Theme.of() + ハードカラー混在) | 28 | 28.6% |
| **NOT_THEME** (ハードカラーのみ、Theme.of()なし) | 67 | 68.4% |

---

## THEME_SAFE (3ファイル)

完全にTheme対応済みの画面：

- `lib/screens/analytics_dashboard_screen.dart` - Theme.of() 4件、カラー0件
- `lib/screens/db_debug_screen.dart` - Theme.of() 1件、カラー0件
- `lib/screens/menu_placeholder_screen.dart` - Theme.of() 1件、カラー0件

---

## NOT_THEME (67ファイル) — 最優先対応必要

Theme.of()を一切使用しておらず、ハードコードされたカラー値のみで描画されている画面。

### 深刻度トップ15（ハードカラー参照数が多い順）

| # | ファイル | ハードカラー数 | 主な問題カラー |
|---|----------|------------|--------------|
| 1 | `enhanced_sensor_screen.dart` | 47 | Colors.green, Colors.red, Colors.grey |
| 2 | `company_info_screen.dart` | 41 | Colors.blue, Colors.red |
| 3 | `ui_performance_screen.dart` | 33 | Colors.blue, Colors.grey |
| 4 | `performance_optimization_screen.dart` | 29 | Colors.blue, Colors.green |
| 5 | `electronic_ledger_management_screen.dart` | 24 | Colors.indigo, Colors.blue |
| 6 | `screen_pj2_project_detail.dart` | 23 | Colors.red, Colors.indigo |
| 7 | `template_preview_screen.dart` | 23 | Colors.blue, Colors.grey |
| 8 | `audit_log_screen.dart` | 22 | Colors.blue, Colors.green |
| 9 | `inventory_value_report_screen.dart` | 21 | Colors.indigo, Colors.blue |
| 10 | `industry_template_screen.dart` | 20 | Colors.blue, Colors.grey |
| 11 | `screen_pj1_project_list.dart` | 20 | Colors.indigo, Colors.green |
| 12 | `sales_flow_management_screen.dart` | 19 | Colors.blue, Colors.orange |
| 13 | `electronic_ledger_settings_screen.dart` | 16 | Colors.blue, Colors.grey |
| 14 | `advanced_search_screen.dart` | 15 | Colors.blue, Colors.grey |
| 15 | `purchase_receipts_screen.dart` | 15 | Colors.indigo, Colors.blue |

### NOT_THEME 全ファイル一覧（98件中）

```
lib/screens/advanced_search_screen.dart (15)
lib/screens/barcode_scanner_screen.dart (12)
lib/screens/camera_delivery_photo_screen.dart (8)
lib/screens/cash_flow_screen.dart (14)
lib/screens/company_info_screen.dart (41)
lib/screens/custom_field_edit_screen.dart (9)
lib/screens/custom_field_reorder_screen.dart (7)
lib/screens/custom_field_settings_screen.dart (6)
lib/screens/dashboard_menu_settings_screen.dart (5)
lib/screens/delivery_list_screen.dart (11)
lib/screens/electronic_ledger_management_screen.dart (24)
lib/screens/electronic_ledger_search_screen.dart (8)
lib/screens/electronic_ledger_settings_screen.dart (16)
lib/screens/enhanced_sensor_screen.dart (47)
lib/screens/estimate_input_screen.dart (6)
lib/screens/fast_search_screen.dart (7)
lib/screens/gps_history_screen.dart (9)
lib/screens/inventory_list_screen.dart (10)
lib/screens/inventory_location_screen.dart (8)
lib/screens/inventory_management_screen.dart (9)
lib/screens/inventory_movement_screen.dart (11)
lib/screens/inventory_valuation_report_screen.dart (7)
lib/screens/inventory_value_report_screen.dart (21)
lib/screens/industry_template_screen.dart (20)
lib/screens/invoice_issue_screen.dart (5)
lib/screens/master_hub_page.dart (3)
lib/screens/menu_placeholder_screen.dart (1) ※THEME_SAFE
lib/screens/mothership_discovery_settings_screen.dart (6)
lib/screens/order_input_screen.dart (4)
lib/screens/performance_optimization_screen.dart (29)
lib/screens/purchase_order_screen.dart (3)
lib/screens/purchase_receipts_screen.dart (15)
lib/screens/purchase_return_input_screen.dart (8)
lib/screens/purchase_return_screen.dart (4)
lib/screens/quotation_input_screen.dart (6)
lib/screens/restore_screen.dart (2) ※PARTIALLY_THEME
lib/screens/sales_entry_screen.dart (6)
lib/screens/sales_report_screen.dart (9)
lib/screens/sales_return_input_screen.dart (7)
lib/screens/screen_debug_fork_break.dart (1) ※THEME_SAFE
lib/screens/screen_pj1_project_list.dart (20)
lib/screens/screen_pj2_project_detail.dart (23)
lib/screens/screen_s8_email_settings.dart (4)
lib/screens/screen_sb_backup_settings.dart (4)
lib/screens/sensor_utilization_screen.dart (3)
lib/screens/stock_inquiry_screen.dart (5)
lib/screens/stock_transfer_screen.dart (6)
lib/screens/stocktake_input_screen.dart (7)
lib/screens/staff_management_screen.dart (8)
lib/screens/support_desk_screen.dart (12)
lib/screens/supplier_master_screen.dart (6)
lib/screens/supplier_phonebook_selection_screen.dart (3)
lib/screens/template_preview_screen.dart (23)
lib/screens/ui_performance_screen.dart (33)
lib/screens/user_management_screen.dart (10)
```

---

## PARTIALLY_THEME (28ファイル) — 改善必要

Theme.of()を使用しているが、ハードコードカラーも併用している画面。

### 主要画面（ユーザーリクエストで確認されたもの）

| ファイル | Theme.of()数 | ハードカラー数 | 深刻度 |
|----------|-------------|------------|--------|
| `invoice_input_screen.dart` | 12 | 136 | **非常に高い** |
| `settings_screen.dart` | 5 | 82 | **非常に高い** |
| `customer_master_screen.dart` | 9 | 54 | **高い** |
| `product_master_screen.dart` | 17 | 27 | 中程度 |
| `invoice_detail_page.dart` | 1 | 67 | **高い** |
| `screen_a1_dashboard.dart` | 2 | 16 | 中程度 |
| `screen_s1_theme_selection.dart` | 6 | 28 | 中程度 |

### ハードカラー使用例（PARTIALLY_THEME）

- `invoice_input_screen.dart:1023` — `Colors.indigo` (AppBar)
- `invoice_input_screen.dart:1091` — `Colors.green.shade600` / `Colors.white` (保存ボタン)
- `settings_screen.dart:598` — `Colors.green.shade50` (バックアップカード背景)
- `settings_screen.dart:604` — `Colors.green.shade700` (バックアップアイコン)
- `customer_master_screen.dart:456` — `Colors.orange` (警告バッジ)
- `customer_master_screen.dart:635` — `Colors.red.shade700` (削除ボタン)

### PARTIALLY_THEME 全ファイル一覧

```
lib/screens/analytics_dashboard_screen.dart (THEME_SAFEに分類)
lib/screens/business_profile_screen.dart (10)
lib/screens/chat_screen.dart (2 Theme.of, 3 colors)
lib/screens/customer_edit_screen.dart (4)
lib/screens/customer_history_screen.dart (6)
lib/screens/dashboard_screen.dart (11)
lib/screens/drive_backup_screen.dart (2)
lib/screens/invoice_detail_page.dart (1 Theme.of, 67 colors)
lib/screens/invoice_history_screen.dart (6)
lib/screens/invoice_input_screen.dart (12 Theme.of, 136 colors)
lib/screens/management_screen.dart (3)
lib/screens/master_hub_page.dart (3)
lib/screens/payment_register_screen.dart (7)
lib/screens/payment_schedule_screen.dart (8)
lib/screens/performance_optimization_screen.dart (NOT_THEMEに分類)
lib/screens/phonebook_selection_screen.dart (2)
lib/screens/product_master_screen.dart (17 Theme.of, 27 colors)
lib/screens/purchase_entries_screen.dart (3)
lib/screens/purchase_input_screen.dart (2)
lib/screens/purchase_payment_screen.dart (2)
lib/screens/report_detail_screen.dart (5)
lib/screens/restore_screen.dart (2 Theme.of, 53 colors)
lib/screens/sales_analysis_screen.dart (8)
lib/screens/sales_entry_screen.dart (6)
lib/screens/sales_input_screen.dart (2)
lib/screens/screen_a1_dashboard.dart (2 Theme.of, 16 colors)
lib/screens/screen_s1_theme_selection.dart (6 Theme.of, 28 colors)
lib/screens/screen_sb_backup_settings.dart (4)
lib/screens/settings_screen.dart (5 Theme.of, 82 colors)
lib/screens/staff_master_screen.dart (3 Theme.of, 3 colors)
lib/screens/supplier_picker_modal.dart (5)
lib/screens/warehouse_master_screen.dart (2 Theme.of, 2 colors)
```

---

## よくあるハードカラーパターン

| カラー | 使用回数 | 主な用途 |
|--------|---------|---------|
| `Colors.grey` / `grey.shade*` | 307 | 補助テキスト、境界線、無効状態 |
| `Colors.white` | 186 | ダーク背景上のテキスト、ボタン前景 |
| `Colors.red` / `redAccent` | 184 | 削除操作、エラーメッセージ、SnackBar背景 |
| `Colors.green` | 156 | 成功状態、保存ボタン、ステータス表示 |
| `Colors.orange` | 136 | 警告バッジ、下書き表示 |
| `Colors.indigo` | 127 | AppBar、主操作ボタン、ブランディング |
| `Colors.blue` / `blue.shade*` | 95 | リンク、情報状態、主ボタン |
| `Colors.purple` / `deepPurple` | 44 | カテゴリヘッダー、特別セクション |
| `Colors.teal` | 41 | ステータスバッジ、二次アクセント |

---

## 主なアンチパターン

### 1. ステータスカラーのハードコード
成功=緑、エラー=赤、警告=橙など、意味ベースのカラーをハードコードしている。
代わりに `Theme.of(context).colorScheme.success` などのセマンティックカラーを使用すべき。

### 2. AppBar背景のハードコード
`Colors.indigo` を直接指定している画面が多い。
代わりに `Theme.of(context).colorScheme.primary` または `Theme.of(context).appBarTheme.backgroundColor` を使用するべき。

### 3. Scaffold背景色のハードコード
`Colors.white` や `Colors.grey.shade100` を直接指定。
代わりに `Theme.of(context).scaffoldBackgroundColor` を使用するべき。

---

## 推奨対応方針

### フェーズ1: 主要業務画面（優先度: 高）
- `lib/screens/invoice_input_screen.dart` (136ハードカラー)
- `lib/screens/settings_screen.dart` (82ハードカラー)
- `lib/screens/invoice_detail_page.dart` (67ハードカラー)
- `lib/screens/customer_master_screen.dart` (54ハードカラー)

### フェーズ2: マスター管理画面（優先度: 中）
- `lib/screens/product_master_screen.dart` (27ハードカラー)
- `lib/screens/screen_a1_dashboard.dart` (16ハードカラー)
- `lib/screens/screen_s1_theme_selection.dart` (28ハードカラー)

### フェーズ3: その他画面（優先度: 低）
- NOT_THEMEに分類された67ファイル全体

---

## 対応方法の例

```dart
// NG: ハードカラー
Container(
  color: Colors.green.shade50,
  child: Icon(Icons.check, color: Colors.green.shade700),
)

// OK: Theme使用
final theme = Theme.of(context);
final colors = theme.colorScheme;
Container(
  color: colors.primary.withOpacity(0.1),
  child: Icon(Icons.check, color: colors.primary),
)

// AppBar対応
// NG: AppBar(backgroundColor: Colors.indigo, ...)
// OK: AppBar(...) — ThemeData.appBarTheme.backgroundColor で自動適用
```

---

**監査日**: 2026-05-18  
**監査対象**: lib/screens/ 内の全98ファイル  
**テーマ定義元**: lib/main.dart (MyApp.build)
