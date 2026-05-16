# Technology Stack

**Analysis Date:** 2026-05-16

## Languages

**Primary:**
- Dart (Flutter SDK ^3.10.7) - All application code, ~53,000 lines across ~40 screens

**Secondary:**
- SQL - SQLite queries via `sqflite` in `lib/services/database_helper.dart`

## Runtime

**Environment:**
- Flutter 3.3.10 (cross-platform: Android + iOS)

**Package Manager:**
- pub (Dart's package manager)
- Lockfile: `pubspec.lock` present

## Frameworks

**Core:**
- Flutter - UI framework, material design widgets
- Provider / ValueNotifier - State management (ValueNotifier-based pattern throughout)

**Testing:**
- `flutter_test` (Flutter built-in test framework)
- `mockito` - Mocking in tests
- Test files: `test/` directory with widget and unit tests

**Build/Dev:**
- `flutter build apk` - APK build pipeline
- `flutter analyze --no-fatal-infos` - Static analysis (infos suppressed)
- `path_provider` - Cross-platform file path resolution

## Key Dependencies

**Critical:**
- `sqflite: ^2.3.x` - SQLite database engine for local persistence (`gemi_invoice.db`)
- `crypto` - SHA-256 hashing for backup integrity verification
- `uuid` - UUID generation for node IDs and auth tokens
- `shared_preferences` - App settings and cached token storage
- `http` - HTTP client for API calls (Mothership, Google APIs, SMTP)
- `mailer` - SMTP email sending capability
- `path` - Cross-platform path manipulation (`dart:io` path utilities)

**PDF/Document Generation:**
- `pdf` - PDF generation for invoices and documents
- `printing` - Print/PDF export functionality
- `share_plus` - File sharing capability

**Media/Camera:**
- `image_picker` - Image selection from gallery
- `camera` - Camera capture for photo attachments

**UI/UX:**
- `intl` - Internationalization and date formatting (Japanese locale)
- `flutter_svg` - SVG icon support
- `cached_network_image` - Network image caching (if used)

**File/Storage:**
- `path_provider` - Platform-specific directory paths (Download, Documents)
- `file_picker` - File selection dialogs for import/export

## Key Service Architecture Files

| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry point, service initialization, module registration |
| `lib/services/database_helper.dart` | SQLite CRUD operations, schema management, migrations |
| `lib/services/auth_repository.dart` | Local authentication with UUID tokens |
| `lib/services/mothership_client.dart` | Remote heartbeat and hash push to Mothership server |
| `lib/services/google_account_service.dart` | Google Sign-In integration (singleton) |
| `lib/services/google_api_service_base.dart` | Base class for Google API auth (token refresh, Bearer headers) |
| `lib/services/gmail_sync_client.dart` | Gmail-based chat/invoice sync via raw MIME envelopes |
| `lib/services/drive_backup_service.dart` | Google Drive DB backup and restore |
| `lib/services/email_notification_service.dart` | SMTP email notifications via mailer package |
| `lib/services/auto_backup_service.dart` | Scheduled local + Drive backup orchestration |
| `lib/modules/feature_module.dart` | Feature module abstraction for plugin-style architecture |

## Configuration

**Environment:**
- App settings stored in `SharedPreferences` (JSON key-value pairs)
- Google OAuth credentials stored as `google_client_id` / `google_client_secret` in prefs
- Database path resolved via `path_provider` + platform-specific paths
- No `.env` file pattern detected — config is app-prefs-based

**Build:**
- `pubspec.yaml` - Main dependency and asset declaration
- `analysis_options.yaml` - Dart linting rules (flutter analyze configuration)
- Platform configs: `android/`, `ios/` standard Flutter platform directories

## Platform Requirements

**Development:**
- Flutter SDK ^3.10.7
- Dart SDK compatible with Flutter 3.3.10
- Android emulator/device or iOS simulator for testing
- SQLite database file: `gemi_invoice.db` (version 33)

**Production:**
- Android (primary target) — `/storage/emulated/0/Download` for file I/O
- iOS (secondary target) — `Documents` folder fallback
- APK build via `flutter build apk`
- Build expiry script: `scripts/build_with_expiry.sh` (supports debug/profile/release)

## Module System

The app uses a plugin-style module system defined in `lib/modules/feature_module.dart`:
- Modules can register screens, services, and menu entries
- Feature modules are loaded dynamically at startup via `main.dart`
- Enables optional feature toggling without code changes

---

*Stack analysis: 2026-05-16*
