# Architecture

**Analysis Date:** 2026-05-16

## System Overview

```text
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer (screens/)                   │
│  ~40 screen files (~44k lines) — StatefulWidgets,           │
│  GenericListScreen<T> templates, DocumentCard cards          │
├──────────┬──────────┬──────────┬──────────┬────────────────┤
│ Widgets  │ Features │ Mothership│ Theme   │ Constants      │
│ (25)     │ (Module) │ (Server)  │ (1)     │ (6)            │
├──────────┴──────────┴──────────┴──────────┴────────────────┤
│                   Services Layer (~60 files)                 │
│  Repository pattern — raw SQL CRUD, NavigationService        │
│  DatabaseHelper (singleton), MothershipClient                │
├─────────────────────────────────────────────────────────────┤
│                    Models Layer (39 models)                  │
│  BaseDocument → Quotation/Order/Invoice/Delivery etc.        │
│  Master models: Customer, Product, Supplier, Staff...        │
├─────────────────────────────────────────────────────────────┤
│                   Database Layer                             │
│  SQLite (gemi_invoice.db v60) via sqflite                    │
│  79 CREATE TABLE statements in database_helper.dart          │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│           External: Mothership (Dart shelf server)           │
│           Heartbeat / Hash push / Chat endpoints             │
└─────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| **App Entry** | Theme management, DB init, backup progress UI, home routing | `lib/main.dart` |
| **Database Helper** | SQLite singleton wrapper, 79 CREATE TABLE statements, migration logic, LocalBackupService with SHA256 integrity verification and 7-year retention | `lib/services/database_helper.dart` |
| **Navigation Service** | Singleton navigator key, named route navigation (push, replace, pop, clear-and-push) | `lib/services/navigation_service.dart` |
| **Menu Catalog** | MenuDefinition class, 6 categories with route mappings | `lib/constants/menu_catalog.dart` |
| **App Config** | Feature flags gated by --dart-define (ENABLE_DEBUG_FEATURES, ENABLE_MASTER_MODULE, enablePurchaseModule, etc.) | `lib/config/app_config.dart` |
| **Generic List Screen** | Reusable list template with filter support, buildCard callback, empty state widget | `lib/widgets/generic_list_screen.dart<T>>` |
| **Document Card** | Bill-type card (title/subtitle/amount/date/status) with optional action buttons | `lib/widgets/document_card.dart` |
| **Base Document** | Abstract model for document types: id, documentNumber, customer?, items, tax, status; getDisplayTitle/getDisplaySubtitle/getDisplayAmount | `lib/models/base_document.dart` |
| **Feature Module** | Abstract base class with dashboard card registration, key/enabled/cards interface | `lib/modules/feature_module.dart` |
| **Mothership Server** | Device-side shelf server with /sync/heartbeat, /sync/hash, /chat/send, /chat/pending, /chat/ack endpoints; API key middleware | `lib/mothership/server.dart` |
| **Mothership Client** | Heartbeat and hash push client with config loading from env vars and client ID management | `lib/services/mothership_client.dart` |
| **Hash Utils** | SHA256-based integrity verification for Customer/Product models; hash chain with version increment and previous_hash linking | `lib/services/hash_utils.dart` |
| **Invoice Repository** | Hash chain verification (HashChainVerifyResult), kNonStockCategories for inventory exclusion | `lib/services/invoice_repository.dart` |

## Pattern Overview

**Overall:** Repository + Generic Template architecture

**Key Characteristics:**
- **Repository pattern** — Every entity has a dedicated repository class (`*_repository.dart`) with raw SQL CRUD; no ORM layer
- **Singleton DatabaseHelper** — `_internal()` constructor with Future caching for concurrent access safety; all queries flow through this gateway
- **Generic templates** — `GenericListScreen<T>` provides reusable list view with filter/callback architecture; `DocumentCard` standardizes bill-type display
- **Feature modules** — Abstract `FeatureModule` base class gates functionality via `AppConfig` flags (e.g., purchase module disabled by default)
- **Hash chain integrity** — SHA256 content hashes with version increment and previous_hash linking for tamper detection on master data (Customer, Product) and invoices

## Layers

### UI Layer (lib/screens/)
- **Purpose:** All 40+ user-facing screens as StatefulWidget classes
- **Location:** `lib/screens/screen_<id>_<name>.dart` pattern
- **Contains:** Screen state management, form inputs, list displays, PDF preview
- **Depends on:** Widgets, Services (repositories), Models
- **Used by:** NavigationService routes

### Widget Layer (lib/widgets/)
- **Purpose:** Reusable UI components shared across screens
- **Location:** `lib/widgets/`
- **Contains:** GenericListScreen, DocumentCard, MetricCard, EmptyStateWidget, LineItemEditor, custom field widgets, keyboard wrappers, status badges
- **Depends on:** Models (BaseDocument, DocumentStatus)
- **Used by:** All screens

### Services Layer (lib/services/)
- **Purpose:** Business logic and data access abstraction
- **Location:** `lib/services/`
- **Contains:** ~60 repository classes (raw SQL CRUD), DatabaseHelper singleton, NavigationService, MothershipClient, HashUtils, InvoiceRepository
- **Depends on:** sqflite, crypto/sha256, shelf (mothership)
- **Used by:** UI screens

### Model Layer (lib/models/)
- **Purpose:** Data structures and domain entities
- **Location:** `lib/models/`
- **Contains:** 39 model files — BaseDocument hierarchy for documents, master data models (Customer, Product, Supplier, Staff, Warehouse), inventory models, business profile
- **Depends on:** None (pure data classes)
- **Used by:** Services and UI layers

### Configuration Layer
- **Purpose:** App-wide settings and feature flags
- **Location:** `lib/config/app_config.dart`, `lib/mothership/config.dart`
- **Contains:** Feature flag parsing from --dart-define, MothershipConfig from environment variables
- **Depends on:** None
- **Used by:** All layers conditionally

## Data Flow

### Primary Screen Navigation Path

1. **App Launch** — `lib/main.dart` initializes theme (gray/dark/light), opens SQLite database via DatabaseHelper singleton, checks for backup progress state
2. **Home Routing** — main.dart routes to dashboard or last-accessed screen based on saved state
3. **Screen Display** — NavigatorService.pushNamed() with named routes from AppRoutes; screen StatefulWidget loads data via repository
4. **Data Access** — Repository class executes raw SQL through DatabaseHelper._instance
5. **UI Update** — setState() after async load, always preceded by `if (!mounted) return;`

### Document CRUD Flow

1. Screen calls `repository.insert/update/delete(model)`
2. Repository builds raw SQL statement with parameterized values
3. DatabaseHelper._instance.rawInsert/rawQuery/rawUpdate executes against SQLite
4. On success, screen navigates back or refreshes list via GenericListScreen callback

### Mothership Sync Flow

1. **Heartbeat** — MothershipClient sends clientId + remainingLifespan to `/sync/heartbeat` endpoint on device-side shelf server
2. **Hash Push** — After document operations, client pushes SHA256 hash to `/sync/hash` for remote recording
3. **Chat** — Bidirectional chat via `/chat/send`, `/chat/pending`, `/chat/ack` endpoints

### Backup Flow

1. User triggers backup from settings screen
2. LocalBackupService copies `gemi_invoice.db` to Downloads folder (`/storage/emulated/0/Download`)
3. SHA256 hash computed for integrity verification
4. Retention policy enforced: 7 years (365 × 7 days) — older backups purged

## Key Abstractions

### BaseDocument Hierarchy
- **Purpose:** Common fields for all document types (quotation, order, invoice, delivery, credit note)
- **Examples:** `lib/models/invoice_models.dart`, quotation and order models in `lib/models/`
- **Pattern:** Abstract base with concrete subclasses; shared fields: id, documentNumber, customer?, items[], tax, status

### Repository Pattern
- **Purpose:** Data access abstraction per entity type
- **Examples:** `lib/services/customer_repository.dart`, `lib/services/product_repository.dart`, `lib/services/invoice_repository.dart`
- **Pattern:** Class with getAll(), getById(), insert(), update(), delete() methods; raw SQL via DatabaseHelper

### GenericListScreen<T>
- **Purpose:** Reusable list screen template for any entity type
- **Examples:** `lib/widgets/generic_list_screen.dart<T>>`
- **Pattern:** Parameterized by T extends BaseDocument; accepts filter predicate, buildCard callback, empty state widget

### FeatureModule
- **Purpose:** Gated feature modules with dashboard card registration
- **Examples:** `lib/modules/purchase_management_module.dart` (gated by enablePurchaseModule)
- **Pattern:** Abstract base with key/enabled/dashboardCards interface; cards registered on dashboard screen

## Entry Points

### main.dart
- **Location:** `lib/main.dart` (~800+ lines)
- **Triggers:** App launch
- **Responsibilities:** MaterialApp configuration, theme management (gray/dark/light), DatabaseHelper initialization, backup progress state restoration, home screen routing, route map definition

### MothershipServer.start()
- **Location:** `lib/mothership/server.dart`
- **Triggers:** On app startup if mothership configured
- **Responsibilities:** Shelf HTTP server on configurable host/port, API key middleware, 6 endpoint handlers (heartbeat, hash, chat send/pending/ack, status, dashboard)

## Architectural Constraints

- **Threading:** Single-threaded Flutter UI; all DB operations via async/await through DatabaseHelper singleton with Future caching to serialize concurrent access
- **Global state:** 
  - `DatabaseHelper._instance` — singleton with `_initFuture` for concurrent access safety (`lib/services/database_helper.dart`)
  - `NavigationService.instance` — singleton navigator key (`lib/services/navigation_service.dart`)
  - `AppConfig` — static feature flags parsed from --dart-define at compile time (`lib/config/app_config.dart`)
- **Circular imports:** None detected; dependency flow is strictly UI → Widgets → Services → Models
- **No ORM:** All data access uses raw SQL through DatabaseHelper; no Object-Relational Mapping layer
- **Screen naming:** Strict `screen_<2-3char-id>_<name>.dart` convention enforced by AGENTS.md

## Anti-Patterns

### Monolithic main.dart

**What happens:** `lib/main.dart` is ~800+ lines containing theme config, DB init, backup progress UI state, home routing logic, and route map definition all in one file.

**Why it's wrong:** Tight coupling between app bootstrap concerns makes testing difficult and increases risk when modifying startup behavior.

**Do this instead:** Extract theme configuration to `lib/theme/`, backup progress state machine to a dedicated service class, and route definitions to `lib/services/navigation_service.dart` (already partially done).

### Raw SQL in Repository Classes

**What happens:** Every repository class embeds raw SQL strings directly in methods (e.g., `rawInsert('INSERT INTO customers ...')`).

**Why it's wrong:** No query abstraction layer means SQL errors surface at runtime, string concatenation risks injection if parameters are not properly bound, and schema changes require edits across many files.

**Do this instead:** Create a query builder or at minimum extract SQL templates to a constants file per entity (e.g., `lib/constants/customer_queries.dart`).

## Error Handling

**Strategy:** try-catch with mounted checks and user-facing error messages

**Patterns:**
- All async operations check `if (!mounted) return;` before setState or Navigator calls (`lib/main.dart`, all screens)
- Database errors caught at repository level, logged via debugPrint, then surfaced to user
- MothershipClient handles connection failures gracefully (offline-first design)
- Backup operations use try-catch with progress state updates through main.dart's backupProgressState

## Cross-Cutting Concerns

**Logging:** `debugPrint()` throughout; shelf server uses `logRequests()` middleware (`lib/mothership/server.dart`)

**Validation:** Hash chain integrity verification via `HashUtils` for Customer/Product models — content hash + previous_hash + version increment enables tamper detection

**Authentication:** Mothership API key via `x-api-key` header in `_apiKeyMiddleware`; no user-level auth detected (offline standalone app)

**Internationalization:** `intl` package for date formatting (`DateFormat('yyyy/MM/dd')`); Japanese UI text throughout

---

*Architecture analysis: 2026-05-16*
