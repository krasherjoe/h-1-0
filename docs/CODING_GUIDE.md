# コーディングガイド（SWE1.5対応）

**販売アシスト1号 開発ガイド**

**最終更新**: 2026-03-08

このドキュメントは、SWE1.5などの軽量AIでも確実にコーディングできるよう、具体的な実装パターンとルールを提供します。

---

## 🎯 このガイドの使い方

### AIエージェント向け

1. **タスク受領時**: 該当セクションを読む
2. **実装時**: パターンをコピー＆カスタマイズ
3. **完了時**: チェックリストで確認

### 人間開発者向け

- 新機能実装時の参考
- コードレビューの基準
- 一貫性の維持

---

## 📋 基本ルール

### 1. ファイル命名規則

```
lib/
├── screens/
│   └── {機能名}_screen.dart          # 例: customer_master_screen.dart
├── models/
│   └── {エンティティ名}_model.dart    # 例: customer_model.dart
├── services/
│   ├── {エンティティ名}_repository.dart  # 例: customer_repository.dart
│   └── {機能名}_service.dart         # 例: pdf_generator.dart
└── widgets/
    └── {ウィジェット名}.dart          # 例: document_card.dart
```

### 2. クラス命名規則

```dart
// 画面: {機能名}Screen
class CustomerMasterScreen extends StatefulWidget {}

// モデル: {エンティティ名}
class Customer {}

// リポジトリ: {エンティティ名}Repository
class CustomerRepository {}

// サービス: {機能名}Service
class PdfGeneratorService {}

// ウィジェット: {機能名}Widget
class DocumentCard extends StatelessWidget {}
```

### 3. 画面ID規則

**全画面のAppBarタイトルは2文字ID必須**

```dart
AppBar(
  title: Text('C1:得意先マスター'),  // ✅ 正しい
  // title: Text('得意先マスター'),  // ❌ 間違い
)
```

**既存の画面ID一覧**:
- P1: 商品マスター
- C1: 得意先マスター
- SI: 仕入先マスター
- WH: 倉庫マスター
- ST: 担当者マスター
- Q1: 見積入力
- O1: 受注入力
- A1: 売上入力
- SR1: 売上返品入力
- IQ: 在庫照会
- IM: 在庫移動
- IC: 棚卸入力
- S1: 設定
- SM: メール設定
- D2: ダッシュボード設定
- CH: 母艦チャット

新規画面追加時は重複しないIDを選択してください。

---

## 🏗️ 実装パターン集

### パターン1: 汎用リスト画面（最も簡単）

**使用場面**: 一覧表示が必要な画面

**実装手順**:

#### Step 1: モデル作成（既存の場合はスキップ）

```dart
// lib/models/example_model.dart
import 'base_document.dart';

class Example extends BaseDocument {
  final String id;
  final String documentNumber;
  final DateTime date;
  final String? customerId;
  final int total;
  final DocumentStatus status;
  
  Example({
    required this.id,
    required this.documentNumber,
    required this.date,
    this.customerId,
    required this.total,
    required this.status,
  });
  
  // BaseDocumentの実装
  @override
  Customer? get customer => null;  // 必要に応じて実装
  
  @override
  List<DocumentItem> get items => [];  // 必要に応じて実装
  
  // JSON変換
  Map<String, dynamic> toJson() => {
    'id': id,
    'documentNumber': documentNumber,
    'date': date.toIso8601String(),
    'customerId': customerId,
    'total': total,
    'status': status.toString(),
  };
  
  factory Example.fromJson(Map<String, dynamic> json) => Example(
    id: json['id'],
    documentNumber: json['documentNumber'],
    date: DateTime.parse(json['date']),
    customerId: json['customerId'],
    total: json['total'],
    status: DocumentStatus.values.firstWhere(
      (e) => e.toString() == json['status'],
    ),
  );
}
```

#### Step 2: リポジトリ作成

```dart
// lib/services/example_repository.dart
import '../models/example_model.dart';
import 'database_helper.dart';

class ExampleRepository {
  final DatabaseHelper _db = DatabaseHelper();
  
  // 全件取得
  Future<List<Example>> getAll() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'examples',
      orderBy: 'date DESC',
    );
    return maps.map((map) => Example.fromJson(map)).toList();
  }
  
  // ID指定取得
  Future<Example?> getById(String id) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'examples',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Example.fromJson(maps.first);
  }
  
  // 挿入
  Future<void> insert(Example example) async {
    final db = await _db.database;
    await db.insert('examples', example.toJson());
  }
  
  // 更新
  Future<void> update(Example example) async {
    final db = await _db.database;
    await db.update(
      'examples',
      example.toJson(),
      where: 'id = ?',
      whereArgs: [example.id],
    );
  }
  
  // 削除
  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete(
      'examples',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
```

#### Step 3: 画面作成（GenericListScreen使用）

