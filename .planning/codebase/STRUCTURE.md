# Codebase Structure

**Analysis Date:** 2026-05-16

## Directory Layout

```
h_1.flutter.0/
├── lib/                          # Application source code (14 entries)
│   ├── main.dart                 # Entry point, theme, DB init, routing (~800+ lines)
│   ├── screens/                  # UI screens (~40 files, ~44k lines total)
│   ├── services/                 # Business logic + data access (~60 files)
│   ├── models/                   # Data models (39 files)
│   ├── widgets/                  # Reusable components (25 files)
│   ├── modules/                  # Feature modules (2 files)
│   ├── mothership/               # Device-side shelf server (config, data_store, chat_store, server.dart)
│   ├── constants/                # App-wide constants (6 files)
│   ├── theme/                    # Theme configuration (1 file)
│   ├── config/                   # Feature flags (1 file)
│   └── utils/                    # Utilities (1 file)
├── test/                         # Test suite
│   ├── unit/                     # Unit tests organized by layer
│   │   ├── models/               # Model tests
│   │   ├── services/             # Service/repository tests
│   │   └── widgets/              # Widget tests
│   └── widget_test.dart          # Placeholder widget test
├── pubspec.yaml                  # Package manifest (version 1.5.28+173)
├── analysis_options.yaml         # Dart linting configuration
├── AGENTS.md                     # Code generation AI guidelines
├── README.md                     # Project overview and development rules
└── TODO.md                       # Task management
```

## Directory Purposes

### lib/screens/
- **Purpose:** All user-facing screens (~40 files)
- **Contains:** StatefulWidget classes implementing business screens (invoices, orders, estimates, master data entry, reports, settings)
- **Key files:** `lib/screens/invoice_input_screen.dart` (3078 lines — largest screen), `lib/screens/screen_pj1_project_list.dart`, `lib/screens/screen_pj2_project_detail.dart`
- **Naming:** `screen_<id>_<name>.dart` where `<id>` is 2–3 character prefix (e.g., `S1`, `PJ1`, `WH`)

### lib/services/
- **Purpose:** Business logic and data access abstraction (~60 files)
- **Contains:** Repository classes per entity, DatabaseHelper singleton, NavigationService, MothershipClient, HashUtils, InvoiceRepository
- **Key files:** 
  - `lib/services/database_helper.dart` — SQLite wrapper with 79 CREATE TABLE statements, LocalBackupService
  - `lib/services/navigation_service.dart` — Singleton navigator key + AppRoutes definitions
  - `lib/services/invoice_repository.dart` — Hash chain verification for documents
  - `lib/services/hash_utils.dart` — SHA256 integrity verification for Customer/Product models
- **Pattern:** Repository classes follow CRUD interface: getAll(), getById(), insert(), update(), delete()

### lib/models/
- **Purpose:** Data structures and domain entities (39 files)
- **Contains:** BaseDocument hierarchy, master data models (Customer, Product, Supplier, Staff, Warehouse), inventory models, business profile
- **Key files:** `lib/models/base_document.dart` (abstract base for documents), `lib/models/invoice_models.dart` (Invoice/InvoiceItem with hash chain support)
- **Hierarchy:** BaseDocument → Quotation, Order, Invoice, Delivery, CreditNote

### lib/widgets/
- **Purpose:** Reusable UI components shared across screens (25 files)
- **Contains:** GenericListScreen template, DocumentCard, MetricCard, EmptyStateWidget, LineItemEditor, custom field widgets, keyboard wrappers, status badges
- **Key files:** `lib/widgets/generic_list_screen.dart<T>>`, `lib/widgets/document_card.dart`, `lib/widgets/line_item_editor.dart`

### lib/modules/
- **Purpose:** Gated feature modules with dashboard card registration (2 files)
- **Contains:** Abstract FeatureModule base class, PurchaseManagementModule implementation
- **Key files:** `lib/modules/feature_module.dart` (ModuleDashboardCard + abstract FeatureModule), `lib/modules/purchase_management_module.dart`

### lib/mothership/
- **Purpose:** Device-side shelf HTTP server for remote sync (4 files)
- **Contains:** Server routing, data store, chat store, configuration
- **Key files:** `lib/mothership/server.dart`, `lib/mothership/config.dart`, `lib/mothership/data_store.dart`, `lib/mothership/chat_store.dart`

### lib/constants/
- **Purpose:** App-wide constants and catalogs (6 files)
- **Contains:** Menu definitions, dashboard icons, mail templates, company profile keys, warehouse constants
- **Key files:** `lib/constants/menu_catalog.dart` (MenuDefinition class, 6 categories)

### test/
- **Purpose:** Test suite organized by layer
- **Structure:** `test/unit/<layer>/<entity>_test.dart` pattern
- **Current coverage:** 12 test files covering hash chain, models (Customer, Product, Quotation, Sales), services (QuotationRepository, InventoryLocationRepository, BusinessProfileRepository), widgets (DocumentCard, EmptyStateWidget)

