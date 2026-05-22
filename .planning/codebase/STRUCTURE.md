# Codebase Structure

**Analysis Date:** 2026-05-22

## Directory Layout

```
lib/                          # Flutter application root (279 .dart files total)
├── main.dart                 # App entry point, theme, DB init, backup, heartbeat
├── config/
│   └── app_config.dart       # Feature flags, version, module toggles
├── constants/                # Static constants and lookup tables
│   ├── company_profile_keys.dart
│   ├── dashboard_icons.dart
│   ├── mail_send_method.dart
│   ├── mail_templates.dart
│   ├── menu_catalog.dart
│   └── warehouse_constants.dart
├── models/                   # Data model classes (43 files)
│   ├── base_document.dart    # Abstract base for document types
│   ├── customer_model.dart
│   ├── product_model.dart
│   ├── invoice_models.dart
│   ├── project_model.dart
│   ├── quotation_model.dart
│   ├── sales_flow_models.dart
│   ├── purchase_entry_models.dart
│   ├── purchase_order_models.dart
│   ├── stock_transfer_models.dart
│   ├── auth_models.dart
│   ├── chat_message.dart
│   ├── dashboard_menu_item.dart
│   ├── sync_preferences.dart
│   └── ... (29 more model files)
├── modules/                  # Feature module system
│   ├── feature_module.dart
│   └── purchase_management_module.dart
├── mothership/               # Server-side mothership code
│   ├── server.dart           # HTTP server (shelf) for sync/heartbeat/chat
│   ├── config.dart
│   ├── data_store.dart
│   └── chat_store.dart
├── screens/                  # UI screens (110 files in 6 subdirs)
│   ├── screen_a1_dashboard.dart
│   ├── screen_pj1_project_list.dart
│   ├── screen_pj2_project_detail.dart
│   ├── screen_s1_theme_selection.dart
│   ├── screen_s8_email_settings.dart
│   ├── screen_sb_backup_settings.dart
│   ├── screen_th2_theme_customizer.dart
│   ├── screen_pc_product_category_master.dart
│   ├── screen_debug_fork_break.dart
│   ├── settings_screen.dart
│   ├── dashboard_screen.dart
│   ├── customer_master_screen.dart
│   ├── product_master_screen.dart
│   ├── supplier_master_screen.dart
│   ├── invoice_input_screen.dart
│   ├── invoice_history_screen.dart
│   ├── invoice_detail_page.dart
│   ├── invoice_issue_screen.dart
│   ├── estimate_input_screen.dart
│   ├── order_input_screen.dart
│   ├── sales_entry_screen.dart
│   ├── quotation_input_screen.dart
│   ├── purchase_input_screen.dart
│   ├── ... (80+ more screen files)
│   ├── company_info/         # Subdirectory: seal contrast/offset widgets
│   │   ├── seal_contrast_dialog.dart
│   │   └── seal_offset_adjust_page.dart
│   ├── invoice_detail/      # Subdirectory: detail snapshot, table cells
│   │   ├── detail_snapshot.dart
│   │   └── invoice_table_cells.dart
│   ├── invoice_history/     # Subdirectory: history item, history list
│   │   ├── invoice_history_item.dart
│   │   └── invoice_history_list.dart
│   ├── invoice_input/       # Subdirectory: calculator keypad, draft badge, snapshot
│   │   ├── calculator_keypad.dart
│   │   ├── draft_badge.dart
│   │   └── invoice_snapshot.dart
│   └── project_detail/      # Subdirectory: status badge
│       └── status_badge.dart
├── services/                 # Business logic, repositories, sync (79 files)
│   ├── database_helper.dart # SQLite singleton, schema, migrations
│   ├── product_repository.dart
│   ├── customer_repository.dart
│   ├── invoice_repository.dart
│   ├── supplier_repository.dart
│   ├── warehouse_repository.dart
│   ├── staff_repository.dart
│   ├── project_repository.dart
│   ├── quotation_repository.dart
│   ├── sales_repository.dart
│   ├── purchase_repository.dart
│   ├── purchase_entry_repository.dart
│   ├── purchase_order_repository.dart
│   ├── purchase_payment_repository.dart
│   ├── purchase_receipt_repository.dart
│   ├── purchase_return_repository.dart
│   ├── payment_repository.dart
│   ├── payment_schedule_repository.dart
│   ├── delivery_repository.dart
│   ├── inventory_repository.dart
│   ├── inventory_location_repository.dart
│   ├── sales_flow_repository.dart
│   ├── activity_log_repository.dart
│   ├── chat_repository.dart
│   ├── auth_repository.dart
│   ├── custom_field_repository.dart
│   ├── milestone_repository.dart
│   ├── task_repository.dart
│   ├── time_log_repository.dart
│   ├── electronic_ledger_repository.dart
│   ├── business_profile_repository.dart
│   ├── app_settings_repository.dart  # SharedPreferences wrapper
│   ├── analytics_repository.dart
│   ├── company_repository.dart
│   ├── product_category_repository.dart
│   ├── warehouse_stock_repository.dart
│   ├── edit_log_repository.dart
│   ├── gmail_sync_client.dart     # Gmail API sync engine
│   ├── chat_sync_scheduler.dart    # 10s periodic sync
│   ├── mothership_client.dart      # Direct HTTP sync client
│   ├── mothership_chat_client.dart
│   ├── mothership_discovery_service.dart
│   ├── google_account_service.dart
│   ├── google_api_service_base.dart
│   ├── drive_backup_service.dart
│   ├── auto_backup_service.dart
│   ├── backup_progress_notifier.dart
│   ├── pdf_generator.dart
│   ├── print_service.dart
│   ├── invoice_email_sender.dart
│   ├── location_service.dart
│   ├── gps_service.dart
│   ├── gps_visit_service.dart
│   ├── sensor_service.dart
│   ├── enhanced_audio_service.dart
│   ├── enhanced_location_service.dart
│   ├── camera_delivery_photo_service.dart
│   ├── fast_search_service.dart
│   ├── full_text_search_service.dart
│   ├── advanced_search_service.dart
│   ├── theme_controller.dart
│   ├── navigation_service.dart
│   ├── company_profile_service.dart
│   ├── storage_monitor.dart
│   ├── storage_permission_service.dart
│   ├── device_account_service.dart
│   ├── email_notification_service.dart
│   ├── hash_utils.dart
│   ├── isolate_service.dart
│   ├── performance_service.dart
│   └── ui_performance_service.dart
├── theme/
│   └── invoice_list_style_theme.dart
├── utils/
│   ├── build_expiry_info.dart   # Build timestamp/lifespan utilities
│   └── theme_utils.dart
└── widgets/                  # Reusable components (30 files)
    ├── generic_list_screen.dart    # Generic list with filter/refresh
    ├── document_card.dart          # Document card widget
    ├── empty_state_widget.dart     # Empty state placeholder
    ├── screen_id_title.dart        # Screen ID title component
    ├── menu_category_header.dart   # Dashboard category header
    ├── contact_picker_sheet.dart   # Contact picker bottom sheet
    ├── keyboard_aware_scaffold.dart
    ├── keyboard_inset_wrapper.dart
    ├── custom_field_display_widget.dart
    ├── custom_field_input_widget.dart
    ├── delivery_status_badge.dart
    ├── draft_badge.dart
    ├── invoice_draft_badge.dart
    ├── invoice_calculator_keypad.dart
    ├── invoice_list_a2_card.dart
    ├── invoice_pdf_preview_page.dart
    ├── invoice_red_invoice_button.dart
    ├── invoice_tax_rate_picker.dart
    ├── line_item_editor.dart
    ├── master_field_config.dart
    ├── metric_card.dart
    ├── report_widgets.dart
    ├── rich_master_edit_sheet.dart
    ├── generic_master_edit_dialog.dart
    ├── seal_camera_screen.dart
    ├── slide_to_unlock.dart
    ├── swipe_to_unlock.dart
    ├── storage_warning_dialog.dart
    ├── zoomable_app_bar.dart
    └── analytics_chart.dart
```

