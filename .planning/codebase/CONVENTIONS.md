# Coding Conventions

**Analysis Date:** 2026-05-16

## Naming Patterns

**Files:**
- snake_case for all Dart source files: `database_helper.dart`, `invoice_repository.dart`, `screen_a1_dashboard.dart`
- Screen files follow `screen_<id>_<name>.dart` pattern: `screen_s8_email_settings.dart`, `screen_pj2_project_detail.dart`
- Test files mirror source names with `_test.dart` suffix: `customer_model_test.dart`, `inventory_location_repository_test.dart`

**Functions/Methods:**
- camelCase for public methods: `fetchAllProducts()`, `toMap()`, `fromMap()`
- private methods prefixed with underscore: `_load()`, `_editInvoice()`, `_confirmFormalIssue()`
- Factory constructors named descriptively: `defaultProfile()`, `fromEnv()`

**Variables:**
- camelCase for local/instance variables: `_loading`, `_invoices`, `searchController`
- Private state prefixed with underscore: `_filter`, `_startDate`, `_issuing`
- const constants in UPPER_SNAKE_CASE when in dedicated constants files: `MAIL_SEND_METHOD_SMTP`, `KEY_INVOICE_STYLE`

**Types:**
- PascalCase for classes: `InvoiceRepository`, `BaseDocument`, `GenericListScreen<T>`
- Enums use PascalCase with PascalCase members: `_InvoiceIssueFilter { pending, issued }`, `BusinessType { retail, service, manufacturing }`
- Abstract base classes prefixed conceptually: `BaseDocument` (no strict naming convention enforced)

**State Variables:**
- Private state variables in StatefulWidget start with underscore: `_loading`, `_invoices`, `_filter`
- Use descriptive names reflecting UI state: `_issuing`, `_redInvoiceSourceIds`, `_searchController`

## Code Style

**Formatting:**
- Standard Dart formatting (dart format)
- 2-space indentation
- Line length: no explicit enforcement via linter rules beyond `flutter_lints/flutter.yaml`
- `analysis_options.yaml` uses only `flutter_lints/flutter.yaml` — no custom rules for line length, imports ordering, or naming conventions

