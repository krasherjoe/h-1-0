# Codebase Concerns

**Analysis Date:** 2026-05-22

## Tech Debt

### 1. Massive File Sizes Violating Project Conventions

The project defines size limits in `AGENTS.md` (1,200 lines for screens, 800 for services), but 5 files exceed the screen limit and 2 exceed the service limit. These monolithic files are the most actively developed and hardest to maintain.

**Screens exceeding 1,200 line limit:**
- `lib/screens/invoice_input_screen.dart` — **2,971 lines** (248% of limit), 39 `setState` calls, complex build tree
- `lib/screens/customer_master_screen.dart` — **1,717 lines** (143% of limit)
- `lib/screens/settings_screen.dart` — **1,670 lines** (139% of limit)
- `lib/screens/screen_pj2_project_detail.dart` — **1,393 lines** (116% of limit)
- `lib/screens/invoice_detail_page.dart` — **1,326 lines** (111% of limit)

**Services exceeding 800 line limit:**
- `lib/services/database_helper.dart` — **3,773 lines** (472% of limit), 65 migration steps
- `lib/services/invoice_repository.dart` — **1,169 lines** (146% of limit), mixes SQL and business logic
- `lib/services/isolate_service.dart` — **1,063 lines** (133% of limit)

**Impact:** Poor navigability, high cognitive load, merge conflicts, high risk of regressions when modifying. The `invoice_input_screen.dart` is nearly 3,000 lines with 39 `setState()` calls — any single change risks breaking unrelated features.

**Fix approach:** Extract sub-widgets (per AGENTS.md child widget pattern), split into feature-specific files, move business logic from screens to services.

---

### 2. Stale Project Documentation

`AGENTS.md` states database version 45 — actual version in `lib/services/database_helper.dart:573` is **version 66**. The discrepancy means documentation cannot be trusted for version-sensitive operations.

**Files:** `AGENTS.md` (line referencing "v45"), `lib/services/database_helper.dart:573`
**Impact:** Migration scripts targeting v45 will fail on actual v66 databases.
**Fix approach:** Audit and update all version references in documentation.

---

### 3. Print-Based Debugging in Production Code

**Severity: HIGH**

The `analysis_options.yaml` has `avoid_print` commented out (default disabled). This has allowed at least 30+ `print()` statements to accumulate across production code:

Key examples:
- `lib/screens/company_info_screen.dart:190-191` — `print('DEBUG: _save() ...')` — debugging registration number serialization in production
- `lib/screens/customer_master_screen.dart:59-60,414-415,640,655-656` — stack traces printed to console on error
- `lib/services/company_repository.dart:34-137` — 8 `print('DEBUG: ...')` statements logging company_info queries
- `lib/services/camera_delivery_photo_service.dart` — 8 `print()` error handlers instead of structured logging

**Impact:** Console noise masks real errors, sensitive data may leak to logcat/console, no production-grade error monitoring.

**Fix approach:** Replace `print()` with structured logging (Logger package). Enable `avoid_print` lint rule. Route all errors through a centralized error reporting service.

---

### 4. Massive Widget Build Trees with Deep Nesting

The `lib/screens/invoice_input_screen.dart` contains an extremely deep widget tree. The `build()` method at line 704 is hundreds of lines with nesting 15+ levels deep. This causes:

- Poor Flutter rebuild performance (large subtrees rebuilt on every `setState`)
- Extreme difficulty reading/maintaining the widget hierarchy
- No widget extraction for reusable UI patterns

**Impact:** Perceptible UI jank on form-heavy screens, slow development velocity for UI changes.

**Fix approach:** Extract logical widget groups into separate StatefulWidget/StatelessWidget files following the `_part.dart` pattern described in AGENTS.md.

---

### 5. 102 AppBar Declarations — Duplication Pattern

**Severity: MEDIUM**

`lib/screens/` contains ~102 `AppBar(` instances across screens. Each screen re-declares AppBar with similar styling, colors, and patterns. AGENTS.md explicitly identifies this as a refactoring target.

**Impact:** Theming changes require touching every screen. Inconsistent AppBar behavior across the app.

**Fix approach:** Create a shared `AppBarBuilder` in `lib/widgets/` as recommended by AGENTS.md DocumentColors pattern.

---

## Security Considerations

### 1. Hardcoded SMTP Credentials

