# External Integrations

**Analysis Date:** 2026-05-16

## APIs & External Services

### Mothership Remote Server (Custom)
- **Purpose:** Node heartbeat registration and periodic hash synchronization for distributed backup coordination
- **Implementation:** `lib/services/mothership_client.dart`
- **Protocol:** HTTP POST to configurable remote URL
- **Heartbeat:** Periodic registration of node ID with server
- **Hash Push:** Periodic SHA-256 hash upload for integrity verification across nodes
- **Auth:** Node UUID (`ensureClientId()`) used as identity
- **Config:** Remote URL stored in app settings or build-time constant

### Google Ecosystem (OAuth 2.0)
- **Purpose:** Account authentication, cloud backup, and email-based data sync
- **SDK/Client:** `googleapis` package + `google_sign_in` package
- **Auth:** OAuth 2.0 flow via `GoogleSignIn`, tokens cached in SharedPreferences

**Sub-services:**

| Service | SDK | Purpose | Scopes |
|---------|-----|---------|--------|
| Google Sign-In | `google_sign_in: ^6.x` | User authentication, token acquisition | `email`, profile |
| Google Drive | `googleapis: ^11.x` (drive/v3) | Database backup upload/download/restore | `drive.file` |
| Gmail | `googleapis: ^11.x` (gmail/v1) | Chat message sync via email envelopes | `gmail.send`, `gmail.modify` |

**Token management:**
- Access token stored in `shared_preferences` key `google_access_token`
- Refresh token stored in `google_refresh_token`
- Token expiry in `google_token_expiry` (with 5-minute buffer)
- Auto-refresh via `_refreshAccessToken()` calling `oauth2.googleapis.com/token`
- Client credentials: `google_client_id`, `google_client_secret`

**Implementation files:**
| File | Purpose |
|------|---------|
| `lib/services/google_account_service.dart` | Google Sign-In singleton, login/logout, user info |
| `lib/services/google_api_service_base.dart` | Token refresh, Bearer auth header injection, HTTP client wrapper |
| `lib/services/gmail_sync_client.dart` | Gmail raw MIME envelope sync (chat messages, invoice snapshots) |
| `lib/services/drive_backup_service.dart` | Drive folder hierarchy, DB upload/download/restore |

### SMTP Email (Mailer)
- **Purpose:** Send email notifications (invoice confirmations, alerts)
- **SDK/Client:** `mailer` package (Dart SMTP client)
- **Implementation:** `lib/services/email_notification_service.dart`
- **Auth:** User-configured SMTP credentials stored in app settings
- **Config keys:** `mail_send_method_smtp`, SMTP host/port/credentials
- **Transport modes:** Direct SMTP or Gmail API (via Google APIs)

## Data Storage

### Primary Database
- **Type:** SQLite local database
- **Connection:** Via `sqflite` package
- **File:** `gemi_invoice.db` (version 33)
- **Location:** App's internal storage (resolved via `path_provider`)
- **Client/ORM:** Raw SQL queries through `DatabaseHelper` (`lib/services/database_helper.dart`) — no ORM layer
- **Schema migrations:** Handled in `onUpgrade` callback with version checks

### Local Backup Storage
- **Type:** SHA-256 integrity-verified local file backups
- **Location:** App's internal storage directory + system Download folder for exports
- **Implementation:** `lib/services/database_helper.dart` (backup methods) + `lib/services/auto_backup_service.dart`
- **Integrity:** SHA-256 hash comparison via `crypto` package

### Cloud Backup (Google Drive)
- **Type:** Google Drive file storage
- **Folder structure:** `SalesAssist Backups/` → `<node_id>/` → timestamped DB files
- **Implementation:** `lib/services/drive_backup_service.dart`
- **Operations:** Upload, list, download, restore (full DB recovery)

### App Settings & Cache
- **Type:** SharedPreferences key-value store
- **Contents:** Theme preferences, SMTP config, Google OAuth tokens, sync settings, feature flags
- **Implementation:** `shared_preferences` package throughout services

## Authentication & Identity

**Auth Provider:** Hybrid — local SQLite auth + optional Google OAuth

