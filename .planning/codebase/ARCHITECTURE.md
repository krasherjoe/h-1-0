<!-- refreshed: 2026-05-22 -->
# Architecture

**Analysis Date:** 2026-05-22

## System Overview

```text
┌────────────────────────────────────────────────────────────────────┐
│                         UI Layer (lib/screens/)                      │
│   StatefulWidget screens (~110 files), setState-based state mgmt    │
│   Screen ID system: "S1:設定", "PJ1:案件管理" in AppBar titles      │
└──────────────────────────┬─────────────────────────────────────────┘
                           │ Navigator.push(MaterialPageRoute(...))
                           ▼
┌────────────────────────────────────────────────────────────────────┐
│                   Business Logic Layer (lib/services/)              │
│   Repository classes (CRUD) → call DatabaseHelper singleton        │
│   ~79 service files: product_repository, customer_repository, etc. │
│   Sync services: gmail_sync_client, chat_sync_scheduler, etc.     │
│   Auth: auth_repository, google_account_service                    │
└──────────────────────────┬─────────────────────────────────────────┘
                           │ dbHelper.database -> SQLite
                           ▼
┌────────────────────────────────────────────────────────────────────┐
│                   Data Access Layer (lib/services/)                 │
│   DatabaseHelper singleton - manages SQLite via sqflite             │
│   Schema version 66, migration via onUpgrade()                     │
│   DB path: /storage/emulated/0/Documents/販売アシスト 1 号/        │
│   DB file: 販売アシスト 1 号.db                                     │
│                                                                     │
│   Online Sync (optional):                                          │
│   ┌─────────────┐    ┌──────────────┐    ┌──────────────────┐     │
│   │ Gmail API   │    │ Mothership   │    │ LAN Discovery   │     │
│   │ (gmail)     │    │ Server       │    │ (GPS-based)     │     │
│   └─────────────┘    └──────────────┘    └──────────────────┘     │
└────────────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────────────────┐
│                   Data Models (lib/models/)                         │
│   ~43 model files: customer_model, product_model, invoice_models   │
│   BaseDocument abstract class for document types                   │
│   toMap() / fromMap() serialization                                │
└────────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| `MyApp` / `_MyAppState` | App root, theme setup, DB init, backup, heartbeat | `lib/main.dart` |
| `ScreenA1Dashboard` | Home dashboard, summary cards, menu navigation | `lib/screens/screen_a1_dashboard.dart` |
| `DatabaseHelper` | Singleton SQLite manager, schema creation, migrations | `lib/services/database_helper.dart` |
| `AppSettingsRepository` | SharedPreferences wrapper for app config | `lib/services/app_settings_repository.dart` |
| `GmailSyncClient` | Gmail API sync for chat + invoice snapshots | `lib/services/gmail_sync_client.dart` |
| `ChatSyncScheduler` | 10s interval sync scheduler, transport selection | `lib/services/chat_sync_scheduler.dart` |
| `MothershipClient` | Direct HTTP client to mothership server | `lib/services/mothership_client.dart` |
| `MothershipServer` | Dart shelf-based mothership HTTP server | `lib/mothership/server.dart` |
| `ProductRepository` | CRUD for products with hash chain versioning | `lib/services/product_repository.dart` |
| `CustomerRepository` | CRUD for customers with hash chain versioning | `lib/services/customer_repository.dart` |
| `InvoiceRepository` | CRUD for invoices, sync snapshots, hash chain | `lib/services/invoice_repository.dart` |
| `GenericListScreen<T>` | Reusable list screen with filters, search, FAB | `lib/widgets/generic_list_screen.dart` |
| `DocumentCard` | Reusable document card widget | `lib/widgets/document_card.dart` |
| `BaseDocument` | Abstract base class for document types | `lib/models/base_document.dart` |
| `NavigationService` | Named route navigator (limited usage) | `lib/services/navigation_service.dart` |
| `AppConfig` | Feature flags, version, module toggles | `lib/config/app_config.dart` |

## Pattern Overview

**Overall:** Repository pattern + singleton DatabaseHelper with offline-first SQLite

**Key Characteristics:**
- Every entity has a Repository class in `lib/services/<entity>_repository.dart`
- `DatabaseHelper` is a singleton (`factory DatabaseHelper() => _instance`) with cached `_database` Future
- Screens are `StatefulWidget` subclasses using setState for state management
- No Riverpod/Provider usage in actual screen code (despite AGENTS.md guidance)
- Navigation via `Navigator.push(MaterialPageRoute(...))` — named routes in `NavigationService` are minimally used
- Database schema v66 with incremental `ALTER TABLE` migrations
- Hash chain versioning for customers, products, invoices (since v44+)
- Offline-first: all data lives in local SQLite; sync is optional add-on
- Feature modules gated via `AppConfig` boolean flags (`ENABLE_MASTER_MODULE`, etc.)

## Layers

**UI Layer (Screens):**
- Purpose: All visual screens, data entry forms, list views
- Location: `lib/screens/` (110 files)
- Contains: StatefulWidget subclasses with `initState()` → `_load()` → `setState()` pattern
- Depends on: Repository classes from `lib/services/`
- Used by: `lib/main.dart` (app root), direct `Navigator.push`

**Business Logic Layer (Services):**
- Purpose: Repository classes, sync clients, utilities
- Location: `lib/services/` (79 files)
- Contains: Repository CRUD (ProductRepository, CustomerRepository, etc.), sync clients, auth, PDF generation, backup
- Depends on: `DatabaseHelper` singleton, models
- Used by: Screen widgets

**Data Access Layer (DatabaseHelper):**
- Purpose: SQLite connection, schema creation, migration management
- Location: `lib/services/database_helper.dart`
- Contains: `DatabaseHelper` singleton, `LocalBackupService`
- Pattern: Singleton with double-checked locking via cached `_databaseFuture`

**Model Layer:**
- Purpose: Data classes with toMap/fromMap serialization
- Location: `lib/models/` (43 files)
- Contains: `BaseDocument` abstract, `Customer`, `Product`, `Invoice`, etc.
- Key base: `BaseDocument` abstract class with `id`, `documentNumber`, `items`, `total`, `toMap()`

**Widget Layer:**
- Purpose: Reusable UI components
- Location: `lib/widgets/` (30 files)
- Contains: `GenericListScreen<T>`, `DocumentCard`, `EmptyStateWidget`, filter chips, modals

## Data Flow

### Primary Request Path (List → Detail)

1. Screen initializes, calls `_load()` in `initState()` (`lib/screens/screen_pj1_project_list.dart:49`)
2. Screen calls repository method: `await _repo.getAllProjects()` (`lib/services/project_repository.dart`)
3. Repository gets DB instance: `final db = await _dbHelper.database;`
4. Repository runs SQL: `await db.rawQuery('SELECT ...')` or `await db.query(...)`
5. Repository maps rows: `rows.map((r) => Model.fromMap(r)).toList()`
6. Result returns to screen: `if (!mounted) return; setState(() { ... })`
7. Screen renders via `build()` method with `_filteredItems` or `_allItems`

### Save Flow (Screen → Repository → DB)

1. User fills form, taps save button
2. Screen calls repository: `await _repo.saveProduct(product)` (`lib/services/product_repository.dart:74`)
3. Repository opens transaction: `await db.transaction((txn) async { ... })`
4. Within transaction: old version marked `is_current=0`, new version INSERTed
5. Hash chain calculated: `HashUtils.calculateProductHash(...)` stored as `content_hash`
6. Activity logged: `await _logRepo.logAction(action: "SAVE_PRODUCT", ...)`
7. Screen refreshes: `_load()` called again

### Sync Flow (Chat/Invoice via Gmail)

1. `ChatSyncScheduler` fires every 10 seconds (`lib/services/chat_sync_scheduler.dart:49`)
2. Transport mode checked: Gmail/Direct/Auto (`_executeSyncWithTransportSelection()`)
3. `GmailSyncClient.sync()` pushes pending chats + fetches inbound in parallel (`Future.wait`)
4. Messages encoded as `GmailSyncEnvelope` (JSON → gzip → Base64URL)
5. Sent as email to BCC address with subject `[Sync:v1] <messageId>#<sequence>`
6. Inbound: queries INBOX for subject prefix, parses envelope, upserts chat messages
7. Direct mode: `MothershipChatClient` does HTTP POST to mothership server

