# クロスカット関心事項（Cross-Cutting Concerns）

## セキュリティ

### 認証・認可
- **ユーザー管理**: `lib/services/auth_repository.dart` — SQLite の `users`/`roles` テーブルでユーザー管理。UUID v4 で ID 生成。
- **セッション管理**: SharedPreferences にセッション情報を保存（キー命名規則: スネークケース）。
- **API キー**: Mothership サーバーは `x-api-key` ヘッダーで認証（`lib/mothership/server.dart`）。

### ⚠️ セキュリティリスク

#### 1. デフォルト API キー
```dart
// lib/mothership/config.dart:15
final apiKey = env['MOTHERSHIP_API_KEY'] ?? 'TEST_MOTHERSHIP_KEY';
```
**深刻度**: 高 — 本番環境でデフォルトキーが使用されるリスク。

#### 2. XSS（XSS）脆弱性
```dart
// lib/mothership/server.dart:133
return '<tr><td>${status.clientId}</td>...';
```
ダッシュボード画面で `clientId` がエスケープなしで HTML に挿入されている。
**深刻度**: 中 — サーバー側（Flutter/Dart）で実行されるため、外部攻撃ベクトルは限定的だが、クライアントからの同期データがそのまま表示される。

#### 3. データベース暗号化不在
SQLite データベース（`gemi_invoice.db`）はプレーンテキストで保存。`crypto` パッケージはバックアップ整合性検証（SHA256）にのみ使用。
**深刻度**: 中 — Android 端末が/root化されている場合、DB ファイルがそのまま読み取り可能。

#### 4. HTTPS なし
Mothership サーバーはポート 8787 で平文 HTTP を使用。
**深刻度**: 高 — ローカルネットワーク内の通信が傍受可能。

### 第三者統合のセキュリティ
- **Google OAuth/Drive/Gmail API**: `lib/services/google_api_service_base.dart` ベースクラス経由。OAuth トークンは SharedPreferences に保存される可能性あり。
- **SMTP メール**: `lib/services/email_notification_service.dart` — SMTP 認証情報が必要。
- **バックアップ整合性**: SHA256 ハッシュによるバックアップファイル検証（`lib/services/database_helper.dart:106`）。

### ネットワークセキュリティ
- API キーヘッダーベース（Transport Layer Security なし）
- TLS/SSL 証明書のピンニングは確認できず
- Google APIs は公式 SDK 経由（OAuth 2.0 処理はライブラリに委譲）

## パフォーマンス

### ホットスポット分析

| ファイル | 行数 | リスク |
|---------|------|--------|
| `lib/main.dart` | ~35,300 | ⚠️ 巨大 — モジュール化検討 |
| `lib/services/database_helper.dart` | 3,621 | ⚠️ 大規模 — 分割候補 |
| `lib/screens/customer_master_screen.dart` | ~59,700 | 🔴 非常に巨大 — リファクタリング優先度高 |
| `lib/screens/company_info_screen.dart` | ~47,400 | 🔴 非常に巨大 |
| `lib/screens/advanced_search_screen.dart` | ~21,500 | ⚠️ 大規模 |

### データベースパフォーマンス
- **インデックス**: `database_helper.dart` でクエリ最適化が行われている可能性あり（要詳細調査）
- **トランザクション**: バックアップ処理でファイルコピー前にトランザクション開始を確認
- **バッチ操作**: 大量データ読み込み時のページネーション実装状況要確認

### UI パフォーマンス
- `GenericListScreen` テンプレートによる一覧表示の標準化（`lib/widgets/generic_list_screen.dart`）
- カード形式表示（`DocumentCard`, `InvoiceListA2Card`）— 大規模リストでのスクロールパフォーマンス要検証
- PDF 生成（`pdf` パッケージ）— 請求書作成時のメモリ使用量に注意

### メモリ管理
- 画像処理（`image_picker`, `camera`）— カメラ撮影時のメモリ確保/解放パターン要確認
- バックアップファイルの読み込み（`File.readAsBytes()`）— 大規模 DB ファイルでの OOM リスク

