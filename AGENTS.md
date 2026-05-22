# AGENTS.md - Code Generation AI Guidelines

## 販売アシスト 1 号（お局様サーバー）

Flutter ベースのオフラインスタンドアロン＋オンライン同期アプリ。約 130 スクリーン、86,500 行コード。SQLite データベース（gemi_invoice.db v45）。

---

## プロジェクト情報

- **バージョン**: 1.5.09+154
- **Flutter SDK**: ^3.10.7
- **SDK バージョン**: 3.3.10
- **メインフォント**: IPAexGothic（日本語文字用）
- **データベース**: SQLite（sqflite パッケージ）
- **主要依存**: googleapis_auth, pdf, image_picker, camera

---

## ビルド・テストコマンド

```bash
# コード検証（info レベルの警告抑制）
flutter analyze --no-fatal-infos

# デバッグビルドと実行
flutter pub get
flutter run

# APK 構築
flutter build apk

# テスト実行
flutter test

# 有効期限管理付きビルド（引数：debug|profile|release）
./scripts/build_with_expiry.sh release
```

---

## AI セッション開始時標準手順

新規セッション開始時は必ず以下を実行：

1. **README.md 確認**: プロジェクト概要と開発ルールを把握
2. **TODO.md 確認**: 現在のタスク状況（進行中・緊急タスク）を把握
3. **ユーザーリクエスト理解**: 実際の指示を待ってから作業開始

### 作業実施時の流れ

```
タスク開始 → TODO.md更新（進行中マーク） → 実装 → テスト → 
flutter analyze → git commit（日本語） → TODO.md更新（完了マーク）
```

---

## 絶対必須ルール

### 1. Git コミットは日本語のみ
- **英語コミットメッセージは禁止**
- 例：`git commit -m "画面 ID を追加し、バッファロー対応"`
- 例：`git commit -m "SQLite データベースバージョン 34 に更新"`

### 2. スクリーン ID は 2、3 文字プレフィックス必須
- 全ての画面タイトルに `S1:`, `P1:`, `PJ1:` 形式の ID 付与
- パターン例：`S1:設定`, `P1:商品マスター`, `PJ1:案件管理`
- 2文字で一意にできない場合は 3 文字を使用（例: `PJ1`, `PJ2`）
- Screen ファイル名は `screen_<id>_<name>.dart`

### 3. 絶対パス使用
- TODO.md, コメント、ドキュメントでは絶対パスを使用
- 例：`lib/screens/screen_s1_setting.dart`（相対パス不可）

### 4. 非同期操作前に mounted チェック必須
```dart
// 正しいパターン
Future<void> loadData() async {
  final result = await repository.fetchData();
  if (!mounted) return;  // ← 必ず挿入
  setState(() {
    data = result;
  });
}
```

### 5. ファイルアクセスのデフォルトはシステムダウンロードフォルダ
- **内部 DB ファイル以外**のファイルアクセスは、システムダウンロードフォルダを使用
- **Android**: `/storage/emulated/0/Download`
- **iOS**: `Documents` フォルダ（iOS にはシステムダウンロードフォルダがない）
- **エクスポート・インポート**: 同じフォルダを参照して、ユーザーが直感的に操作できるように

**実装パターン**
```dart
// ダウンロードフォルダを取得
static Future<Directory> _getDownloadDirectory() async {
  try {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) {
        return dir;
      }
    } else if (Platform.isIOS) {
      return await getApplicationDocumentsDirectory();
    }
  } catch (e) {
    debugPrint('Error: $e');
  }
  // フォールバック
  return await getApplicationDocumentsDirectory();
}

// ファイルピッカーの初期ディレクトリ
final result = await FilePicker.platform.pickFiles(
  initialDirectory: Platform.isAndroid 
    ? '/storage/emulated/0/Download'
    : (await getApplicationDocumentsDirectory()).path,
);
```

---

## ディレクトリ構造