```dart
// lib/screens/example_list_screen.dart
import 'package:flutter/material.dart';
import '../models/example_model.dart';
import '../services/example_repository.dart';
import '../widgets/generic_list_screen.dart';
import '../widgets/document_card.dart';

class ExampleListScreen extends StatelessWidget {
  const ExampleListScreen({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return GenericListScreen<Example>(
      screenId: 'EX',  // 新規画面IDを割り当て
      screenTitle: 'サンプル一覧',
      repository: ExampleRepository(),
      itemBuilder: (example) => DocumentCard(
        document: example,
        onTap: () {
          // 詳細画面へ遷移
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExampleDetailScreen(id: example.id),
            ),
          );
        },
      ),
      onAdd: () {
        // 新規作成画面へ遷移
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExampleFormScreen(),
          ),
        );
      },
    );
  }
}
```

**これだけで完成！** 約50行で完全なリスト画面ができます。

---

### パターン2: フォーム画面

**使用場面**: データ入力・編集画面

**実装例**:

```dart
// lib/screens/example_form_screen.dart
import 'package:flutter/material.dart';
import '../models/example_model.dart';
import '../services/example_repository.dart';

class ExampleFormScreen extends StatefulWidget {
  final String? id;  // 編集時はIDを渡す
  
  const ExampleFormScreen({Key? key, this.id}) : super(key: key);
  
  @override
  State<ExampleFormScreen> createState() => _ExampleFormScreenState();
}

class _ExampleFormScreenState extends State<ExampleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = ExampleRepository();
  
  // フォームコントローラー
  final _documentNumberController = TextEditingController();
  final _totalController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  
  bool _isLoading = false;
  Example? _example;
  
  @override
  void initState() {
    super.initState();
    if (widget.id != null) {
      _loadData();
    }
  }
  
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final example = await _repository.getById(widget.id!);
      if (example != null) {
        setState(() {
          _example = example;
          _documentNumberController.text = example.documentNumber;
          _totalController.text = example.total.toString();
          _selectedDate = example.date;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('読み込みエラー: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      final example = Example(
        id: _example?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        documentNumber: _documentNumberController.text,
        date: _selectedDate,
        total: int.parse(_totalController.text),
        status: DocumentStatus.draft,
      );
      
      if (_example == null) {
        await _repository.insert(example);
      } else {
        await _repository.update(example);
      }
      
      if (!mounted) return;
      Navigator.pop(context, true);  // 成功を返す
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存エラー: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('EX:${_example == null ? "新規作成" : "編集"}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _save,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _documentNumberController,
                    decoration: const InputDecoration(
                      labelText: '伝票番号',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '伝票番号を入力してください';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('日付'),
                    subtitle: Text(_selectedDate.toString().split(' ')[0]),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        setState(() => _selectedDate = date);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _totalController,
                    decoration: const InputDecoration(
                      labelText: '金額',
                      border: OutlineInputBorder(),
                      suffixText: '円',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '金額を入力してください';
                      }
                      if (int.tryParse(value) == null) {
                        return '数値を入力してください';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
    );
  }
  
  @override
  void dispose() {
    _documentNumberController.dispose();
    _totalController.dispose();
    super.dispose();
  }
}
```

---

### パターン3: データベーステーブル追加

**使用場面**: 新しいエンティティのテーブル作成

**実装手順**:

#### Step 1: database_helper.dartのバージョンアップ

```dart
// lib/services/database_helper.dart
class DatabaseHelper {
  static const _databaseVersion = 34;  // ← バージョンを1増やす
  // ...
}
```

#### Step 2: _onUpgradeにマイグレーション追加

```dart
Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  // 既存のマイグレーション...
  
  // 新規追加
  if (oldVersion < 34) {
    await db.execute('''
      CREATE TABLE examples (
        id TEXT PRIMARY KEY,
        document_number TEXT NOT NULL,
        date TEXT NOT NULL,
        customer_id TEXT,
        total INTEGER NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (customer_id) REFERENCES customers (id)
      )
    ''');
    
    // インデックス作成
    await db.execute('''
      CREATE INDEX idx_examples_date ON examples(date)
    ''');
    await db.execute('''
      CREATE INDEX idx_examples_customer ON examples(customer_id)
    ''');
  }
}
```

---

### パターン4: ダッシュボードへの画面追加

**使用場面**: 新しい画面をメニューに追加

**実装手順**:

#### Step 1: menu_catalog.dartに定義追加

```dart
// lib/constants/menu_catalog.dart
class MenuCatalog {
  static final List<MenuDefinition> allMenus = [
    // 既存のメニュー...
    
    // 新規追加
    MenuDefinition(
      id: 'EX',
      title: 'サンプル一覧',
      route: 'example_list',
      category: MenuCategory.sales,  // カテゴリ選択
      icon: Icons.list,  // アイコン選択
      description: 'サンプルデータの一覧表示',
    ),
  ];
}
```

#### Step 2: dashboard_screen.dartにルート追加