**State Management:**
- All screen-level state handled via `setState()` in StatefulWidget
- `ChatSyncScheduler` uses `WidgetsBindingObserver` for app lifecycle
- `BackupProgressNotifier` is a `ChangeNotifier` used by `_MyAppState`
- `AppThemeController` uses `ValueNotifier<String>` for theme switching
- No Riverpod/Provider/Bloc usage in production screen code

## Key Abstractions

**BaseDocument (Abstract Model):**
- Purpose: Base class for all document types (quotations, orders, sales, invoices)
- File: `lib/models/base_document.dart`
- Fields: `id`, `documentNumber`, `date`, `customer`, `items`, `subtotal`, `taxAmount`, `total`, `taxRate`, `status`, `createdAt`, `updatedAt`
- Methods: `toMap()`, `getStatusColor()`, `getThemeColor()`, `getDocumentTypeName()`

**GenericListScreen<T>:**
- Purpose: Reusable list screen with data fetching, filtering, pull-to-refresh
- File: `lib/widgets/generic_list_screen.dart`
- Pattern: Accepts `fetchData`, `buildCard`, `filters`, `onCreateNew` as callbacks
- Layout: AppBar with screen ID title + filter menu + refresh, ListView with pull-to-refresh, FAB for create

**DocumentCard:**
- Purpose: Reusable card-style document list item
- File: `lib/widgets/document_card.dart`
- Fields: `title`, `subtitle`, `amount`, `date`, `status`, `themeColor`, `actions`
- Status chip: `draft` (secondary), `confirmed` (tertiary), `cancelled` (outline)