```
lib/
├── screens/          # UI スクリーン（130+ ファイル）
│   └── screen_<id>_<name>.dart
├── services/         # ビジネスロジック・リポジトリ（68ファイル）
│   ├── <entity>_repository.dart
│   └── database_helper.dart
├── models/           # データモデル（43ファイル）
│   └── <model>.dart
├── widgets/          # 再利用可能コンポーネント（33ファイル）
│   ├── generic_list_screen.dart
│   └── document_card.dart
└── main.dart
```

---

## コーディングパターン

### リポジトリパターン
```dart
// lib/services/product_repository.dart
class ProductRepository {
  Future<List<Product>> getAll() async { ... }
  Future<void> insert(Product product) async { ... }
  Future<void> update(Product product) async { ... }
  Future<void> delete(int id) async { ... }
}
```

### GenericListScreen テンプレート
```dart
// lib/widgets/generic_list_screen.dart
class GenericListScreen<T extends BaseDocument> extends StatefulWidget {
  final String screenId;
  final String title;
  final Repository<T> repository;
  
  // 一覧表示・編集・削除の共通ロジックを提供
}
```

### DocumentCard テンプレート
```dart
// lib/widgets/document_card.dart
class DocumentCard extends StatelessWidget {
  final BaseDocument document;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  
  // カード形式のドキュメント表示コンポーネント
}
```

### BaseDocument モデル
```dart
// lib/models/base_document.dart
class BaseDocument {
  int? id;
  DateTime createdAt;
  DateTime updatedAt;
  String createdBy;
  String updatedBy;
  
  // 全ドキュメントの共通フィールド
}
```

---

## 主要サービスの役割分担

| サービス | 責任範囲 | ファイル例 |
|----------|----------|------------|
| **Repository** | データ操作（CRUD） | `product_repository.dart` |
| **DatabaseHelper** | SQLite 操作・クエリ | `database_helper.dart` |
| **SyncService** | オンライン同期処理 | `sync_service.dart` |
| **AuthService** | 認証・セッション管理 | `auth_service.dart` |

---

## データベース構造

- **ファイル**: `gemi_invoice.db`
- **バージョン**: 45
- **主要テーブル**: products, invoices, customers, inventory, users
- **操作**: sqflite パッケージ経由

---

## 既存画面 ID 一覧（重複防止用）

| ID | 画面名 | ファイル名 |
|----|--------|------------|
| S1 | 設定 | `lib/screens/settings_screen.dart` |
| SM | メール設定 | `lib/screens/screen_s8_email_settings.dart` |
| P1 | 商品マスター | `lib/screens/product_master_screen.dart` |
| C1 | 得意先マスター | `lib/screens/customer_master_screen.dart` |
| SI | 仕入先マスター | `lib/screens/supplier_master_screen.dart` |
| WH | 倉庫マスター | `lib/screens/warehouse_master_screen.dart` |
| ST | 担当者マスター | `lib/screens/staff_master_screen.dart` |
| ES | 見積入力 | `lib/screens/estimate_input_screen.dart` |
| OR | 受注入力 | `lib/screens/order_input_screen.dart` |
| IV | 請求書発行 | `lib/screens/invoice_issue_screen.dart` |
| IQ | 在庫照会 | `lib/screens/stock_inquiry_screen.dart` |
| IM | 在庫移動 | `lib/screens/stock_transfer_screen.dart` |
| IC | 棚卸入力 | `lib/screens/stocktake_input_screen.dart` |
| CS | 得意先別売上推移 | `lib/screens/customer_sales_trend_screen.dart` |
| PA | 商品別粗利分析 | `lib/screens/product_profit_analysis_screen.dart` |
| CH | 母艦チャット | `lib/screens/chat_screen.dart` |
| M1 | マスター管理 | `lib/screens/management_screen.dart` |
| D2 | ダッシュボード設定 | `lib/screens/dashboard_menu_settings_screen.dart` |
| PJ1 | 案件一覧 | `lib/screens/screen_pj1_project_list.dart` |
| PJ2 | 案件詳細 | `lib/screens/screen_pj2_project_detail.dart` |

