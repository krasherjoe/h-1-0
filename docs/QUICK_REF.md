# クイックリファレンス

**最終更新**: 2026-03-08

このドキュメントはSWE1.5がよく使う情報への高速アクセスを提供します。

---

## 📁 重要ファイルパス

### プロジェクトルート
```
/home/user/dev/h-1.flutter.0
```

### ディレクトリ構造
```
lib/
├── screens/          # 画面ファイル
├── models/           # データモデル
├── services/         # ビジネスロジック・リポジトリ
├── widgets/          # 再利用可能なウィジェット
├── constants/        # 定数定義
└── utils/            # ユーティリティ

docs/                 # ドキュメント
├── tasks/            # タスク詳細
└── archive/          # アーカイブ

test/                 # テストファイル
```

### 主要ファイル
- **データベース**: `lib/services/database_helper.dart`
- **メニュー定義**: `lib/constants/menu_catalog.dart`
- **ダッシュボード**: `lib/screens/dashboard_screen.dart`
- **汎用リスト画面**: `lib/widgets/generic_list_screen.dart`
- **ドキュメントカード**: `lib/widgets/document_card.dart`
- **基底モデル**: `lib/models/base_document.dart`

---

## 🔧 よく使うコマンド

### 解析
```bash
cd /home/user/dev/h-1.flutter.0
flutter analyze
```

### テスト
```bash
# 全テスト実行
flutter test

# 特定のテスト実行
flutter test test/models/quotation_model_test.dart
```

### 実行
```bash
# デバッグモード
flutter run

# リリースモード
flutter run --release
```

### クリーン
```bash
# ビルドキャッシュクリア
flutter clean

# 依存関係再取得
flutter pub get
```

### データベースリセット
```bash
# アプリをアンインストール（エミュレータ）
adb uninstall com.example.gemi_invoice

# 再インストール
flutter run
```

---

## 📋 コーディングパターン

### 1. StatefulWidget変換
**参考**: `lib/screens/quotation_input_screen.dart`

```dart
// 変更前
class MyScreen extends StatelessWidget {
  const MyScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    // ...
  }
}

// 変更後
class MyScreen extends StatefulWidget {
  const MyScreen({super.key});
  
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  @override
  Widget build(BuildContext context) {
    // ...
  }
}
```

### 2. mountedチェック
```dart
// 非同期処理の後、UI更新の前
onPressed: () async {
  await someAsyncOperation();
  if (!mounted) return;  // ← これを追加
  ScaffoldMessenger.of(context).showSnackBar(...);
}
```

### 3. データベーステーブル追加
**参考**: `lib/services/database_helper.dart`

```dart
// 1. バージョン更新
static const _databaseVersion = 35;  // +1

// 2. マイグレーション追加
if (oldVersion < 35) {
  await db.execute('''
    CREATE TABLE my_table (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      created_at TEXT NOT NULL
    )
  ''');
  
  await db.execute('''
    CREATE INDEX idx_my_table_name ON my_table(name)
  ''');
}
```

### 4. 新規画面追加
**参考**: `lib/screens/quotation_input_screen.dart`

```dart
// GenericListScreenを使用
class MyListScreen extends StatefulWidget {
  const MyListScreen({super.key});
  
  @override
  State<MyListScreen> createState() => _MyListScreenState();
}

class _MyListScreenState extends State<MyListScreen> {
  @override
  Widget build(BuildContext context) {
    final repo = MyRepository();
    
    return GenericListScreen<MyModel>(
      screenId: 'XX',
      title: 'タイトル',
      icon: Icons.my_icon,
      themeColor: Colors.blue,
      fetchData: () => repo.getAll(),
      buildCard: (context, item, onRefresh) {
        return DocumentCard(
          title: item.title,
          // ...
        );
      },
      // ...
    );
  }
}
```

### 5. メニュー追加
**参考**: `lib/constants/menu_catalog.dart`