**Linting:**
- Tool: `flutter_lints` package
- Config: `analysis_options.yaml` (minimal — relies on parent package's lints)
- Run command: `flutter analyze --no-fatal-infos`
- No custom lint rules defined — project-level linting is minimal

**Trailing Commas:** Used in method parameters and constructor calls (consistent with modern Dart style)

## Import Organization

**Order:**
1. `dart:` core imports first (`dart:async`, `dart:io`)
2. `package:` Flutter/Dart package imports alphabetically
3. Relative local imports grouped by layer (`../models/`, `../services/`, `widgets/`)

**Example from `lib/screens/invoice_issue_screen.dart`:**
```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/invoice_list_style.dart';
import '../models/invoice_models.dart';
import '../services/customer_repository.dart';
import '../services/app_settings_repository.dart';
import '../services/invoice_repository.dart';
import '../services/pdf_generator.dart';
import '../services/storage_monitor.dart';
import '../theme/invoice_list_style_theme.dart';
import '../widgets/invoice_list_a2_card.dart';
import '../widgets/invoice_pdf_preview_page.dart';
import '../widgets/storage_warning_dialog.dart';
import 'invoice_input_screen.dart';
```

**Path Aliases:** None detected — all local imports use relative paths (`../services/`, `widgets/`)

## Error Handling

**Strategy:** Throw typed exceptions with descriptive Japanese messages.

**Patterns observed:**
```dart
// Generic Exception for runtime/business errors
throw Exception('ストレージ容量不足のため保存できません');
throw Exception('order_not_found');
throw Exception('見積が見つかりません');
throw Exception('データ改ざんが検出されました: $documentId');

// ArgumentError for invalid parameters
throw ArgumentError('Database file not found: ${databaseFile.path}');
throw ArgumentError('amount must be greater than 0');
throw ArgumentError('移動元と移動先の倉庫が同一です');

// StateError for invariant violations
throw StateError('倉庫[$warehouseId]の商品[$productId]の在庫が不足しています (残量: $current, 変動: $delta)');
```

**Custom Exception Classes:**
- `DuplicateCustomerException` — thrown when duplicate customer detected in `lib/models/customer_model.dart`
- `CustomerInUseException` — thrown when customer referenced by other records

**Screen-level error handling:** Try-catch blocks with debugPrint for logging, no user-facing error dialogs consistently implemented. Example from `lib/screens/invoice_issue_screen.dart`:
```dart
Future<bool> _confirmFormalIssue(Invoice invoice) async {
  final result = await showDialog<bool>(...);
  if (result == true) {
    try {
      await _invoiceRepo.formalIssue(invoice.id!);
    } catch (e) {
      // Error handling pattern varies by screen
    }
  }
}
```

## Logging

**Framework:** `debugPrint()` — used extensively throughout the codebase (~290 calls across services and screens).

**Patterns observed:**
```dart
// Verbose debug logging in services
debugPrint('InvoiceRepository: fetchAllWithHistory called');
debugPrint('HashChainVerifyResult: hash=$hash, isValid=$isValid');
debugPrint('BackupService: backup completed successfully');

// DEBUG markers for temporary debugging (mixed with real code)
// 51 TODO/FIXME/HACK comments found — many are debug prints or incomplete features
```

**Note:** No structured logging framework (e.g., `logging`, `logger`) is used. All logging goes through Flutter's `debugPrint`.

## Comments

**When to Comment:**
- Japanese comments used throughout for business logic explanation
- API documentation comments (`///`) used sparingly — only on public-facing widgets like `EmptyStateWidget`
- Inline comments explain "why" not "what" when present

**JSDoc/TSDoc (Dart doc comments):**
```dart
/// 基本伝票モデル
/// すべての伝票（見積・受注・売上・請求）に共通する基底クラス
abstract class BaseDocument { ... }

/// 汎用空状態ウィジェット
/// データがない時の表示に使用
class EmptyStateWidget extends StatelessWidget { ... }
```

## Function Design

**Size:** Functions tend to be medium-sized (20-80 lines). Complex screens like `invoice_issue_screen.dart` (~559 lines) have many private helper methods.

**Parameters:**
- Named parameters with defaults for widgets (Flutter convention)
- Required named parameters for constructors: `required this.id`, `required this.documentNumber`
- Optional nullable parameters where appropriate: `this.notes`, `this.subtitle`

**Return Values:**
- `Future<T>` for async operations
- `Map<String, dynamic>` for serialization (`toMap()`)
- Custom result objects for complex operations: `HashChainVerifyResult` from invoice_repository
- `void` for side-effect-only methods

## Module Design

**Exports:**
- Each file exports its primary class(es) — no barrel files detected
- Models import each other directly when needed (e.g., `base_document.dart` imports `customer_model.dart`)

**Repository Pattern:**
- One repository per entity: `lib/services/<entity>_repository.dart`
- Repositories construct their own `DatabaseHelper` instances internally
- Methods: `getAll()`, `getById()`, `insert()`, `update()`, `delete()`, plus domain-specific methods

**Generic Widgets:**
- `GenericListScreen<T extends BaseDocument>` — typed generic list with filters, async loading
- `DocumentCard` — reusable card for document display
- `EmptyStateWidget` — empty state placeholder UI

## StatefulWidget Patterns

**Lifecycle:**
```dart
class InvoiceIssueScreen extends StatefulWidget {
  const InvoiceIssueScreen({super.key});
  
  @override
  State<InvoiceIssueScreen> createState() => _InvoiceIssueScreenState();
}

class _InvoiceIssueScreenState extends State<InvoiceIssueScreen> {
  final InvoiceRepository _invoiceRepo = InvoiceRepository();
  bool _loading = true;
  
  @override
  void initState() {
    super.initState();
    _load();
  }
  
  Future<void> _load() async { ... }
}
```

**mounted checks after async:**
- `if (!mounted) return;` used before `setState()` and `Navigator.push()` after await
- Consistently applied in screens that perform async operations (verified across multiple screen files)

## Constants & Configuration

**Constants file:** `lib/constants/` — static constants, mail templates, enums
```dart
// lib/constants/mail_templates.dart
const String kMailTemplateSubjectDefault = '請求書のご案内';
const String kMailTemplateBodyDefault = 'お世話になっております。';
```

**AppConfig:** Centralized version and feature flags via `lib/config/app_config.dart`
- Overridable via `--dart-define` at build time
- Controls module visibility: master, sales, purchase, inventory, analytics, system

## Theme System

**Singleton pattern:** `AppThemeController` in `lib/services/theme_controller.dart` uses `ValueNotifier<String>` for reactive theme state.

**Theme resolution:** `InvoiceListStyleTheme` resolves between A2-style and legacy invoice card styles based on settings.

---

*Convention analysis: 2026-05-16*