**新規画面追加時**: 上記と重複しない 2、3 文字 ID を選定

---

## 重要な実装上の注意事項

### StatefulWidget での非同期処理
```dart
// ✅ 正しいパターン
Future<void> loadData() async {
  final result = await repository.fetchData();
  if (!mounted) return;  // ← 必須
  setState(() => data = result);
}

// ❌ 間違い: mounted チェックなし
Future<void> loadData() async {
  final result = await repository.fetchData();
  setState(() => data = result);  // Widget 破棄後にエラー
}
```

### Navigator 使用時の mounted チェック
```dart
// ✅ 正しいパターン
await someAsyncOperation();
if (!mounted) return;
Navigator.push(context, ...);

// ❌ 警告が出る
await someAsyncOperation();
Navigator.push(context, ...);  // use_build_context_synchronously
```

### データベースマイグレーション
```dart
// lib/services/database_helper.dart
onUpgrade: (db, oldVersion, newVersion) async {
  if (oldVersion < 34) {
    await db.execute('ALTER TABLE ...');
  }
}
```
- **バージョン増分必須**: スキーマ変更時は `version:` を増やす
- **既存データ保護**: `DROP TABLE` せず `ALTER TABLE` を使用

### SharedPreferences のキー命名
```dart
// ✅ 命名規則: スネークケース
const String kMailSendMethodSmtp = 'mail_send_method_smtp';
const String kLastBackupTime = 'last_backup_time';
```

---

## AI 開発効率化ルール

### ファイル構造ルール
- **画面ファイルは最大 1,200 行**。超えたら必ず子ウィジェットに分割
- サービスファイルは最大 800 行。超えたらエンティティ別または機能別に分割
- 分割時は `lib/screens/` または `lib/widgets/` に `_part.dart` サフィックス付きで配置
- 例：`invoice_input_screen.dart` (1,200行超) → `invoice_header_widget.dart`, `invoice_lines_widget.dart`, `invoice_calculator_widget.dart`

### コード複製禁止
- **3回以上出現するコードブロックは、必ず共通化してリファクタリング**
- AppBar構築ロジック、DocumentType色判定、ダークテーマ対応等は `lib/widgets/` に統一抽出
- 重複検出パターン:
  ```dart
  // ❌ 各画面にコピーしている場合（複製）
  Color _documentTypeColor(DocumentType type, bool isDark) { ... }
  
  // ✅ lib/widgets/document_colors.dart に一元化
  class DocumentColors {
    static Color colorFor(DocumentType type, bool isDark) { ... }
    static AppBarStyle appBarStyleFor(DocumentType type) { ... }
  }
  ```

### 状態更新パターン
- **setState の使用は最小限に**。複雑な状態管理は Riverpod Provider を優先
- 単純な UI 更新のみ setState を使用。データフェッチ・状態共有は Provider/StateNotifier
- 既存コードの setState は段階的に置換（新規実装から Riverpod 適用）
- パターン統一により、AI がデータフローを追跡するコストを削減

### 変更時のチェックリスト
- 変更前に `flutter analyze --no-fatal-infos` で静的解析を実行
- 関連ファイル一覧を AI が自動生成して影響範囲を確認
- 画面変更時は対応するモデル・リポジトリへの波及を確認
- テーマ変更時は全画面の AppBar・Container カラーを一括確認
- コミット前に `git diff --stat` で変更行数を確認し、意図と一致するか検証

---

## 画面実装ワークフロー

1. **画面 ID 決定**: 2、3 文字プレフィックスと一意な名付け（例：`S1`, `PJ1`）
2. **スクリーン作成**: `lib/screens/screen_<id>_<name>.dart`
3. **モデル定義**: `lib/models/<model>.dart`（BaseDocument継承）
4. **リポジトリ作成**: `lib/services/<entity>_repository.dart`
5. **テスト実装**: 関連する widget テスト追加
6. **コミット**: 日本語メッセージで Git に記録