**Severity: CRITICAL**

`lib/services/email_notification_service.dart:13-21` contains hardcoded SMTP credentials:

```dart
_smtpServer = SmtpServer(
  'smtp.example.com',
  username: 'noreply@example.com',
  password: 'password',   // ← Hardcoded credential
  port: 587,
  ignoreBadCertificate: true,  // ← Disables TLS verification
);
```

While annotated as "dummy settings", this pattern is dangerous:
- The `ignoreBadCertificate: true` disables TLS verification — a MITM risk if these are replaced with real credentials
- `password: 'password'` is a placeholder that could be accidentally deployed
- The placeholder email addresses (`noreply@example.com`, `inventory@example.com`) appear in production code

**Fix approach:** Move SMTP config to runtime configuration or encrypted storage. Remove `ignoreBadCertificate: true` (use proper certificates). Enable TLS by default.

---

### 2. Auth Tokens Stored in SharedPreferences (Not Encrypted)

**Severity: HIGH**

`lib/services/google_account_service.dart` stores Google OAuth tokens via `saveTokens()`:
```dart
await saveTokens(
  accessToken: googleAuth.accessToken ?? '',
  refreshToken: googleAuth.idToken ?? '',
);
```

These tokens are likely stored in `SharedPreferences` (the project uses `shared_preferences: ^2.2.2` but **does not use** `flutter_secure_storage`). SQLite database (`gemi_invoice.db`) is also unencrypted on disk.

**Mothership API key** (`external_pass`) is stored similarly in `lib/services/mothership_client.dart:22` via `_settingsRepository.getString()` which also uses SharedPreferences.

**Impact:** Any app with device root access or backup access can read OAuth tokens and API keys from plain-text storage. Android backups (`adb backup`) will contain tokens in clear text.

**Fix approach:** Migrate all token storage to `flutter_secure_storage` (AES-encrypted, Keychain/Keystore-backed). Encrypt the SQLite database with `sqflite` encryption or `sembast` with encryption.

---

### 3. Placeholder Company Data in Email Templates

`lib/services/email_notification_service.dart` contains 10 repetitions of hardcoded placeholder company data:

```
株式会社XXXX<br>
住所: XXXX<br>
電話: XXXX<br>
Email: XXXX</p>
```

Also hardcoded bank info in invoice HTML template (line 454-459):
```
銀行名: XXX銀行 XXX支店
口座番号: 普通預金 1234567
口座名義: 株式会社XXXX
```

**Impact:** If shipped without proper template variable substitution, real company data would be wrong. Templates are unmaintainable.

**Fix approach:** Extract all email HTML templates to a dedicated class with proper variable injection. Use company profile repository to populate actual data.

---

## Performance Bottlenecks

### 1. Monolithic Screen Rebuilds (setState-Based State Management)

**Severity: MEDIUM**

The entire codebase uses `StatefulWidget` + `setState()` for state management. No Riverpod, Bloc, or Provider observed. Key metrics:

- `lib/screens/invoice_input_screen.dart` — 39 `setState()` calls
- `lib/screens/settings_screen.dart` — 32 `setState()` calls  
- `lib/screens/invoice_detail_page.dart` — 29 `setState()` calls
- `lib/screens/customer_master_screen.dart` — 10 `setState()` calls

**Impact:** Every `setState()` rebuilds the entire widget subtree regardless of what changed. With 2,971-line build methods, this causes unnecessary widget rebuilds and visible jank on slower devices.

**Fix approach:** Migrate to Riverpod (recommended by AGENTS.md) for granular state rebuilds. Use `const` constructors extensively. Extract frequently-changing widgets.

---

### 2. No Lazy Loading / Pagination Pattern

Database queries in screen `initState()` methods load entire datasets. Pattern observed across the codebase:

```dart
// Typical pattern in screen initState
Future<void> _loadInitialData() async {
  final result = await repository.getAll();
  setState(() => data = result);
}
```

**Impact:** Screens with large datasets will have slow initial load times and high memory usage. No scroll-based pagination or chunked loading.

**Fix approach:** Implement pagination in repositories (`LIMIT/OFFSET`), use `ScrollController` listeners for infinite scroll, and lazy-load list data.

---

### 3. Database Query Heavy Screens

