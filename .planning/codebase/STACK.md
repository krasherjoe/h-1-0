# Technology Stack

**Analysis Date:** 2026-05-22

## Languages

**Primary:**
- Dart (>=3.10.7, <4.0.0) — All application code in `lib/`, `test/`, and `bin/`

**Secondary:**
- Shell script — `scripts/build_with_expiry.sh` (build automation with expiry date embedding)
- YAML — Project configuration (`pubspec.yaml`, `analysis_options.yaml`)

## Runtime

**Mobile/Desktop Runtime:**
- Flutter SDK ^3.10.7 (actual: >=3.38.4 per lockfile)
- Dart SDK ^3.10.7

**Package Manager:**
- `pub` (Dart package manager)
- Lockfile: `pubspec.lock` present and committed

## Frameworks

**Core:**
- Flutter (Google's UI toolkit) — All 105+ screens, 30 reusable widgets
- Material Design 3 (`useMaterial3: true`) — Used throughout `lib/main.dart` theme definitions

**PDF Generation:**
- `pdf: ^3.11.3` — Invoice/estimate/delivery note/receipt document generation in `lib/services/pdf_generator.dart`
- `printing: ^5.14.2` — PDF printing support

**Database:**
- `sqflite: ^2.3.0` (actual 2.4.2) — SQLite database access
- `sqflite_common_ffi_web: ^0.4.2+3` — Web platform FFI support
- `sqflite_common_ffi: ^2.3.2` (dev) — Desktop test support
- DB file: `販売アシスト 1 号.db` (migrated from `gemi_invoice.db`) on Android shared storage

**Testing:**
- `flutter_test` (SDK) — Widget and unit tests
- `sqflite_common_ffi ^2.3.2` (dev) — Desktop-native DB testing
- Config: `analysis_options.yaml` includes `package:flutter_lints/flutter.yaml`

## Key Dependencies

**Critical Infrastructure:**

| Package | Version | Purpose | File |
|---------|---------|---------|------|
| `sqflite` | ^2.3.0 | SQLite database layer | `lib/services/database_helper.dart` |
| `shared_preferences` | ^2.2.2 | Key-value settings persistence | `lib/services/app_settings_repository.dart` |
| `path_provider` | ^2.1.5 | Filesystem path resolution | `lib/services/database_helper.dart` |
| `http` | ^1.2.2 | HTTP requests for sync/mothership API | `lib/services/mothership_client.dart` |

**Google Ecosystem:**
| Package | Version | Purpose | File |
|---------|---------|---------|------|
| `google_sign_in` | ^6.1.0 | OAuth 2.0 sign-in | `lib/services/google_account_service.dart` |
| `googleapis` | ^12.0.0 | Gmail/Drive API client libraries | `lib/services/gmail_sync_client.dart`, `lib/services/drive_backup_service.dart` |
| `googleapis_auth` | ^1.4.0 | Auth token management | `lib/services/google_api_service_base.dart` |

**File Handling & Input:**
| Package | Version | Purpose | File |
|---------|---------|---------|------|
| `image_picker` | ^1.2.1 | Camera/gallery photo capture | Used across screens |
| `camera` | ^0.11.0+1 | Live camera preview/seal capture | `lib/widgets/seal_camera_screen.dart` |
| `file_picker` | ^8.1.2 | File selection dialogs | Import/export screens |
| `open_filex` | ^4.7.0 | Open external files | PDF preview |
| `mobile_scanner` | ^7.2.0 | Barcode/QR scanning | `lib/screens/barcode_scanner_screen.dart` |

**Email & Communication:**
| Package | Version | Purpose | File |
|---------|---------|---------|------|
| `mailer` | ^6.0.1 | SMTP email sending | `lib/services/email_notification_service.dart` |
| `flutter_email_sender` | ^6.0.3 | Native mail app intent | `lib/services/invoice_email_sender.dart` |

**Location & Sensors:**
| Package | Version | Purpose | File |
|---------|---------|---------|------|
| `geolocator` | ^14.0.2 | GPS location tracking | `lib/services/gps_service.dart` |
| `device_info_plus` | ^12.3.0 | Device info (SDK version, etc.) | `lib/services/storage_permission_service.dart` |

**UI & Utilities:**
| Package | Version | Purpose | File |
|---------|---------|---------|------|
| `intl` | ^0.20.2 | Date/currency formatting | `lib/services/pdf_generator.dart` |
| `crypto` | ^3.0.7 | SHA-256 hashing (hash chains, backup integrity) | `lib/services/database_helper.dart`, `lib/models/gmail_sync_envelope.dart` |
| `uuid` | ^4.5.1 | UUID generation for client IDs | `lib/services/mothership_client.dart` |
| `share_plus` | ^12.0.1 | Native share sheet integration | Document sharing |
| `url_launcher` | ^6.3.2 | Open URLs externally | Help/dial links |
| `cupertino_icons` | ^1.0.8 | iOS-style icons | `lib/main.dart` |
| `permission_handler` | ^12.0.1 | Runtime permission requests | `lib/services/storage_permission_service.dart` |
| `flutter_contacts` | ^1.1.9+2 | Phonebook contact access | Contact picker screens |
| `package_info_plus` | ^9.0.0 | App version info | Settings/about screens |
| `shelf` / `shelf_router` | ^1.4 | HTTP server (mothership) | `bin/mothership_server.dart` |

## Configuration

**Build Configuration:**
- `pubspec.yaml` — Package manifest, dependencies, fonts
- `analysis_options.yaml` — Dart/Flutter lint rules (flutter_lints)
- `google-services.json` — Firebase/Google Services (Android)

**Environment Configuration:**
- `--dart-define` flags at build time via `scripts/build_with_expiry.sh`:
  - `APP_BUILD_TIMESTAMP` — UTC build timestamp (expiry enforcement)
  - `APP_BUILD_LIFESPAN_DAYS` — Build lifespan in days (default: 90)
  - `APP_VERSION`, `ENABLE_DEBUG_FEATURES`, `API_ENDPOINT` — via `lib/config/app_config.dart`
- `MothershipClient` host/password: stored in SharedPreferences (`external_host`, `external_pass` keys)
- Google OAuth credentials: stored in SharedPreferences (`google_client_id`, `google_client_secret`)

**Lint Rules:**
- `flutter_lints: ^6.0.0` — Standard Flutter lint package
- `analysis_options.yaml` uses `package:flutter_lints/flutter.yaml` include

## Database

**Engine:** SQLite via `sqflite` package
**DB File:** `販売アシスト 1 号.db` (stored in `/storage/emulated/0/Documents/販売アシスト 1 号/` on Android)
**Current Version:** 66 (in code), migrated from v1 through 65+ upgrade steps in `DatabaseHelper._onUpgrade()`
**Singleton pattern:** `DatabaseHelper` uses `factory DatabaseHelper() => _instance;` with `_databaseFuture` caching to prevent concurrent init
**Schema Approach:** `ALTER TABLE` only — never `DROP TABLE` — to preserve existing data through upgrades

## State Management

**Primary approach:** `setState()` in StatefulWidget — used in `lib/main.dart`, all 105+ screens
**Secondary (notifications):** `ValueListenableBuilder` — used in `lib/main.dart` for theme changes via `AppThemeController.instance.notifier`
**Progress/Background:** `Listenable` pattern — `BackupProgressNotifier` for backup status
**Constants-driven module enablement:** `lib/config/app_config.dart` uses `bool.fromEnvironment()` for feature flags

## Fonts & Theming

**Primary Font:** IPAexGothic (`assets/fonts/ipaexg.ttf`) — Japanese text rendering
**Theme modes:** 5 variants defined in `lib/main.dart`:
- `light` (default, indigo/blue-grey) — `MaterialColor`
- `dark` (dark indigo) — `Brightness.dark`
- `dark-gray` (dark grey surfaces) — `Brightness.dark`
- `gray` (light grey) — `Brightness.light`
- `custom` (user-customizable colors) — Stored in `SharedPreferences` via `AppThemeController`
- `system` (follow OS) — `ThemeMode.system`
**All modes:** Material 3, `visualDensity.adaptivePlatformDensity`, `fontFamily: 'IPAexGothic'`

## Platform Support

**Target Platforms:**
- Android (primary target — APK build via `scripts/build_with_expiry.sh`)
- iOS — platform template present in `ios/`
- Linux — platform template present (desktop support)
- macOS — platform template present
- Windows — platform template present
- Web — partial support (`kIsWeb` checks throughout code, `sqflite_common_ffi_web`, `shelf` for server-side)

**Build Pipeline:**
```bash
flutter pub get
flutter analyze --no-fatal-infos
flutter build apk          # Production APK
./scripts/build_with_expiry.sh release [days]   # With expiry
```

---

*Stack analysis: 2026-05-22*