```dart
MenuDefinition(
  id: 'XX',
  title: 'メニュー名',
  route: 'my_route',
  category: MenuCategory.sales,
  icon: Icons.my_icon,
  description: '説明文',
),
```

### 6. ルート追加
**参考**: `lib/screens/dashboard_screen.dart`

```dart
// 1. import追加
import 'my_screen.dart';

// 2. _getScreenメソッドにcase追加
case 'my_route':
  return const MyScreen();
```

---

## 🎯 現在の状態

### データベース
- **バージョン**: 34
- **テーブル数**: 33+

### 画面数
- **合計**: 40画面以上

### コード行数
- **合計**: 約53,000行

---

## 📊 画面ID一覧

### 販売管理
- **Q1**: 見積入力
- **O1**: 受注入力
- **A1**: 売上入力
- **SR1**: 売上返品入力
- **INV1**: 請求書発行
- **DOC1**: 伝票入力
- **A2**: 伝票一覧

### マスタ管理
- **P1**: 商品マスター
- **C1**: 得意先マスター
- **SI**: 仕入先マスター
- **WH**: 倉庫マスター
- **ST**: 担当者マスター
- **M1**: マスター管理ハブ

### 在庫管理
- **IQ**: 在庫照会
- **IM**: 在庫移動
- **IC**: 棚卸入力
- **WH**: 倉庫ダッシュボード

### 仕入管理
- **U2**: 仕入入力
- **支払予定管理**: purchase_receipts_screen

### 集計分析
- **売上日報**: sales_report_screen
- **CS**: 得意先別売上推移
- **PA**: 商品別粗利分析

### システム設定
- **S1**: 設定
- **SM**: メール設定
- **D2**: ダッシュボード設定

### その他
- **DL**: 配送記録一覧
- **IV**: 在庫一覧
- **SA**: 売上分析

**完全なリスト**: `docs/02_CURRENT_STATUS.md` を参照

---

## 🔍 よくある検索

### ファイルを探す
```bash
# 画面ファイル
find lib/screens -name "*_screen.dart"

# モデルファイル
find lib/models -name "*_model.dart"

# リポジトリファイル
find lib/services -name "*_repository.dart"
```

### コード内を検索
```bash
# StatelessWidgetを探す
grep -r "extends StatelessWidget" lib/screens/

# mountedチェックを探す
grep -r "if (!mounted)" lib/screens/

# テーブル作成を探す
grep -r "CREATE TABLE" lib/services/
```

---

## 📚 ドキュメント参照

### タスク実行時
1. `docs/NEXT_TASK.md` - 今やること
2. `docs/tasks/{TASK_ID}.md` - 詳細手順
3. このファイル - よく使う情報

### 問題発生時
1. タスク詳細の「トラブルシューティング」
2. 完了済みの類似ファイル
3. `docs/PROGRESS.md` - 過去の解決例

### 全体把握
1. `docs/PROJECT_MASTER_PLAN.md` - プロジェクト全体
2. `docs/01_OVERVIEW.md` - プロジェクト概要
3. `docs/02_CURRENT_STATUS.md` - 実装状況

---

## ⚡ ショートカット

### 最頻出パス
```bash
# プロジェクトルートへ移動
cd /home/user/dev/h-1.flutter.0

# 画面ディレクトリ
cd lib/screens

# ドキュメントディレクトリ
cd docs
```

### 最頻出コマンド
```bash
# 解析＋テスト
flutter analyze && flutter test

# クリーン＋実行
flutter clean && flutter pub get && flutter run
```

---

## 🚨 緊急時の対応

### データベースエラー
```bash
# アプリをアンインストール
adb uninstall com.example.gemi_invoice

# 再インストール
flutter run
```

### ビルドエラー
```bash
# クリーンビルド
flutter clean
flutter pub get
flutter run
```

### Gitで戻す
```bash
# 最後のコミットに戻す
git reset --hard HEAD

# 特定のファイルを戻す
git checkout HEAD -- lib/screens/my_screen.dart
```

---

このリファレンスを活用して、効率的に作業を進めてください。
