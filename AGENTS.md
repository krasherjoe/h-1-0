# AGENTS.md - Code Generation AI Guidelines

## 販売アシスト 1 号（お局様サーバー）

Flutter ベースのオフラインスタンドアロン＋オンライン同期アプリ。約 40 スクリーン、53,000 行コード。SQLite データベース（gemi_invoice.db v33）。

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

## 絶対必須ルール

### 1. Git コミットは日本語のみ
- **英語コミットメッセージは禁止**
- 例：`git commit -m "画面 ID を追加し、バッファロー対応"`
- 例：`git commit -m "SQLite データベースバージョン 34 に更新"`

### 2. スクリーン ID は 2 文字プレフィックス必須
- 全ての画面タイトルに `S1:`, `P1:`, `A2:` 形式の ID 付与
- パターン例：`S1:設定`, `P1:商品マスター`, `A1:在庫管理`
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

---

## ディレクトリ構造

```
lib/
├── screens/          # UI スクリーン（40+ ファイル）
│   └── screen_<id>_<name>.dart
├── services/         # ビジネスロジック・リポジトリ
│   ├── <entity>_repository.dart
│   └── database_helper.dart
├── models/           # データモデル
│   └── <model>.dart
├── widgets/          # 再利用可能コンポーネント
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
- **バージョン**: 33
- **主要テーブル**: products, invoices, customers, inventory, users
- **操作**: sqflite パッケージ経由

---

## 画面実装ワークフロー

1. **画面 ID 決定**: 2 文字プレフィックスと一意な名付け（例：`S1`）
2. **スクリーン作成**: `lib/screens/screen_s1_<name>.dart`
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

## 品質チェックリスト

実装前に必ず確認：

- [ ] スクリーンに 2 文字 ID を付与したか
- [ ] mounted チェックを挿入したか（非同期操作）
- [ ] TODO.md に絶対パスでタスク記録したか
- [ ] コミットメッセージは日本語のみか
- [ ] `flutter analyze --no-fatal-infos` がエラーなしか

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
**バージョン**: 1.0  
**対象**: Cursor, Copilot 等のコード生成 AI エージェント