```dart
// lib/screens/dashboard_screen.dart

// import追加
import 'example_list_screen.dart';

class _DashboardScreenState extends State<DashboardScreen> {
  // ...
  
  Widget _getScreen(String route) {
    switch (route) {
      // 既存のcase...
      
      // 新規追加
      case 'example_list':
        return const ExampleListScreen();
      
      default:
        return const MenuPlaceholderScreen(route: route);
    }
  }
}
```

---

## ✅ 実装チェックリスト

### 新規画面追加時

- [ ] 画面IDを決定（既存と重複しない2文字）
- [ ] モデルクラス作成（`lib/models/`）
- [ ] リポジトリクラス作成（`lib/services/`）
- [ ] データベーステーブル作成（マイグレーション）
- [ ] 画面クラス作成（`lib/screens/`）
- [ ] メニューカタログに追加
- [ ] ダッシュボードにルート追加
- [ ] `flutter analyze` でエラー確認
- [ ] 動作確認
- [ ] Gitコミット（日本語メッセージ）

### データベース変更時

- [ ] バージョン番号を1増やす
- [ ] `_onUpgrade`にマイグレーション追加
- [ ] インデックス作成（必要に応じて）
- [ ] 既存データの移行処理（必要に応じて）
- [ ] テスト実行
- [ ] Gitコミット

---

## 🚫 よくある間違いと修正方法

### 間違い1: 画面IDなし

```dart
// ❌ 間違い
AppBar(title: Text('得意先マスター'))

// ✅ 正しい
AppBar(title: Text('C1:得意先マスター'))
```

### 間違い2: 非同期処理でmountedチェックなし

```dart
// ❌ 間違い
Future<void> _loadData() async {
  final data = await repository.getData();
  setState(() => _data = data);  // Widgetが破棄されている可能性
}

// ✅ 正しい
Future<void> _loadData() async {
  final data = await repository.getData();
  if (!mounted) return;  // ← これを追加
  setState(() => _data = data);
}
```

### 間違い3: エラーハンドリングなし

```dart
// ❌ 間違い
Future<void> _save() async {
  await repository.save(data);
  Navigator.pop(context);
}

// ✅ 正しい
Future<void> _save() async {
  try {
    await repository.save(data);
    if (!mounted) return;
    Navigator.pop(context);
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('保存エラー: $e')),
    );
  }
}
```

### 間違い4: コントローラーのdisposeなし

```dart
// ❌ 間違い
class _MyScreenState extends State<MyScreen> {
  final _controller = TextEditingController();
  // disposeなし
}

// ✅ 正しい
class _MyScreenState extends State<MyScreen> {
  final _controller = TextEditingController();
  
  @override
  void dispose() {
    _controller.dispose();  // ← これを追加
    super.dispose();
  }
}
```

---

## 📝 Gitコミットメッセージ規則

**必ず日本語で記述**

### 良い例

```
見積入力画面を実装

- QuotationモデルとRepositoryを作成
- GenericListScreenを使用して150行で実装
- メニューカタログとダッシュボードに追加
- データベースバージョンを33に更新
```

### 悪い例（英語は使用しない）

```
Add quotation input screen
```

---

## 🎯 SWE1.5向け実装タスクテンプレート

### タスク: 新規画面追加

```markdown
## タスク: {画面名}画面の実装

### 概要
{画面の目的と機能を1-2行で説明}

### 画面ID
{2文字のID}

### 実装手順

1. モデル作成
   - ファイル: `lib/models/{エンティティ名}_model.dart`
   - パターン: パターン1のStep 1参照

2. リポジトリ作成
   - ファイル: `lib/services/{エンティティ名}_repository.dart`
   - パターン: パターン1のStep 2参照

3. データベーステーブル作成
   - ファイル: `lib/services/database_helper.dart`
   - パターン: パターン3参照
   - バージョン: {現在+1}

4. 画面作成
   - ファイル: `lib/screens/{画面名}_screen.dart`
   - パターン: パターン1のStep 3参照

5. メニュー追加
   - ファイル: `lib/constants/menu_catalog.dart`
   - パターン: パターン4のStep 1参照

6. ルート追加
   - ファイル: `lib/screens/dashboard_screen.dart`
   - パターン: パターン4のStep 2参照

7. 確認
   - [ ] `flutter analyze` エラーなし
   - [ ] 画面表示確認
   - [ ] データ保存確認
   - [ ] Gitコミット

### 参考
- 類似画面: {既存の類似画面}
- ドキュメント: `docs/CODING_GUIDE.md`
```

---

## 📚 参考ドキュメント

- **プロジェクト概要**: `docs/01_OVERVIEW.md`
- **実装状況**: `docs/02_CURRENT_STATUS.md`
- **アーキテクチャ**: `ARCHITECTURE.md`
- **ロードマップ**: `ROADMAP.md`
- **AI引き継ぎ**: `HANDOFF.md`

---

このガイドに従えば、SWE1.5でも確実に実装できます！