**Repository Pattern:**
- All repositories follow same interface: `getAll()`, `getById()`, `save()`, `delete()`, `search()`
- File: `lib/services/*_repository.dart`
- Pattern: Instantiates `DatabaseHelper` singleton, uses `_logRepo` for activity logging
- Hash chain versioning: saves create new version rows (not UPDATE in-place)

**FeatureModule:**
- Purpose: Pluggable module system for dashboard cards
- File: `lib/modules/feature_module.dart`
- Used by: `PurchaseManagementModule` (`lib/modules/purchase_management_module.dart`)
- Gated by `AppConfig.enable*Module` flags

## Entry Points

**App Entry:**
- Location: `lib/main.dart:65` — `void main() async { ... runApp(MyApp(...)); }`
- Triggers: App launch
- Responsibilities: WidgetsFlutterBinding initialization, build expiry check, theme setup, DB init, heartbeat, sync scheduler start, backup restore check

**Mothership Server:**
- Location: `lib/mothership/server.dart:12` — `class MothershipServer`
- Triggers: `dart run bin/mothership_server.dart`
- Responsibilities: HTTP server on configurable host:port, heartbeat/hash/chat endpoints, HTML dashboard

## Architectural Constraints

- **Threading:** Single-threaded event loop (Flutter standard); `Future.microtask()` used for deferred initialization at startup (`lib/main.dart:147`)
- **Global state:** `DatabaseHelper` singleton (`_instance`), `_database` static field; `AppThemeController.instance` singleton; `NavigationService.instance` singleton
- **Circular imports:** Not detected — services depend on `DatabaseHelper`, screens depend on services/models/widgets
- **Platform constraints:** Uses `Platform.isAndroid` / `Platform.isIOS` branching throughout (e.g., `lib/main.dart:110`, `lib/services/database_helper.dart:613`)
- **File access:** Internal DB in shared Documents folder; exports/imports in system Download folder (`/storage/emulated/0/Download`)
- **Build expiry:** `BuildExpiryInfo` from `--dart-define=APP_BUILD_TIMESTAMP` enforces 90-day default lifespan
- **No state management library:** Despite AGENTS.md recommending Riverpod, all existing screens use `setState()` — migration has not occurred

## Error Handling

**Strategy:** try-catch at screen level, user-facing SnackBar on failure, `debugPrint` for diagnostics

**Patterns:**
1. DB calls wrapped in try-catch: `try { await db.query(...) } catch (e) { debugPrint('DB Error: $e'); }` (`lib/services/database_helper.dart:703`)
2. Screen-level: `try { ... } catch (e) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(...); }` (`lib/widgets/generic_list_screen.dart:66-72`)
3. Async mounted check: `if (!mounted) return;` before any `setState()` or `Navigator.push()` after await
4. Activity log repository records errors to DB: `_logRepo.logAction(action: "ERROR", ...)`

## Cross-Cutting Concerns

**Logging:** `debugPrint` throughout (Flutter debug-only); `print` in a few files; dedicated `ActivityLogRepository` for business audit trail (`lib/services/activity_log_repository.dart`)
**Validation:** Client-side validation in screen forms; duplicate checking in `CustomerRepository.checkDuplicate()`
**Authentication:** Custom auth via `AuthRepository` / `AuthService`; Google Sign-In via `google_sign_in` package + `GoogleAccountService`
**Hash Chain:** SHA-256 hash chain for customers/products/invoices since DB v44; verified on startup (tail-5) in `main.dart:144`

## Anti-Patterns

### setState-heavy State Management

**What happens:** Nearly all screens manage state via `StatefulWidget` + `setState()`, including data-fetching screens with complex state
**Why it's wrong:** Leads to unnecessary rebuilds, makes state sharing between screens difficult, and increases boilerplate
**Do this instead:** The AGENTS.md recommends Riverpod Provider/StateNotifier for complex state. New screens should use `flutter_riverpod` with `StateNotifierProvider` instead of another `setState`

### Mixed Naming Convention for Screen Files

**What happens:** Some screens follow `screen_<id>_<name>.dart` convention (e.g., `screen_pj1_project_list.dart`) while others use plain names (e.g., `customer_master_screen.dart`, `invoice_input_screen.dart`)
**Why it's wrong:** Inconsistency makes it harder to locate files by name pattern; the AGENTS.md mandates `screen_<id>_<name>.dart` format but ~90% of screens don't follow it
**Do this instead:** Rename legacy screens to match `screen_<id>_<name>.dart` convention, or update AGENTS.md to reflect actual convention

---

*Architecture analysis: 2026-05-22*