---

## よく使われる依存関係

```yaml
dependencies:
  sqflite: ^2.3.0           # SQLite データベース
  pdf: ^3.10.7               # PDF 生成（請求書など）
  googleapis_auth: ^1.4.1   # Google API 認証
  image_picker: ^1.0.5      # 画像選択
  camera: ^0.10.0           # カメラ機能
  path_provider: ^2.1.1     # ファイルパス取得
```

---

## エラーハンドリング

### データベースエラー
```dart
try {
  final result = await database.query('products');
} catch (e) {
  // エラーログ記録
  print('DB Error: $e');
  if (!mounted) return;
  // ユーザーにメッセージ表示
}
```

### API 通信エラー
```dart
try {
  await syncService.uploadData(data);
} catch (e) {
  // オフライン状態を維持
  if (!mounted) return;
  showOfflineWarning();
}
```

---

## デバッグ・トラブルシューティング

### よくあるエラーと対処法

**1. `use_build_context_synchronously`**
```dart
// NG: async後に直接context使用
await someAsyncFunction();
Navigator.push(context, ...);  // ← 警告

// OK: mounted チェック
await someAsyncFunction();
if (!mounted) return;
Navigator.push(context, ...);
```

**2. `duplicate_definition`**
- 変数・メソッドの重複宣言を確認
- インポートの重複確認

**3. `unused_field` / `unused_element`**
- 未使用の変数・メソッドを削除
- または実装を完成させる

### データベースリセット（開発時のみ）
```bash
# アプリをアンインストールしてDBクリア
adb uninstall com.example.h_1
```

### ビルドエラー時の確認ポイント
```bash
# 依存関係の更新
flutter clean
flutter pub get

# コード検証
flutter analyze --no-fatal-infos
```

---

## 品質チェックリスト

実装前に必ず確認：

- [ ] スクリーンに 2、3 文字 ID を付与したか（SCREEN_IDS.mdと重複ないこと）
- [ ] mounted チェックを挿入したか（非同期操作）
- [ ] TODO.md に絶対パスでタスク記録したか
- [ ] コミットメッセージは日本語のみか
- [ ] `flutter analyze --no-fatal-infos` がエラーなしか
- [ ] ファイルアクセスはシステムダウンロードフォルダを使用しているか（内部 DB 以外）
- [ ] エクスポート・インポートが同じフォルダを参照しているか

---

## 参考ドキュメント

- **README.md**: プロジェクト概要、AI ワークフロー
- **TODO.md**: タスク管理、開発ルール（絶対パス使用）
- **ROADMAP.md**: 開発フェーズとマイルストーン
- **ARCHITECTURE.md**: システムアーキテクチャ詳細
- **analysis_options.yaml**: Dart ランティング設定

---

## よくある質問

**Q: 新しい画面を追加したい**  
A: `lib/screens/` に `screen_<2char_id>_<name>.dart` を作成。タイトルに ID 付与必須。

**Q: データベーススキーマを変更したい**  
A: `lib/services/database_helper.dart` を更新。バージョン番号も増分。

**Q: オンライン同期を実装したい**  
A: `lib/services/sync_service.dart` にロジック追加。Google APIs 認証を使用。

**Q: エラーハンドリングがわからない**  
A: try-catch で囲み、`if (!mounted) return;` を挿入。ユーザーに優しいメッセージ表示。

---

## Git 操作例（日本語コミット）

```bash
# 新しい画面追加
git add lib/screens/screen_s1_new_feature.dart
git commit -m "S1:新機能画面を実装し、データベース連携を追加"

# バグ修正
git commit -m "バグ修正：在庫数の表示エラーを修正し、計算ロジックを見直し"

# 機能拡張
git commit -m "PDF 出力機能を追加し、請求書フォーマットを更新"
```