`lib/services/full_text_search_service.dart` (631 lines), `lib/services/fast_search_service.dart` (630 lines), and `lib/services/advanced_search_service.dart` each perform complex SQL queries. These can block the UI thread on large datasets.

**Fix approach:** Move heavy queries to isolates using the existing `lib/services/isolate_service.dart`.

---

## Maintainability Issues

### 1. Inadequate Test Coverage (Most Critical Concern)

**Severity: CRITICAL**

For 87,194 lines of Dart code across **279 files**, there are only **14 test files**:
- 8 unit tests (models + services)
- 5 widget tests
- 1 smoke test

**No tests exist for:**
- Any screen file (all 110 screens are untested)
- `lib/services/database_helper.dart` (3,773 lines, 65 migration versions — zero tests)
- `lib/services/invoice_repository.dart` (1,169 lines — zero tests)
- `lib/services/isolate_service.dart` (1,063 lines — zero tests)
- Any sync/network code

**Impact:** Regression risk is extremely high. No safety net for the 65 database migrations. Refactoring the monolithic files is impossible to verify.

**Fix approach:** Prioritize test coverage for database migrations (v2→v66), repository layer, and the 5 largest screen files.

---

### 2. Mixed Naming Conventions

- `_databaseVersion` (line 573) — prefix underscore for private but inconsistent with surrounding code
- SharedPreferences keys use snake_case (`mail_send_method_smtp`) — consistent per AGENTS.md
- File naming mixes `screen_<id>_<name>.dart` and `<name>_screen.dart` patterns:
  - Newer: `screen_s1_theme_selection.dart`, `screen_pj1_project_list.dart`
  - Legacy: `settings_screen.dart`, `customer_master_screen.dart`
- Some `InvoiceListStyleTheme` references use `_currentListTheme` getter pattern inconsistently

**Impact:** New developers cannot predict file locations. Refactoring is confusing.

**Fix approach:** Migrate all legacy screen files to the `screen_<id>_<name>.dart` pattern. Enforce with a lint rule.

---

### 3. InvoiceInputScreen — Mixed Concerns

The 2,971-line `lib/screens/invoice_input_screen.dart` is simultaneously:
- A form input screen
- A document type switcher (見積書/受注伝票/納品書/請求書/領収書)
- A PDF generator trigger
- A data persistence layer
- A navigation hub

**Impact:** Single responsibility principle violation. Hard to test, hard to understand, every feature change risks breaking unrelated functionality.

**Fix approach:** Split by document type into separate screens/forms. Extract PDF generation, persistence, and navigation into dedicated services.

---

## Offline/Online Sync Risks

### 1. No Conflict Resolution Strategy

**Severity: HIGH**

The project advertises "offline-standalone + online sync" but sync services show no conflict resolution:

- `lib/services/mothership_chat_client.dart` — simple push-then-fetch with no merge strategy
- `lib/services/chat_repository.dart` — uses `ConflictAlgorithm.replace` (last write wins)
- `lib/services/business_profile_repository.dart:36` — `ConflictAlgorithm.replace`
- `lib/services/custom_field_repository.dart:66,216` — `ConflictAlgorithm.replace`
- No vector clocks, no timestamp-based resolution, no user-visible conflict UI

**Impact:** Concurrent edits on different devices will silently lose data. No mechanism to detect or recover from sync conflicts.

**Fix approach:** Implement version vectors or hybrid logical clocks. Add conflict detection and user-facing resolution UI. Store `updated_at` timestamps server-side for LWW comparison.

---

### 2. Google Drive Backup — Opaque Error Handling

`lib/services/drive_backup_service.dart` and `lib/screens/drive_backup_screen.dart` handle Google Drive backup/restore. The integration appears complex with no visible error recovery for:

- Network failures mid-backup
- Partial backup states (data inconsistency after interrupted backup)
- Token expiry during long backup operations

**Fix approach:** Add backup state machine with rollback capability. Implement progress tracking and resume logic.

---

## Database Migration Complexity

### 1. 65 Migration Steps in One Function

**Severity: HIGH**

`lib/services/database_helper.dart:_onUpgrade()` (line 825 onwards) contains 65 sequential `if (oldVersion < N)` blocks — one for each schema change from v2 to v66. Key concerns:

