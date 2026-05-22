# External Integrations

**Analysis Date:** 2026-05-22

## APIs & External Services

### Google Services (Primary External Integration)

**Authentication:**
- Package: `google_sign_in: ^6.1.0` (actual 6.3.0)
- Implementation: `lib/services/google_account_service.dart` — Singleton pattern via `GoogleAccountService.instance`
- Scopes requested: `email`, `drive.file`, `gmail.send`, `gmail.modify`
- Token storage: SharedPreferences (`google_access_token`, `google_refresh_token`, `google_token_expiry`)
- Token refresh: `GoogleApiServiceBase._refreshAccessToken()` hitting `https://oauth2.googleapis.com/token`
- OAuth setup documented in `README.md` (Google Cloud Console, SHA-1 fingerprint)
- `google-services.json` present in project root for Android Firebase/Google Play Services

**Google Drive Backup:**
- Package: `googleapis: ^12.0.0` (Drive v3 API)
- Implementation: `lib/services/drive_backup_service.dart`
- Backup path: `SalesAssist Backups/<clientId>/<filename>_<timestamp>.db`
- File types: SQLite database snapshots, error/log reports
- Operations: upload, list, download, restore with integrity checks
- Triggered by: `lib/services/auto_backup_service.dart` (every 24h background) and manual via settings

**Gmail Sync (Sync Transport):**
- Package: `googleapis: ^12.0.0` (Gmail v1 API)
- Implementation: `lib/services/gmail_sync_client.dart`
- Sync mechanism: Gmail envelopes via `GmailSyncEnvelope` (`lib/models/gmail_sync_envelope.dart`)
- Envelope format: JSON → (optionally gzip) → Base64URL, subject prefix `[Sync:v1] <messageId>#<sequence>`
- Payload types: `chat_message`, `invoice_snapshot` (invoice push currently disabled)
- Encoding modes: `gzipBase64` (default), `base64Only`, `plainJson` — configurable in settings
- Polling: 10-second interval via `ChatSyncScheduler` in `lib/services/chat_sync_scheduler.dart`
- Label management: Auto-creates/uses `SalesAssist Sync` Gmail label, moves processed messages out of INBOX
- BCC required: `gmail_sync_bcc_address` must be set in `AppSettingsRepository`

### Mothership Server (お局様 LAN Server)

**Direct Connection Sync:**
- Implementation: `lib/services/mothership_client.dart`
- Endpoints: `/sync/heartbeat`, `/sync/hash`, `/chat/send`, `/chat/pending`, `/chat/ack`
- Auth: API key passed as `x-api-key` header
- Client ID: UUID v4 generated on first use, stored in SharedPreferences

**Chat Transport:**
- Implementation: `lib/services/mothership_chat_client.dart`
- Discovery: `lib/services/mothership_discovery_service.dart` — GPS-based auto-detection of mothership (100m-2000m range)
- Config: host URL + password stored in SharedPreferences (`external_host`, `external_pass`)

**Transport Selection:** `SyncTransportMode` enum (`lib/models/sync_preferences.dart`) — `gmailOnly`, `directOnly`, `auto` (GPS-preferred with fallback to Gmail)

## Data Storage

**Primary Database:**
- SQLite via `sqflite: ^2.3.0`
- DB file: `販売アシスト 1 号.db` on Android shared storage (`/storage/emulated/0/Documents/販売アシスト 1 号/`)
- iOS: app Documents folder via `path_provider`
- Current version: 66 (in `DatabaseHelper._databaseVersion`)
- Backup to `/storage/emulated/0/Download/` with SHA-256 integrity verification
- 7-year retention policy (`LocalBackupService`) per Japanese electronic bookkeeping law

**Settings Storage:**
- `shared_preferences: ^2.2.2` — All app settings, credentials, tokens
- Managed via `lib/services/app_settings_repository.dart`

**File Storage:**
- Default for user-facing file operations: system Download folder (`/storage/emulated/0/Download/`) on Android
- iOS: `getApplicationDocumentsDirectory()`
- Database storage: separate Documents folder specific to app (`/storage/emulated/0/Documents/販売アシスト 1 号/`)
- Permission management: `lib/services/storage_permission_service.dart` (handles Android 13+ MANAGE_EXTERNAL_STORAGE)

**Caching:** Not used (SQLite is the primary data store, no Redis/memcache layer)

## Authentication & Identity

**Auth Provider:**
- Google Sign-In (`google_sign_in`) — Primary auth for cloud services
- Mothership API key — Direct connection auth (shared secret)
- No custom user auth system — Google identity used as the primary user context
- Auth state stored in `GoogleAccountService` (singleton, `lib/services/google_account_service.dart`)
- OAuth token auto-refresh via `GoogleApiServiceBase` (`lib/services/google_api_service_base.dart`)
- Multi-account support: force account picker, silent sign-in restoration