## 信頼性・エラーハンドリング

### オフラインファースト設計
- **ローカル SQLite がプライマリストレージ** — サーバー接続が切れても稼働継続
- **同期**: Mothership サーバーとのハッシュベースの同期（`/sync/hash`, `/sync/heartbeat`）
- **Google Drive バックアップ**: オプションのクラウドバックアップ（`DriveBackupService`）

### バックアップ & リカバリ
- **自動ローカルバックアップ**: 毎日実行、7年間保存（電子帳簿保存法対応）
- **SHA256 整合性検証**: バックアップファイルのハッシュを別途保存
- **手動削除推奨**: 日付暴走時の誤削除防止のため自動削除は行わない（`database_helper.dart:118-120`）
- **Google Drive バックアップ**: ノード別フォルダ構造、エラーレポートもアップロード可能

### エラーリカバリ
- `if (!mounted) return;` パターン — StatefulWidget の非同期処理で必須
- try-catch + debugPrint によるエラーログ記録が標準パターン
- バックアップ失敗時は null を返す（静黙失敗の可能性あり）

### ロギング & モニタリング
- `ActivityLogRepository`: アクティビティログの記録・検索機能
- `AuditLogRepository`:監査証跡の管理
- エラーレポートの Google Drive アップロード対応

## データ整合性

### トランザクション管理
- SQLite のトランザクション API を直接使用（`database_helper.dart`）
- バックアップ処理でファイルコピー前の整合性確認

### 検証
- バックアップファイルの SHA256 ハッシュ比較による整合性検証
- データベースマイグレーション: バージョン番号管理 + `ALTER TABLE` のみ使用（`DROP TABLE` なし）

### 同期整合性
- **ハッシュベース検出**: クライアントが DB ハッシュをサーバーに送信（`/sync/hash`）
- **heartbeat 机制**: クライアントの存続状態を監視
- **競合解決**: 詳細な戦略は要確認 — 現時点では最後の書き込みが勝つ（LWW）の可能性

## プラットフォーム固有の関心事

### Android
- ファイルシステム: `/storage/emulated/0/Download` をダウンロードフォルダとして使用
- 権限: カメラ、ストレージ、ネットワーク権限が必要
- バックアップ: Downloads フォルダに直接保存（ユーザーがアクセス可能）

### iOS
- ファイルシステム: `Documents` フォルダをフォールバックとして使用
- バックアップ: Documents/backups サブフォルダ
- システムダウンロードフォルダの代替対応

## リスク評価（優先度順）

| # | リスク | 深刻度 | 影響範囲 | 推奨対策 |
|---|--------|--------|----------|----------|
| 1 | デフォルト API キー | 🔴 高 | サーバー通信 | 環境変数強制、起動時チェック |
| 2 | HTTPS なし通信 | 🔴 高 | ネットワークセキュリティ | TLS 有効化 |
| 3 | DB 暗号化不在 | 🟡 中 | データ漏洩 | SQLCipher 等の検討 |
| 4 | 巨大スクリーンファイル | 🟡 中 | メンテナンス性 | 画面のモジュール化 |
| 5 | XSS（ダッシュボード） | 🟡 中 | インジェクション | HTML エスケープ |
| 6 | バックアップ失敗の静黙化 | 🟡 中 | データ損失 | エラー通知の強化 |

## アーキテクチャ上の制約事項

- **monolithic main.dart**: 35K 行 — 初期ロード時間・メンテナンス性に影響
- **database_helper.dart の肥大化**: 3621 行（バックアップサービス等が含まれる）— 責任範囲の分離が必要
- **画面ファイルの巨大化**: customer_master_screen.dart が ~60K 行 — コンポーネント分割が望ましい
- **モジュールシステム**: `lib/modules/` に `feature_module.dart`, `purchase_management_module.dart` が存在（未成熟なモジュール化）