- All migrations run in **sequence within one transaction** — a failure at step 40 means all 39 previous steps are rolled back
- Migration steps are **only additive** (ALTER TABLE, CREATE TABLE) — no column removals or data transformations
- The file is 3,773 lines — finding a specific migration requires counting version blocks
- No migration tests exist

**Fix approach:** Extract each migration version into a separate function file. Write integration tests that create a v2 database and migrate through all versions to v66, verifying schema and data at each step.

---

## Dependencies at Risk

### 1. google_sign_in / googleapis — Breaking Changes

The project uses `google_sign_in: ^6.1.0` and `googleapis: ^12.0.0`. Google's Dart/Flutter auth APIs have undergone significant changes. The `googleapis_auth: ^1.4.0` package has known deprecation cycles.

**Impact:** Future Flutter SDK upgrades may break Google sign-in and backup features.

### 2. camera: ^0.11.0+1 — Pre-stable API

The `camera` plugin (used in `lib/services/camera_delivery_photo_service.dart` and `lib/screens/camera_delivery_photo_screen.dart`) has a history of breaking changes below 1.0. Android embedding v2 migration issues are common.

### 3. sqflite — No Encryption

SQLite database `gemi_invoice.db` contains business data with no encryption. `sqflite: ^2.3.0` does not support encryption natively. For a business app handling invoices, customer data, and financial records, this is a compliance concern.

### 4. No Version Upgrade Strategy Documented

Without migration tests and with 65 sequential migrations, upgrading to a different database technology (e.g., drift, sembast) would be extremely risky.

---

## Platform-Specific Issues

### 1. Hardcoded Android Download Path

**Severity: MEDIUM**

`AGENTS.md` mandates `/storage/emulated/0/Download` for Android file access. This path is hardcoded in multiple files:
- `lib/screens/restore_screen.dart:499`
- `lib/screens/screen_th2_theme_customizer.dart:224`
- `lib/screens/company_info_screen.dart:280-282`
- `lib/services/company_info_export_import.dart:14`

**Impact:** Android 11+ (API 30+) enforces scoped storage. The hardcoded `/storage/emulated/0/Download` path will **fail on Android 11+ devices** without `android:requestLegacyExternalStorage="true"` in AndroidManifest.xml. Android 14 (API 34) removes legacy storage access entirely.

**Fix approach:** Replace hardcoded paths with `getExternalStorageDirectory()` or platform channel `getDownloadsDirectory()`. Use SAF (Storage Access Framework) via `file_picker` for all file operations.

---

### 2. Scoped Storage / Permission Complexity

`lib/services/storage_permission_service.dart` handles Android storage permissions. With Android 13+ introducing granular media permissions (`READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`), the existing permission handling may fail on newer devices.

---

## Test Coverage Gaps

### 1. Zero Tests for Largest Files

| File | Lines | Tests |
|------|-------|-------|
| database_helper.dart | 3,773 | 0 |
| invoice_input_screen.dart | 2,971 | 0 |
| customer_master_screen.dart | 1,717 | 0 |
| settings_screen.dart | 1,670 | 0 |
| invoice_repository.dart | 1,169 | 0 |

### 2. No Database Migration Tests

The 65-step migration pipeline from v2→v66 has no automated verification. A single migration bug can corrupt all user data irreversibly.

### 3. No Widget/Golden Tests

Despite 30 shared widgets in `lib/widgets/`, only 2 widget tests exist. No golden/screenshot tests for visual regression.

### 4. No Integration / E2E Tests

Zero integration tests exist. The app's complex multi-screen navigation and database interactions are untested end-to-end.

### 5. No Network Mocking

Services like `lib/services/mothership_chat_client.dart` and `lib/services/mothership_client.dart` use real HTTP clients with no mock layer for testing.

**Priority for all testing gaps: HIGH**

---

## Missing Critical Features

### 1. No Analytics / Crash Reporting

No crash reporting (Sentry, Firebase Crashlytics) or analytics SDK is integrated. Bugs in the field are invisible to the development team.

**Fix approach:** Integrate Sentry (Dart SDK) for crash reporting. Add opt-in analytics for usage patterns.

### 2. No Logging Framework

All logging uses `print()` or `debugPrint()`. No log levels, no log rotation, no persistent log storage for debugging production issues.

---

*Concerns audit: 2026-05-22 — 87,194 lines across 279 Dart files, 14 test files, database version 66*