---

**作成**: 2026-04-04  
**最終更新**: 2026-05-21  
**バージョン**: 1.1（AI開発効率化ルール追加・プロジェクト情報更新）  
**対象**: Cursor, Copilot, Claude 等のコード生成 AI エージェント

<!-- GSD:project-start source:PROJECT.md -->
## Project

**販売アシスト 1号（お局様サーバー）**

オフラインスタンドアロン＋オンライン同期の Flutter ベース販売管理アプリ。約130画面/86,500行のコードベースで、SQLite（gemi_invoice.db v45）を主データベースとし、見積・受注・請求・在庫・マスター管理などの業務機能を提供する。中規模業務システムで、現在約半分の実装が完了している状態。

**Core Value:** **販売業務の基本フロー（見積→受注→請求→在庫管理）が正しく動作し、データが失われないこと。**

### Constraints

- **Tech Stack**: Flutter 3.10.7 / Dart 3.3.10 — バージョン固定。アップグレードは安定化後
- **Database**: SQLite（sqflite）、gemi_invoice.db v45 — スキーマ変更は最小限に
- **Compatibility**: Android 実機動作必須。ファイルアクセスはシステムダウンロードフォルダ使用
- **Code Quality**: `flutter analyze --no-fatal-infos` 通過必須
- **Commit**: コミットメッセージは日本語のみ
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Languages
- Dart (>=3.10.7, <4.0.0) — All application code in `lib/`, `test/`, and `bin/`
- Shell script — `scripts/build_with_expiry.sh` (build automation with expiry date embedding)
- YAML — Project configuration (`pubspec.yaml`, `analysis_options.yaml`)
## Runtime
- Flutter SDK ^3.10.7 (actual: >=3.38.4 per lockfile)
- Dart SDK ^3.10.7
- `pub` (Dart package manager)
- Lockfile: `pubspec.lock` present and committed
## Frameworks
- Flutter (Google's UI toolkit) — All 105+ screens, 30 reusable widgets
- Material Design 3 (`useMaterial3: true`) — Used throughout `lib/main.dart` theme definitions
- `pdf: ^3.11.3` — Invoice/estimate/delivery note/receipt document generation in `lib/services/pdf_generator.dart`
- `printing: ^5.14.2` — PDF printing support
- `sqflite: ^2.3.0` (actual 2.4.2) — SQLite database access
- `sqflite_common_ffi_web: ^0.4.2+3` — Web platform FFI support
- `sqflite_common_ffi: ^2.3.2` (dev) — Desktop test support
- DB file: `販売アシスト 1 号.db` (migrated from `gemi_invoice.db`) on Android shared storage
- `flutter_test` (SDK) — Widget and unit tests
- `sqflite_common_ffi ^2.3.2` (dev) — Desktop-native DB testing
- Config: `analysis_options.yaml` includes `package:flutter_lints/flutter.yaml`
## Key Dependencies
| Package | Version | Purpose | File |
|---------|---------|---------|------|
| `sqflite` | ^2.3.0 | SQLite database layer | `lib/services/database_helper.dart` |
| `shared_preferences` | ^2.2.2 | Key-value settings persistence | `lib/services/app_settings_repository.dart` |
| `path_provider` | ^2.1.5 | Filesystem path resolution | `lib/services/database_helper.dart` |
| `http` | ^1.2.2 | HTTP requests for sync/mothership API | `lib/services/mothership_client.dart` |
| Package | Version | Purpose | File |
|---------|---------|---------|------|
| `google_sign_in` | ^6.1.0 | OAuth 2.0 sign-in | `lib/services/google_account_service.dart` |
| `googleapis` | ^12.0.0 | Gmail/Drive API client libraries | `lib/services/gmail_sync_client.dart`, `lib/services/drive_backup_service.dart` |
| `googleapis_auth` | ^1.4.0 | Auth token management | `lib/services/google_api_service_base.dart` |
| Package | Version | Purpose | File |
|---------|---------|---------|------|
| `image_picker` | ^1.2.1 | Camera/gallery photo capture | Used across screens |
| `camera` | ^0.11.0+1 | Live camera preview/seal capture | `lib/widgets/seal_camera_screen.dart` |
| `file_picker` | ^8.1.2 | File selection dialogs | Import/export screens |
| `open_filex` | ^4.7.0 | Open external files | PDF preview |
| `mobile_scanner` | ^7.2.0 | Barcode/QR scanning | `lib/screens/barcode_scanner_screen.dart` |
| Package | Version | Purpose | File |
|---------|---------|---------|------|
| `mailer` | ^6.0.1 | SMTP email sending | `lib/services/email_notification_service.dart` |
| `flutter_email_sender` | ^6.0.3 | Native mail app intent | `lib/services/invoice_email_sender.dart` |
| Package | Version | Purpose | File |
|---------|---------|---------|------|
| `geolocator` | ^14.0.2 | GPS location tracking | `lib/services/gps_service.dart` |
| `device_info_plus` | ^12.3.0 | Device info (SDK version, etc.) | `lib/services/storage_permission_service.dart` |
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
- `pubspec.yaml` — Package manifest, dependencies, fonts
- `analysis_options.yaml` — Dart/Flutter lint rules (flutter_lints)
- `google-services.json` — Firebase/Google Services (Android)
- `--dart-define` flags at build time via `scripts/build_with_expiry.sh`:
- `MothershipClient` host/password: stored in SharedPreferences (`external_host`, `external_pass` keys)
- Google OAuth credentials: stored in SharedPreferences (`google_client_id`, `google_client_secret`)
- `flutter_lints: ^6.0.0` — Standard Flutter lint package
- `analysis_options.yaml` uses `package:flutter_lints/flutter.yaml` include
## Database
## State Management
## Fonts & Theming
- `light` (default, indigo/blue-grey) — `MaterialColor`
- `dark` (dark indigo) — `Brightness.dark`
- `dark-gray` (dark grey surfaces) — `Brightness.dark`
- `gray` (light grey) — `Brightness.light`
- `custom` (user-customizable colors) — Stored in `SharedPreferences` via `AppThemeController`
- `system` (follow OS) — `ThemeMode.system`
## Platform Support
- Android (primary target — APK build via `scripts/build_with_expiry.sh`)
- iOS — platform template present in `ios/`
- Linux — platform template present (desktop support)
- macOS — platform template present
- Windows — platform template present
- Web — partial support (`kIsWeb` checks throughout code, `sqflite_common_ffi_web`, `shelf` for server-side)
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Naming Patterns
- Screen files: `screen_<2-3char_id>_<name>.dart` (e.g. `screen_pj1_project_list.dart`, `screen_s1_theme_selection.dart`)
- Service/repository files: `<entity>_repository.dart` (e.g. `customer_repository.dart`, `product_repository.dart`)
- Model files: `<entity>_model.dart` (e.g. `customer_model.dart`, `invoice_models.dart`)
- Widget files: `<descriptive_name>.dart` (e.g. `document_card.dart`, `empty_state_widget.dart`)
- Part files: `_part.dart` suffix when splitting large files (e.g. `invoice_header_widget.dart`)
- Screens: `{Purpose}Screen` (e.g. `ProjectListScreen`, `ThemeSelectionScreen`)
- Services: `{Entity}Repository` (e.g. `CustomerRepository`, `ProductRepository`)
- Models: `{Entity}` (e.g. `Customer`, `Product`, `BaseDocument`)
- Widgets: `{Purpose}{Widget}` (e.g. `DocumentCard`, `EmptyStateWidget`, `ScreenAppBarTitle`)
- Private State classes: `_{Class}State` (e.g. `_ProjectListScreenState`)
- `camelCase` for all methods and functions
- Private: `_leadingUnderscore` plus `camelCase`
- Getters: `camelCase` (e.g. `getDisplayTitle()`, `get invoiceName`)
- Local variables: `camelCase` (e.g. `_allItems`, `_loading`, `_searchCtrl`)
- Constants: `lowercase_with_underscores` for SharedPreferences keys (e.g. `kLastBackupTime = 'last_backup_time'`)
- Class-level const: `kPrefix` convention (e.g. `kMailSendMethodSmtp`)
- Private instance vars: `_leadingUnderscore`
- Enums: `PascalCase` (e.g. `DocumentStatus`, `BusinessType`, `WorkflowType`)
- Abstract classes: `PascalCase` (e.g. `BaseDocument`)
- Mixins: `PascalCase` with `Mixin` suffix when applicable
## Screen ID Prefix System
- `S1:設定`, `P1:商品マスター`, `PJ1:案件一覧`
- File name pattern: `screen_<id>_<name>.dart`
- The `ScreenAppBarTitle` widget in `lib/widgets/screen_id_title.dart` enforces the ID+title display pattern
## Code Style & Formatting
- `analysis_options.yaml` includes `package:flutter_lints/flutter.yaml` with no custom overrides
- The default Flutter lint set is active
## File Size Limits
- **Screen files: 1,200 lines maximum** — exceed by splitting into child widgets in `lib/screens/` or `lib/widgets/` with `_part.dart` suffix
- **Service files: 800 lines maximum** — split by entity or functional area
- Example split: `invoice_input_screen.dart` → `invoice_header_widget.dart`, `invoice_lines_widget.dart`, `invoice_calculator_widget.dart`
## Import Organization
## Widget Patterns
## Async Operation — `mounted` Check
- `setState()` calls
- `Navigator.push()`, `Navigator.pop()` calls
- `ScaffoldMessenger.of(context).showSnackBar()` calls
## Generic List Pattern
## Repository Pattern (CRUD)
- `DatabaseHelper` singleton accessed via `_dbHelper.database`
- Raw SQL queries via `db.rawQuery()` (not `db.query()` often)
- Transactions for multi-table writes via `db.transaction()`
- Hash chain integration via `HashUtils` for electronic recordkeeping compliance
## Model Patterns
- Contains `id`, `documentNumber`, `date`, `customer`, `items`, `subtotal`, `taxAmount`, `total`, `status`
- Abstract methods: `toMap()`, `getStatusColor()`, `getThemeColor()`, `getDocumentTypeName()`
- Concrete `DocumentItem` class with `toMap()`, `fromMap()`, `copyWith()`
- Immutable fields with `final`
- `fromMap(Map<String, dynamic>)` factory constructor
- `toMap()` instance method for SQLite serialization
- `copyWith()` for immutable updates
- Custom exception classes co-located in the model file (e.g. `DuplicateCustomerException`)
## Error Handling
- `DuplicateCustomerException` in `lib/models/customer_model.dart`
- `CustomerInUseException` in `lib/models/customer_model.dart`
## Logging
- Production logging: `debugPrint()` (prints only in debug mode)
- Temporary debug output: `print()` — avoid in committed code
- Error context: Include operation name and entity ID in the message
## SharedPreferences Key Naming
## Duplicate Code Prevention
- `lib/widgets/document_card.dart` — universal document card widget
- `lib/widgets/empty_state_widget.dart` — universal empty state
- `lib/widgets/generic_list_screen.dart` — reusable list screen template
- `lib/widgets/screen_id_title.dart` — unified AppBar title with screen ID
## Database Migration Patterns
- Always increment `version` in `openDatabase()` when schema changes
- Use `_safeAddColumn()` helper pattern from `lib/services/customer_repository.dart` to add columns safely
## Git Commits
- Messages MUST be in Japanese only
- Example: `git commit -m "S1:新機能画面を実装し、データベース連携を追加"`
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## System Overview
```text
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
- Purpose: All visual screens, data entry forms, list views
- Location: `lib/screens/` (110 files)
- Contains: StatefulWidget subclasses with `initState()` → `_load()` → `setState()` pattern
- Depends on: Repository classes from `lib/services/`
- Used by: `lib/main.dart` (app root), direct `Navigator.push`
- Purpose: Repository classes, sync clients, utilities
- Location: `lib/services/` (79 files)
- Contains: Repository CRUD (ProductRepository, CustomerRepository, etc.), sync clients, auth, PDF generation, backup
- Depends on: `DatabaseHelper` singleton, models
- Used by: Screen widgets
- Purpose: SQLite connection, schema creation, migration management
- Location: `lib/services/database_helper.dart`
- Contains: `DatabaseHelper` singleton, `LocalBackupService`
- Pattern: Singleton with double-checked locking via cached `_databaseFuture`
- Purpose: Data classes with toMap/fromMap serialization
- Location: `lib/models/` (43 files)
- Contains: `BaseDocument` abstract, `Customer`, `Product`, `Invoice`, etc.
- Key base: `BaseDocument` abstract class with `id`, `documentNumber`, `items`, `total`, `toMap()`
- Purpose: Reusable UI components
- Location: `lib/widgets/` (30 files)
- Contains: `GenericListScreen<T>`, `DocumentCard`, `EmptyStateWidget`, filter chips, modals
## Data Flow
### Primary Request Path (List → Detail)
### Save Flow (Screen → Repository → DB)
### Sync Flow (Chat/Invoice via Gmail)
- All screen-level state handled via `setState()` in StatefulWidget
- `ChatSyncScheduler` uses `WidgetsBindingObserver` for app lifecycle
- `BackupProgressNotifier` is a `ChangeNotifier` used by `_MyAppState`
- `AppThemeController` uses `ValueNotifier<String>` for theme switching
- No Riverpod/Provider/Bloc usage in production screen code
## Key Abstractions
- Purpose: Base class for all document types (quotations, orders, sales, invoices)
- File: `lib/models/base_document.dart`
- Fields: `id`, `documentNumber`, `date`, `customer`, `items`, `subtotal`, `taxAmount`, `total`, `taxRate`, `status`, `createdAt`, `updatedAt`
- Methods: `toMap()`, `getStatusColor()`, `getThemeColor()`, `getDocumentTypeName()`
- Purpose: Reusable list screen with data fetching, filtering, pull-to-refresh
- File: `lib/widgets/generic_list_screen.dart`
- Pattern: Accepts `fetchData`, `buildCard`, `filters`, `onCreateNew` as callbacks
- Layout: AppBar with screen ID title + filter menu + refresh, ListView with pull-to-refresh, FAB for create
- Purpose: Reusable card-style document list item
- File: `lib/widgets/document_card.dart`
- Fields: `title`, `subtitle`, `amount`, `date`, `status`, `themeColor`, `actions`
- Status chip: `draft` (secondary), `confirmed` (tertiary), `cancelled` (outline)
- All repositories follow same interface: `getAll()`, `getById()`, `save()`, `delete()`, `search()`
- File: `lib/services/*_repository.dart`
- Pattern: Instantiates `DatabaseHelper` singleton, uses `_logRepo` for activity logging
- Hash chain versioning: saves create new version rows (not UPDATE in-place)
- Purpose: Pluggable module system for dashboard cards
- File: `lib/modules/feature_module.dart`
- Used by: `PurchaseManagementModule` (`lib/modules/purchase_management_module.dart`)
- Gated by `AppConfig.enable*Module` flags
## Entry Points
- Location: `lib/main.dart:65` — `void main() async { ... runApp(MyApp(...)); }`
- Triggers: App launch
- Responsibilities: WidgetsFlutterBinding initialization, build expiry check, theme setup, DB init, heartbeat, sync scheduler start, backup restore check
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
## Cross-Cutting Concerns
## Anti-Patterns
### setState-heavy State Management
### Mixed Naming Convention for Screen Files
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
