# Coding Conventions

**Analysis Date:** 2026-05-22

## Naming Patterns

**Files:**
- Screen files: `screen_<2-3char_id>_<name>.dart` (e.g. `screen_pj1_project_list.dart`, `screen_s1_theme_selection.dart`)
- Service/repository files: `<entity>_repository.dart` (e.g. `customer_repository.dart`, `product_repository.dart`)
- Model files: `<entity>_model.dart` (e.g. `customer_model.dart`, `invoice_models.dart`)
- Widget files: `<descriptive_name>.dart` (e.g. `document_card.dart`, `empty_state_widget.dart`)
- Part files: `_part.dart` suffix when splitting large files (e.g. `invoice_header_widget.dart`)

**Classes:**
- Screens: `{Purpose}Screen` (e.g. `ProjectListScreen`, `ThemeSelectionScreen`)
- Services: `{Entity}Repository` (e.g. `CustomerRepository`, `ProductRepository`)
- Models: `{Entity}` (e.g. `Customer`, `Product`, `BaseDocument`)
- Widgets: `{Purpose}{Widget}` (e.g. `DocumentCard`, `EmptyStateWidget`, `ScreenAppBarTitle`)
- Private State classes: `_{Class}State` (e.g. `_ProjectListScreenState`)

**Functions/Methods:**
- `camelCase` for all methods and functions
- Private: `_leadingUnderscore` plus `camelCase`
- Getters: `camelCase` (e.g. `getDisplayTitle()`, `get invoiceName`)

**Variables & Constants:**
- Local variables: `camelCase` (e.g. `_allItems`, `_loading`, `_searchCtrl`)
- Constants: `lowercase_with_underscores` for SharedPreferences keys (e.g. `kLastBackupTime = 'last_backup_time'`)
- Class-level const: `kPrefix` convention (e.g. `kMailSendMethodSmtp`)
- Private instance vars: `_leadingUnderscore`

**Types:**
- Enums: `PascalCase` (e.g. `DocumentStatus`, `BusinessType`, `WorkflowType`)
- Abstract classes: `PascalCase` (e.g. `BaseDocument`)
- Mixins: `PascalCase` with `Mixin` suffix when applicable

## Screen ID Prefix System

Every screen MUST use a 2-3 character alphanumeric prefix (e.g. `S1:`, `P1:`, `PJ1:`) in the AppBar title:
- `S1:設定`, `P1:商品マスター`, `PJ1:案件一覧`
- File name pattern: `screen_<id>_<name>.dart`
- The `ScreenAppBarTitle` widget in `lib/widgets/screen_id_title.dart` enforces the ID+title display pattern

**Existing IDs (do not duplicate):** S1, SM, P1, C1, SI, WH, ST, ES, OR, IV, IQ, IM, IC, CS, PA, CH, M1, D2, PJ1, PJ2, TK, PC, TH, SB

## Code Style & Formatting

**Linter:** `package:flutter_lints` (v6.0.0) via `analysis_options.yaml`, with `flutter analyze --no-fatal-infos`

**Key Dart settings:**
- `analysis_options.yaml` includes `package:flutter_lints/flutter.yaml` with no custom overrides
- The default Flutter lint set is active

**Run command:**
```bash
flutter analyze --no-fatal-infos
```

## File Size Limits

- **Screen files: 1,200 lines maximum** — exceed by splitting into child widgets in `lib/screens/` or `lib/widgets/` with `_part.dart` suffix
- **Service files: 800 lines maximum** — split by entity or functional area
- Example split: `invoice_input_screen.dart` → `invoice_header_widget.dart`, `invoice_lines_widget.dart`, `invoice_calculator_widget.dart`

## Import Organization

Imports follow this order within each file:
1. **Dart SDK** (`dart:io`, `dart:async`, `dart:convert`)
2. **Flutter SDK** (`package:flutter/material.dart`, `package:flutter/foundation.dart`)
3. **Third-party packages** (`package:sqflite/`, `package:shared_preferences/`, `package:path_provider/`, etc.)
4. **Local project imports** relative paths (e.g. `'../models/customer_model.dart'`)

Screen files use relative imports (e.g. `'../services/project_repository.dart'`), not package-prefixed.

## Widget Patterns

**StatefulWidget pattern:**
```dart
class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({super.key});

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen>
    with SingleTickerProviderStateMixin {
  // Private fields initialized directly (not in constructor)
  final _repo = ProjectRepository();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _repo.getAllProjects();
    if (!mounted) return;  // ← REQUIRED after any await
    setState(() {
      _all = list;
      _loading = false;
    });
  }
}
```

**StatelessWidget pattern** (used for reusable widgets):
```dart
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // ... build method
  }
}
```

## Async Operation — `mounted` Check

**MANDATORY:** Insert `if (!mounted) return;` after every `await` call that precedes `setState()` or `Navigator` operations:

```dart
// lib/screens/screen_pj1_project_list.dart — lines 46-50
Future<void> _load() async {
  final list = await _repo.getAllProjects();
  final salesMap = <String, int>{};
  for (final project in list) {
    final sales = await _invoiceRepo.getTotalAmountByProjectId(project.id);
    salesMap[project.id] = sales;
  }
  if (!mounted) return;  // ← REQUIRED
  setState(() {
    _all = list;
    _projectSales = salesMap;
    _loading = false;
  });
}
```

This applies to:
- `setState()` calls
- `Navigator.push()`, `Navigator.pop()` calls
- `ScaffoldMessenger.of(context).showSnackBar()` calls

## Generic List Pattern

Reusable `GenericListScreen<T>` in `lib/widgets/generic_list_screen.dart`:
```dart
class GenericListScreen<T> extends StatefulWidget {
  final String screenId;
  final String title;
  final Future<List<T>> Function() fetchData;
  final Widget Function(BuildContext, T, VoidCallback) buildCard;
  final List<FilterOption<T>>? filters;
  final Future<void> Function()? onCreateNew;
  // ...
}
```

## Repository Pattern (CRUD)

Every entity has a repository class in `lib/services/`:
```dart
// lib/services/product_repository.dart
class ProductRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ActivityLogRepository _logRepo = ActivityLogRepository();

  Future<List<Product>> getAllProducts({bool includeHidden = false}) async { ... }
  Future<Product?> getProduct(String id) async { ... }
  Future<void> saveProduct(Product product) async { ... }
  Future<void> deleteProduct(String id) async { ... }
}
```

Key conventions:
- `DatabaseHelper` singleton accessed via `_dbHelper.database`
- Raw SQL queries via `db.rawQuery()` (not `db.query()` often)
- Transactions for multi-table writes via `db.transaction()`
- Hash chain integration via `HashUtils` for electronic recordkeeping compliance

## Model Patterns

**`BaseDocument`** in `lib/models/base_document.dart` — abstract base for all document types:
- Contains `id`, `documentNumber`, `date`, `customer`, `items`, `subtotal`, `taxAmount`, `total`, `status`
- Abstract methods: `toMap()`, `getStatusColor()`, `getThemeColor()`, `getDocumentTypeName()`
- Concrete `DocumentItem` class with `toMap()`, `fromMap()`, `copyWith()`

**Standard model** (e.g. `Customer` in `lib/models/customer_model.dart`):
- Immutable fields with `final`
- `fromMap(Map<String, dynamic>)` factory constructor
- `toMap()` instance method for SQLite serialization
- `copyWith()` for immutable updates
- Custom exception classes co-located in the model file (e.g. `DuplicateCustomerException`)

## Error Handling

**Database operations** — `try-catch` with logging and safe UI update:
```dart
try {
  final db = await _dbHelper.database;
  // ...
} catch (e) {
  debugPrint('DB Error: $e');
  if (!mounted) return;
  showOfflineWarning();
}
```

**API/network operations** — graceful offline degradation:
```dart
try {
  await syncService.uploadData(data);
} catch (e) {
  if (!mounted) return;
  showOfflineWarning();  // Stay in offline mode
}
```

Custom exceptions used for domain errors:
- `DuplicateCustomerException` in `lib/models/customer_model.dart`
- `CustomerInUseException` in `lib/models/customer_model.dart`

## Logging

- Production logging: `debugPrint()` (prints only in debug mode)
- Temporary debug output: `print()` — avoid in committed code
- Error context: Include operation name and entity ID in the message

## SharedPreferences Key Naming

Use snake_case strings assigned to `const` variables with `k` prefix:
```dart
const String kLastBackupTime = 'last_backup_time';
const String kMailSendMethodSmtp = 'mail_send_method_smtp';
const String kDailyBackupKey = 'backup_date_today';
```

See `lib/services/auto_backup_service.dart` for examples.

## Duplicate Code Prevention

**Rule:** Any code block appearing 3+ times MUST be extracted to `lib/widgets/` as a shared utility.

Good shared abstractions found:
- `lib/widgets/document_card.dart` — universal document card widget
- `lib/widgets/empty_state_widget.dart` — universal empty state
- `lib/widgets/generic_list_screen.dart` — reusable list screen template
- `lib/widgets/screen_id_title.dart` — unified AppBar title with screen ID

Split large screens into child widgets under `lib/screens/<screen_name>/` subdirectories (e.g. `lib/screens/invoice_input/`).

## Database Migration Patterns

In `lib/services/database_helper.dart`:
```dart
onUpgrade: (db, oldVersion, newVersion) async {
  if (oldVersion < 34) {
    await db.execute('ALTER TABLE ...');
  }
  // Never DROP TABLE — use ALTER TABLE to preserve data
}
```
- Always increment `version` in `openDatabase()` when schema changes
- Use `_safeAddColumn()` helper pattern from `lib/services/customer_repository.dart` to add columns safely

## Git Commits

- Messages MUST be in Japanese only
- Example: `git commit -m "S1:新機能画面を実装し、データベース連携を追加"`

---

*Convention analysis: 2026-05-22*