## Key File Locations

### Entry Points:
- `lib/main.dart`: App entry point, theme management (gray/dark/light), DatabaseHelper initialization, backup progress state UI, home routing
- `lib/mothership/server.dart`: Shelf HTTP server startup with 6 endpoints

### Configuration:
- `pubspec.yaml`: Package manifest — version 1.5.28+173, SDK ^3.10.7
- `lib/config/app_config.dart`: Feature flags from --dart-define (ENABLE_DEBUG_FEATURES, ENABLE_MASTER_MODULE, enablePurchaseModule, etc.)
- `lib/mothership/config.dart`: MothershipConfig from env vars (MOTHERSHIP_HOST, MOTHERSHIP_PORT, MOTHERSHIP_API_KEY, MOTHERSHIP_DATA_DIR)
- `analysis_options.yaml`: Dart linting configuration

### Core Logic:
- `lib/services/database_helper.dart`: SQLite singleton wrapper, 79 CREATE TABLE statements, version 60 migration logic, LocalBackupService with SHA256 integrity and 7-year retention
- `lib/services/navigation_service.dart`: Singleton NavigatorKey + AppRoutes named route definitions
- `lib/services/hash_utils.dart`: SHA256 hash chain for Customer/Product integrity verification

### Testing:
- `test/unit/`: Unit tests organized by layer (models/, services/, widgets/)
- `flutter test`: Run all tests
- `flutter analyze --no-fatal-infos`: Code validation

## Naming Conventions

### Files:
- **Screens:** `screen_<id>_<name>.dart` — e.g., `screen_s1_setting.dart`, `screen_pj1_project_list.dart`
- **Services:** `<entity>_repository.dart` or descriptive name (e.g., `database_helper.dart`, `navigation_service.dart`)
- **Models:** `<entity>_model.dart` or `<entity>_models.dart` — e.g., `customer_model.dart`, `invoice_models.dart`
- **Widgets:** Descriptive kebab-case or camelCase — e.g., `document_card.dart`, `generic_list_screen.dart`
- **Constants:** `<category>_constants.dart` or `<purpose>.dart` — e.g., `menu_catalog.dart`, `mail_templates.dart`

### Directories:
- All lowercase with underscores: `lib/screens/`, `lib/services/`, `lib/models/`, `lib/widgets/`
- Nested test directories follow layer pattern: `test/unit/models/`, `test/unit/services/`

## Where to Add New Code

### New Feature Screen:
- **Primary code:** `lib/screens/screen_<2-3char-id>_<name>.dart`
- **Model (if new entity):** `lib/models/<entity>_model.dart`
- **Repository (if new entity):** `lib/services/<entity>_repository.dart`
- **Register in menu:** `lib/constants/menu_catalog.dart` (add to appropriate category)
- **Tests:** `test/unit/widgets/screen_<id>_<name>_test.dart` or `test/unit/services/<entity>_repository_test.dart`

### New Component/Widget:
- **Implementation:** `lib/widgets/<widget_name>.dart`
- **Usage:** Import from `../widgets/<widget_name>` in screen files

### Utilities:
- **Shared helpers:** `lib/utils/<utility_name>.dart` (currently only `build_expiry_info.dart`)
- **Constants:** `lib/constants/<category>.dart` (currently 6 files)

### Feature Module:
- **Implementation:** `lib/modules/<module_name>_module.dart`
- **Register dashboard cards in:** Dashboard screen (via FeatureModule.dashboardCards)
- **Gate behind flag in:** `lib/config/app_config.dart`

## Special Directories

### lib/screens/
- **Purpose:** All 40+ UI screens
- **Generated:** No — manually created per AGENTS.md conventions
- **Committed:** Yes
- **Note:** ~44k total lines; invoice_input_screen.dart is the largest at 3078 lines

### lib/services/
- **Purpose:** Business logic and data access (~60 files)
- **Generated:** No — manually created
- **Committed:** Yes
- **Note:** DatabaseHelper singleton is the central data access point; all repositories route through it

### test/
- **Purpose:** Test suite (12 files)
- **Generated:** No — manually created
- **Committed:** Yes
- **Note:** Coverage is partial (~12 files for ~53k lines); hash chain and model tests are the most comprehensive

### lib/mothership/
- **Purpose:** Device-side shelf HTTP server for remote sync
- **Generated:** No — manually created
- **Committed:** Yes
- **Note:** Runs Dart shelf server on device; endpoints: /sync/heartbeat, /sync/hash, /chat/send, /chat/pending, /chat/ack, /status, /

### .planning/codebase/
- **Purpose:** GSD codebase analysis documents (ARCHITECTURE.md, STRUCTURE.md, etc.)
- **Generated:** Yes — by gsd-map-codebase and similar commands
- **Committed:** Yes

---

*Structure analysis: 2026-05-16*