## Monitoring & Observability

**Logging:**
- `debugPrint()` throughout — No structured logging framework
- Activity logging to SQLite via `lib/services/activity_log_repository.dart` (audit trail)
- `BuildExpiryInfo` — Build timestamp validation with lifespan enforcement

**Error Tracking:** Not detected (no Sentry, Crashlytics, or similar)

## CI/CD & Deployment

**Hosting:**
- Android APK builds via Flutter CLI
- `scripts/build_with_expiry.sh` — Wraps `flutter analyze --no-fatal-infos && flutter build apk` with `--dart-define` for expiry
- Build modes: `debug`, `profile`, `release`
- Lifespan: default 90 days (configurable via script argument)

**CI Pipeline:** Not detected (no CI config files found)

## Email Integration

**Native Mail App:**
- Package: `flutter_email_sender: ^6.0.3`
- Implementation: `lib/services/invoice_email_sender.dart`
- Flow: Generate PDF → Save to temp → Open native mail composer with PDF attachment
- BCC: Configured in `S1:設定 > メール設定`, stored in `AppSettingsRepository`

**SMTP (Direct):**
- Package: `mailer: ^6.0.1`
- Implementation: `lib/services/email_notification_service.dart`
- Use case: Automated notifications (quote, order, invoice, delivery, stock shortage)
- SMTP server config hardcoded as dev defaults (smtp.example.com — placeholder)

## File Export/Import

**PDF Document Generation:**
- Package: `pdf: ^3.11.3`
- Implementation: `lib/services/pdf_generator.dart`
- Document types: Estimates, Orders, Invoices, Delivery notes, Receipts
- Features: Company info + seal image overlay, QR code (content hash), bank account info, tax display modes
- Font: IPAexGothic embedded for Japanese text

**Printing:**
- Package: `printing: ^5.14.2`
- Service: `lib/services/print_service.dart` (file exists, empty)
- PDF preview: `lib/widgets/invoice_pdf_preview_page.dart`

**File Picker:**
- Package: `file_picker: ^8.1.2`
- For import of CSV/Excel data and DB restore file selection

**File Sharing:**
- Package: `share_plus: ^12.0.1` — Native share sheet
- Package: `open_filex: ^4.7.0` — Open generated PDFs in external viewers

## Image Handling

**Camera:**
- Package: `camera: ^0.11.0+1` — Seal/stamp photo capture via `lib/widgets/seal_camera_screen.dart`
- Delivery photo capture: `lib/services/camera_delivery_photo_service.dart`

**Image Picker:**
- Package: `image_picker: ^1.2.1` — Gallery selection for profile images, product photos

**Barcode Scanner:**
- Package: `mobile_scanner: ^7.2.0` — Barcode/QR scanning in `lib/screens/barcode_scanner_screen.dart`

## Webhooks & Callbacks

**Incoming:**
- None detected (app is offline-first, not a receiver)

**Outgoing:**
- Mothership heartbeat: `POST /sync/heartbeat` on app launch
- Mothership hash chain: `POST /sync/hash` on data mutation
- Gmail envelopes: Each outbound sync message is a new Gmail draft/send

## Network & Offline Strategy

**Architecture:** Offline-first — all data in local SQLite, sync is optional
**Network Detection:** Not via dedicated package; connection errors silently handled (try-catch with `debugPrint`)
**Offline Behavior:** All CRUD operations work without network; sync runs best-effort in background
**Sync Triggers:**
- App launch (heartbeat, 24h backup, chat sync start)
- Timer-based (chat sync every 10s via `ChatSyncScheduler`)
- Manual via settings screen

## Environment Configuration

**Required env vars (build-time):**
- `APP_BUILD_TIMESTAMP` — UTC ISO 8601 datetime (embedded by build script)
- `APP_BUILD_LIFESPAN_DAYS` — Integer, days until expiry (default: 90)

**Optional build-time vars:**
- `APP_VERSION`, `ENABLE_DEBUG_FEATURES`, `API_ENDPOINT`
- `ENABLE_MASTER_MODULE`, `ENABLE_SALES_MODULE`, `ENABLE_PURCHASE_MODULE`, etc.

**Runtime credentials (stored in SharedPreferences):**
- `external_host` — Mothership server URL
- `external_pass` — Mothership API key
- `google_client_id` / `google_client_secret` — OAuth credentials
- `google_access_token` / `google_refresh_token` — OAuth tokens
- `gmail_sync_bcc_address` — Sync BCC recipient

**Secrets location:**
- OAuth client credentials: SharedPreferences (set via settings UI)
- `google-services.json` — Committed to repo (Android Firebase config)
- `.env` files: Explicitly blacklisted (see README: "`.env` はデフォルトでブラックリスト化")

---

*Integration audit: 2026-05-22*