**Local Auth:**
- **Implementation:** `lib/services/auth_repository.dart`
- **Mechanism:** UUID-based tokens stored in SQLite + SharedPreferences
- **User model:** Local user records with email/password (SQLite)
- **Session:** In-memory token validation, persisted across app restarts via prefs

**Google OAuth:**
- **Implementation:** `lib/services/google_account_service.dart` (singleton)
- **Flow:** Google Sign-In → access/id token → stored in SharedPreferences
- **Token lifecycle:** Auto-refresh with 5-minute expiry buffer
- **Scopes:** `email`, `drive.file`, `gmail.send`, `gmail.modify`

## Monitoring & Observability

**Error Tracking:**
- No dedicated error tracking SDK detected (e.g., Sentry, Firebase Crashlytics)
- Errors logged via `debugPrint()` in service classes
- Error reports can be uploaded to Google Drive as files (`drive_backup_service.uploadErrorReport()`)

**Logs:**
- **Approach:** `debugPrint()` throughout services with prefixed tags (e.g., `[GmailSync]`, `[DriveBackup]`, `[GoogleAPI]`)
- **Export:** Log files can be backed up to Google Drive via `uploadErrorReport()`
- No structured logging framework detected

## CI/CD & Deployment

**Hosting:**
- Not applicable — this is a standalone mobile app (APK), not a web service
- Distribution: Direct APK install or private distribution channel

**Build Pipeline:**
- Script: `scripts/build_with_expiry.sh` (accepts `debug|profile|release`)
- Verification: `flutter analyze --no-fatal-infos` before commits
- Manual build: `flutter build apk`

## Environment Configuration

### Required env vars / settings

| Setting | Storage | Purpose |
|---------|---------|---------|
| Mothership URL | App settings or code constant | Remote heartbeat target |
| Google Client ID/Secret | SharedPreferences (`google_client_id`, `google_client_secret`) | OAuth 2.0 credentials |
| SMTP Host/Port/User/Pass | App settings (`mail_send_method_smtp` and related keys) | Email notification server |
| Database path | Resolved at runtime via `path_provider` | SQLite file location |

### Secrets location
- **Google OAuth:** Stored in `SharedPreferences` after user login (access token, refresh token, client credentials)
- **SMTP credentials:** Stored in app settings SharedPreferences
- **No `.env` files** — all secrets are app-prefs-based
- ⚠️ **Security note:** Tokens and credentials stored in plain-text SharedPreferences with no encryption layer detected

## Webhooks & Callbacks

**Incoming:**
- None detected — this is a mobile-first client app, not a webhook consumer

**Outgoing:**
| Service | Endpoint | Trigger |
|---------|----------|---------|
| Mothership server | Configurable remote URL (HTTP POST) | Periodic heartbeat + hash push |
| Google OAuth2 token endpoint | `https://oauth2.googleapis.com/token` | Token refresh |
| Gmail API | `gmail.googleapis.com/gmail/v1/users/{userId}/messages` | Chat/invoice sync |
| Google Drive API | `www.googleapis.com/upload/drive/v3/files` | DB backup upload/restore |
| SMTP server | Configurable host:port (via mailer) | Email notifications |

## Sync Architecture (Gmail-based)

The app implements a unique Gmail-envelope-based sync protocol for cross-device data synchronization:

1. **Envelope format:** JSON payload wrapped in MIME email with custom headers (`X-Client-Id`, `X-Sequence`, `X-Envelope-Encoding`)
2. **Encoding:** Base64-encoded raw MIME sent as BCC to self (`_defaultSubjectPrefix = "[Sync:v1]"`)
3. **Payload types:** `chat_message` and `invoice_snapshot`
4. **Transport modes:** Direct SMTP or Gmail API (configurable per `SyncTransportMode`)
5. **Conflict resolution:** Client ID comparison prevents self-messages; sequence numbers track ordering
6. **Status:** Invoice push is currently disabled (`"receiver not available"`), chat sync active

**Implementation:** `lib/services/gmail_sync_client.dart` — reads/writes `ChatMessage` and `InvoiceSyncPayload` models

---

*Integration audit: 2026-05-16*