## Directory Purposes

**`lib/screens/` (110 files):**
- Purpose: All UI screen widgets for the application
- Subdirectories: `company_info/`, `invoice_detail/`, `invoice_history/`, `invoice_input/`, `project_detail/`
- Key pattern: `StatefulWidget` + `initState() → _load() → setState()` cycle
- Screen ID convention: Title bar shows `"S1:設定"`, `"PJ1:案件管理"`, etc.

**`lib/services/` (79 files):**
- Purpose: Repository classes (CRUD), sync clients, utilities, PDF generation, backup
- Key files: `database_helper.dart` (SQLite singleton, 2850+ lines), sync services, `app_settings_repository.dart`
- Pattern: Each entity has `<entity>_repository.dart` with `getAll`, `save`, `delete`, `search`

**`lib/models/` (43 files):**
- Purpose: Data model classes with `toMap()`/`fromMap()` serialization
- Key base: `BaseDocument` abstract class in `base_document.dart`
- Pattern: All models have `toMap()`, `fromMap()`, and some have `copyWith()`

**`lib/widgets/` (30 files):**
- Purpose: Reusable UI components shared across screens
- Key widgets: `GenericListScreen<T>`, `DocumentCard`, `EmptyStateWidget`, `ScreenIdTitle`

**`lib/config/` (1 file):**
- Purpose: `AppConfig` — feature flags, version, module enable/disable via `--dart-define`

