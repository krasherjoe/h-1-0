# AUTO_QUEUE — 原子タスクキュー

**最終更新**: 2026-03-09  
**ルール**: 1タスク＝1〜2ファイル・最大50行変更。`進めてください` で先頭 ⏳ を1件処理する。

---

## 🔴 即時修正（コンパイルエラー）

### ERR-001 ✅ `email_notification_service.dart` — SendReport API修正
**対象**: `lib/services/email_notification_service.dart`  
**エラー**: `SendReport.success` が存在しない（8箇所）  
**修正**: `sendReport.success` → try/catch内なので `return true` に置き換え  
**完了日**: 2026-03-09

### ERR-002 ✅ `purchase_receipts_screen.dart` — Supplierコンストラクタ修正
**対象**: `lib/screens/purchase_receipts_screen.dart`  
**エラー**: `Supplier(name:)` → `displayName`/`formalName` が必須（2箇所）  
**修正**: `name: '仕入先不明'` → `displayName: '仕入先不明', formalName: '仕入先不明'`  
**完了日**: 2026-03-09

### ERR-003 ✅ `report_widgets.dart` — 構文・型・import修正
**対象**: `lib/widgets/report_widgets.dart`  
**エラー**: 構文エラー2件・型エラー1件・import位置1件  
**修正**: `import 'dart:math'` をファイル先頭に移動、`num→double` キャスト追加、括弧修正  
**完了日**: 2026-03-09

### ERR-004 ✅ `camera_delivery_photo_service.dart` — ui.Canvas/Paint修正
**対象**: `lib/services/camera_delivery_photo_service.dart`  
**エラー**: `Canvas`, `Paint` が未定義（`ui.` プレフィックスなし）  
**修正**: `Canvas(recorder)` → `ui.Canvas(recorder)`、`Paint()` → `ui.Paint()`  
**完了日**: 2026-03-09

### ERR-005 ✅ `profit_analysis_screen.dart` — 括弧構文エラー修正
**対象**: `lib/screens/profit_analysis_screen.dart`  
**エラー**: Expected to find `]` (line 181)  
**修正**: 括弧バランスを修正  
**完了日**: 2026-03-09

### ERR-006 ✅ `isolate_service.dart` — num→double型修正
**対象**: `lib/services/isolate_service.dart`  
**エラー**: `num` を `double` パラメータに渡している（line 968）  
**修正**: `.toDouble()` キャスト追加  
**完了日**: 2026-03-09

---

## 🟡 警告整理（unused import / field）

### WARN-001 ✅ `sales_flow_management_screen.dart` — 未使用フィールド削除
**対象**: `lib/screens/sales_flow_management_screen.dart`  
**警告**: `_pdfService`, `_emailService`, `_quotes`, `_orders`, `_sales`, `_deliveries`, `_invoices`, `_searchQuery` が未使用  
**修正**: 未使用フィールドを削除（_searchQueryは使用箇所があるため残す）  
**完了日**: 2026-03-09

### WARN-002 ✅ `isolate_service.dart` — 未使用import/field削除
**対象**: `lib/services/isolate_service.dart`  
**警告**: `dart:isolate` import未使用、`_dbHelper` field未使用、`delay` 変数未使用  
**修正**: 未使用要素を削除  
**完了日**: 2026-03-09

### WARN-003 ✅ `fast_search_service.dart` / `full_text_search_service.dart` — 未使用import削除
**対象**: 上記2ファイル  
**警告**: `package:sqflite/sqflite.dart` 未使用  
**修正**: 未使用importを削除  
**完了日**: 2026-03-09

### WARN-004 ✅ `camera_delivery_photo_service.dart` — 未使用import/variable削除
**対象**: `lib/services/camera_delivery_photo_service.dart`  
**警告**: `intl` import未使用、`backupFile` 変数未使用  
**修正**: 未使用要素を削除  
**完了日**: 2026-03-09

### WARN-005 ✅ `email_notification_service.dart` — 未使用import削除
**対象**: `lib/services/email_notification_service.dart`  
**警告**: `sales_flow_models.dart` import未使用  
**修正**: 未使用importを削除  
**完了日**: 2026-03-09

### WARN-006 ✅ `gps_visit_service.dart` — 未使用変数・非推奨API修正
**対象**: `lib/services/gps_visit_service.dart`  
**警告**: `clientName` 未使用、`desiredAccuracy` 非推奨  
**修正**: 変数削除、`LocationSettings` を使う形に修正  
**完了日**: 2026-03-09

### WARN-007 ✅ その他 lib/ 警告一括整理
**対象**: `lib/screens/dashboard_screen.dart`, `lib/screens/inventory_movement_screen.dart`, `lib/screens/cash_flow_screen.dart`, 他  
**警告**: 未使用import、未使用フィールド  
**修正**: 未使用要素を削除  
**完了日**: 2026-03-09

---

## 🟢 機能追加タスク（エラー修正完了後）

### FEAT-001 ✅ `sales_flow_management_screen.dart` — 実DB接続
**対象**: `lib/screens/sales_flow_management_screen.dart`  
**内容**: サンプルデータ → `SalesFlowRepository` の実データに接続  
**完了日**: 2026-03-09

### FEAT-002 ✅ ナビゲーションに新画面を統合
**対象**: `lib/screens/` の新規画面（GPS、カメラ、FTS検索）  
**内容**: `management_screen.dart` にメニュー追加  
**完了日**: 2026-03-09

### WARN-008 ✅ 未使用変数・import一括削除
**対象**: 複数ファイル  
**警告**: `_payments`, `_availableLocations`, `_searchQuery`, `sendReport` など  
**修正**: 未使用要素を削除またはコメントアウト  
**完了日**: 2026-03-09

---

## ✅ 完了済みタスク

（なし）

---

## 📋 タスク追加ルール

- **1タスク＝1〜2ファイル・最大50行変更**
- ファイルを追加する場合は必ず「対象」「エラー/警告/内容」「修正方法」を明記
- 完了日は `git commit` 後に記入