**`lib/constants/` (6 files):**
- Purpose: Static lookup tables for dashboard icons, menu catalog, mail templates, etc.

**`lib/modules/` (2 files):**
- Purpose: Pluggable feature modules with dashboard card definitions

**`lib/mothership/` (4 files):**
- Purpose: Server-side code for the mothership "お局様" HTTP server (shelf-based)

**`lib/theme/` (1 file):**
- Purpose: Theme extensions for invoice list styles

**`lib/utils/` (2 files):**
- Purpose: `BuildExpiryInfo` (build timestamp/lifespan), `ThemeUtils`

## Key File Locations

**Entry Points:**
- `lib/main.dart`: App entry point, MyApp widget, theme (5 variants), DB init, backup, heartbeat

**Configuration:**
- `lib/config/app_config.dart`: Feature flags, version, module enablement via `--dart-define`
- `pubspec.yaml`: Dependencies, version 1.5.31+176, Flutter SDK ^3.10.7

**Database:**
- `lib/services/database_helper.dart`: SQLite singleton, schema version 66, full migration history
- DB file: `/storage/emulated/0/Documents/販売アシスト 1 号/販売アシスト 1 号.db`

**Core Logic:**
- `lib/services/product_repository.dart`: Product CRUD with hash chain versioning
- `lib/services/customer_repository.dart`: Customer CRUD with duplicate detection + hash chain
- `lib/services/invoice_repository.dart`: Invoice CRUD with sync snapshots

**Navigation:**
- `lib/services/navigation_service.dart`: Named route definitions (limited usage)
- Most navigation: Direct `Navigator.push(MaterialPageRoute(...))` in screen code

**Testing:**
- `test/` directory (not in `lib/`): test files

## Naming Conventions

**Files:**
- `screen_<id>_<name>.dart`: Newer convention (e.g., `screen_pj1_project_list.dart`, `screen_a1_dashboard.dart`)
- `<entity>_repository.dart`: Repository files (e.g., `product_repository.dart`)
- `<entity>_model.dart`: Model files (e.g., `customer_model.dart`)
- `<widget_name>.dart`: Widget files (e.g., `document_card.dart`, `empty_state_widget.dart`)
- **Inconsistency**: Many older screens use plain names like `customer_master_screen.dart`, `invoice_input_screen.dart` instead of the `screen_<id>_<name>.dart` convention

**Directories:**
- Lowercase with underscores: `screens/`, `services/`, `models/`, `widgets/`, `utils/`, `constants/`

**Dart classes:**
- PascalCase: `ProductRepository`, `GenericListScreen`, `BaseDocument`
- State classes: `_<WidgetName>State` (private, e.g., `_ProjectListScreenState`)

## Where to Add New Code

**New Feature/Screen:**
- Primary code: `lib/screens/screen_<id>_<name>.dart` (follow `screen_<id>_<name>` convention)
- Model: `lib/models/<entity>_model.dart` (extend BaseDocument if applicable)
- Repository: `lib/services/<entity>_repository.dart`
- Tests: `test/` directory

**New Widget:**
- Implementation: `lib/widgets/<widget_name>.dart`

**New Utility/Service:**
- Shared helpers: `lib/services/<name>_service.dart` or `lib/utils/<name>.dart`

**New Feature Module:**
- Module class: `lib/modules/<name>_module.dart` (extend `FeatureModule`)

**Database Schema Change:**
- Migration: `lib/services/database_helper.dart` in `_onUpgrade()`, increment `_databaseVersion`

## Special Directories

**`lib/mothership/`:**
- Purpose: Server-side Dart code for the mothership ("お局様") HTTP server
- Generated: No
- Committed: Yes (part of the monorepo)

---

*Structure analysis: 2026-05-22*
