# TEST-ADD-001: 単体テスト追加

**タスクID**: TEST-ADD-001  
**優先度**: 🔴 高  
**担当**: SWE1.5  
**推定時間**: 2時間  
**作成日**: 2026-03-08

---

## 📝 タスク概要

基本的な単体テストを追加する。モデルクラス、リポジトリクラス、基本的なウィジェットのテストを作成し、コード品質を向上させる。

### 背景
現在テストコードがほとんど存在しないため、基本的な単体テストを追加してリグレッションを防ぎ、将来のリファクタリングを安全にする。

---

## ✅ 前提条件確認

- [ ] Flutterプロジェクトのテスト環境が整っていること
- [ ] testパッケージがpubspec.yamlに含まれていること
- [ ] テスト対象のクラスが存在することを確認

---

## 🎯 対象ファイル

### モデルクラスのテスト
1. `lib/models/quotation_model.dart` - 見積モデル
2. `lib/models/sales_model.dart` - 売上モデル
3. `lib/models/customer_model.dart` - 得意先モデル

### リポジトリクラスのテスト
1. `lib/services/quotation_repository.dart` - 見積リポジトリ
2. `lib/services/sales_repository.dart` - 売上リポジトリ
3. `lib/services/customer_repository.dart` - 得意先リポジトリ

### ウィジェットのテスト
1. `lib/widgets/document_card.dart` - ドキュメントカード
2. `lib/widgets/empty_state_widget.dart` - 空状態ウィジェット

---

## 📋 実行手順

### Step 1: テストディレクトリ構造を確認

現在のテストディレクトリを確認：

```bash
ls -la test/
```

必要に応じてディレクトリを作成：

```bash
mkdir -p test/unit/models
mkdir -p test/unit/services
mkdir -p test/unit/widgets
```

### Step 2: モデルクラスの単体テストを作成

#### 2-1. quotation_model_test.dart

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gemi_invoice/models/quotation_model.dart';
import 'package:gemi_invoice/models/base_document.dart';

void main() {
  group('QuotationModel', () {
    late Quotation quotation;
    late Customer customer;

    setUp(() {
      customer = Customer(
        id: 'test-customer-1',
        formalName: 'テスト顧客',
        displayName: 'テスト顧客',
        createdAt: DateTime.now(),
      );

      quotation = Quotation(
        id: 'test-quotation-1',
        customer: customer,
        date: DateTime(2026, 3, 8),
        items: [],
        isDraft: false,
      );
    });

    test('should create quotation with required fields', () {
      expect(quotation.id, 'test-quotation-1');
      expect(quotation.customer, customer);
      expect(quotation.date, DateTime(2026, 3, 8));
      expect(quotation.items, isEmpty);
      expect(quotation.isDraft, false);
    });

    test('should calculate total amount correctly', () {
      final quotationWithItems = Quotation(
        id: 'test-2',
        customer: customer,
        date: DateTime.now(),
        items: [
          QuotationItem(
            productId: 'product-1',
            productName: 'テスト商品',
            quantity: 2,
            unitPrice: 1000,
            taxRate: 0.1,
          ),
          QuotationItem(
            productId: 'product-2',
            productName: 'テスト商品2',
            quantity: 1,
            unitPrice: 2000,
            taxRate: 0.1,
          ),
        ],
        isDraft: false,
      );

      final expectedTotal = (2 * 1000 * 1.1) + (1 * 2000 * 1.1); // 2200 + 2200 = 4400
      expect(quotationWithItems.totalAmount, 4400);
    });

    test('should return correct display title', () {
      expect(quotation.getDisplayTitle(), 'テスト顧客');
    });

    test('should return correct display subtitle', () {
      expect(quotation.getDisplaySubtitle(), contains('2026/03/08'));
      expect(quotation.getDisplaySubtitle(), contains('下書き'));
    });

    test('should return correct display amount', () {
      expect(quotation.getDisplayAmount(), '¥0');
    });

    test('should return correct theme color', () {
      expect(quotation.getThemeColor(), Colors.blue);
    });
  });
}
```

#### 2-2. sales_model_test.dart

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gemi_invoice/models/sales_model.dart';
import 'package:gemi_invoice/models/base_document.dart';

void main() {
  group('SalesModel', () {
    late Sales sales;
    late Customer customer;

    setUp(() {
      customer = Customer(
        id: 'test-customer-1',
        formalName: 'テスト顧客',
        displayName: 'テスト顧客',
        createdAt: DateTime.now(),
      );

      sales = Sales(
        id: 'test-sales-1',
        customer: customer,
        date: DateTime(2026, 3, 8),
        items: [],
        isDraft: false,
      );
    });

    test('should create sales with required fields', () {
      expect(sales.id, 'test-sales-1');
      expect(sales.customer, customer);
      expect(sales.date, DateTime(2026, 3, 8));
      expect(sales.items, isEmpty);
      expect(sales.isDraft, false);
    });

    test('should calculate total amount correctly', () {
      final salesWithItems = Sales(
        id: 'test-2',
        customer: customer,
        date: DateTime.now(),
        items: [
          SalesItem(
            productId: 'product-1',
            productName: 'テスト商品',
            quantity: 3,
            unitPrice: 1500,
            taxRate: 0.1,
          ),
        ],
        isDraft: false,
      );

      final expectedTotal = 3 * 1500 * 1.1; // 4950
      expect(salesWithItems.totalAmount, 4950);
    });

    test('should return correct display title', () {
      expect(sales.getDisplayTitle(), 'テスト顧客');
    });

    test('should return correct display subtitle', () {
      expect(sales.getDisplaySubtitle(), contains('2026/03/08'));
    });

    test('should return correct display amount', () {
      expect(sales.getDisplayAmount(), '¥0');
    });

    test('should return correct theme color', () {
      expect(sales.getThemeColor(), Colors.green);
    });
  });
}
```

#### 2-3. customer_model_test.dart

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gemi_invoice/models/customer_model.dart';

void main() {
  group('CustomerModel', () {
    late Customer customer;

    setUp(() {
      customer = Customer(
        id: 'test-customer-1',
        formalName: '株式会社テスト',
        displayName: 'テスト',
        tel: '03-1234-5678',
        address: '東京都渋谷区',
        createdAt: DateTime(2026, 3, 8),
      );
    });

    test('should create customer with required fields', () {
      expect(customer.id, 'test-customer-1');
      expect(customer.formalName, '株式会社テスト');
      expect(customer.displayName, 'テスト');
      expect(customer.tel, '03-1234-5678');
      expect(customer.address, '東京都渋谷区');
      expect(customer.createdAt, DateTime(2026, 3, 8));
    });

    test('should create customer with minimal fields', () {
      final minimalCustomer = Customer(
        id: 'test-2',
        formalName: '最小テスト',
        displayName: '最小',
        createdAt: DateTime.now(),
      );

      expect(minimalCustomer.id, 'test-2');
      expect(minimalCustomer.formalName, '最小テスト');
      expect(minimalCustomer.displayName, '最小');
      expect(minimalCustomer.tel, isNull);
      expect(minimalCustomer.address, isNull);
    });

    test('should handle empty display name', () {
      final customerWithoutDisplayName = Customer(
        id: 'test-3',
        formalName: 'テスト会社',
        createdAt: DateTime.now(),
      );

      expect(customerWithoutDisplayName.displayName, 'テスト会社');
    });
  });
}
```

### Step 3: リポジトリクラスの単体テストを作成

#### 3-1. quotation_repository_test.dart

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gemi_invoice/services/quotation_repository.dart';
import 'package:gemi_invoice/services/database_helper.dart';
import 'package:gemi_invoice/models/quotation_model.dart';
import 'package:gemi_invoice/models/customer_model.dart';

void main() {
  group('QuotationRepository', () {
    late QuotationRepository repository;
    late Database database;

    setUpAll(() async {
      // Initialize FFI
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      // Create in-memory database for testing
      database = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseHelper._databaseVersion,
        onCreate: (db, version) async {
          // Create tables
          await db.execute('''
            CREATE TABLE customers (
              id TEXT PRIMARY KEY,
              formal_name TEXT NOT NULL,
              display_name TEXT,
              tel TEXT,
              address TEXT,
              created_at TEXT NOT NULL
            )
          ''');
          
          await db.execute('''
            CREATE TABLE quotations (
              id TEXT PRIMARY KEY,
              customer_id TEXT NOT NULL,
              date TEXT NOT NULL,
              is_draft INTEGER NOT NULL DEFAULT 1,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              FOREIGN KEY (customer_id) REFERENCES customers (id)
            )
          ''');
          
          await db.execute('''
            CREATE TABLE quotation_items (
              id TEXT PRIMARY KEY,
              quotation_id TEXT NOT NULL,
              product_id TEXT,
              product_name TEXT,
              quantity REAL NOT NULL,
              unit_price REAL NOT NULL,
              tax_rate REAL NOT NULL DEFAULT 0.1,
              FOREIGN KEY (quotation_id) REFERENCES quotations (id)
            )
          ''');
        },
      );
      
      repository = QuotationRepository();
      // Set test database
      // Note: This might require modifying the repository to accept a database instance
    });

    tearDown(() async {
      await database.close();
    });

    test('should create quotation successfully', () async {
      final customer = Customer(
        id: 'test-customer',
        formalName: 'テスト顧客',
        displayName: 'テスト',
        createdAt: DateTime.now(),
      );

      // Insert customer first
      await database.insert('customers', customer.toMap());

      final quotation = Quotation(
        id: 'test-quotation',
        customer: customer,
        date: DateTime.now(),
        items: [],
        isDraft: true,
      );

      // This test might need adjustment based on actual repository implementation
      // await repository.saveQuotation(quotation);
      
      // Verify
      // final savedQuotation = await repository.getQuotation(quotation.id);
      // expect(savedQuotation?.id, quotation.id);
    });

    test('should get all quotations', () async {
      // This test would require setting up test data
      // final quotations = await repository.getAllQuotations();
      // expect(quotations, isA<List<Quotation>>());
    });
  });
}
```

### Step 4: ウィジェットテストを作成

#### 4-1. document_card_test.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gemi_invoice/widgets/document_card.dart';
import 'package:gemi_invoice/models/quotation_model.dart';
import 'package:gemi_invoice/models/customer_model.dart';

void main() {
  group('DocumentCard', () {
    late Quotation testQuotation;
    late Customer testCustomer;

    setUp(() {
      testCustomer = Customer(
        id: 'test-customer',
        formalName: 'テスト顧客',
        displayName: 'テスト',
        createdAt: DateTime.now(),
      );

      testQuotation = Quotation(
        id: 'test-quotation',
        customer: testCustomer,
        date: DateTime(2026, 3, 8),
        items: [],
        isDraft: false,
      );
    });

    testWidgets('should display document information', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocumentCard(
              title: testQuotation.getDisplayTitle(),
              subtitle: testQuotation.getDisplaySubtitle(),
              amount: testQuotation.getDisplayAmount(),
              date: testQuotation.date,
              status: testQuotation.status,
              themeColor: testQuotation.getThemeColor(),
              onTap: () {},
              actions: [],
            ),
          ),
        ),
      );

      expect(find.text('テスト'), findsOneWidget);
      expect(find.text('¥0'), findsOneWidget);
    });

    testWidgets('should handle tap correctly', (tester) async {
      bool wasTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocumentCard(
              title: testQuotation.getDisplayTitle(),
              subtitle: testQuotation.getDisplaySubtitle(),
              amount: testQuotation.getDisplayAmount(),
              date: testQuotation.date,
              status: testQuotation.status,
              themeColor: testQuotation.getThemeColor(),
              onTap: () => wasTapped = true,
              actions: [],
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Card));
      await tester.pump();

      expect(wasTapped, isTrue);
    });
  });
}
```

#### 4-2. empty_state_widget_test.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gemi_invoice/widgets/empty_state_widget.dart';

void main() {
  group('EmptyStateWidget', () {
    testWidgets('should display empty state information', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.inbox,
              title: 'データがありません',
              subtitle: '新しいデータを作成してください',
              actionLabel: '作成',
              iconColor: Colors.grey,
              onAction: () {},
            ),
          ),
        ),
      );

      expect(find.text('データがありません'), findsOneWidget);
      expect(find.text('新しいデータを作成してください'), findsOneWidget);
      expect(find.text('作成'), findsOneWidget);
      expect(find.byIcon(Icons.inbox), findsOneWidget);
    });

    testWidgets('should handle action button tap', (tester) async {
      bool actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.inbox,
              title: 'データがありません',
              subtitle: '新しいデータを作成してください',
              actionLabel: '作成',
              iconColor: Colors.grey,
              onAction: () => actionTapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('作成'));
      await tester.pump();

      expect(actionTapped, isTrue);
    });
  });
}
```

### Step 5: flutter testでテスト実行

```bash
cd /home/user/dev/h-1.flutter.0
flutter test
```

### Step 6: カバレッジを確認

```bash
cd /home/user/dev/h-1.flutter.0
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

カバレッジレポートを確認：
- `coverage/html/index.html` をブラウザで開く

### Step 7: 完了報告

`docs/PROGRESS.md` の末尾に追記：

```markdown
## 2026-03-08 TEST-ADD-001
- ✅ quotation_model_test.dart 作成完了
- ✅ sales_model_test.dart 作成完了
- ✅ customer_model_test.dart 作成完了
- ✅ quotation_repository_test.dart 作成完了
- ✅ document_card_test.dart 作成完了
- ✅ empty_state_widget_test.dart 作成完了
- ✅ flutter test: すべてパス
- ✅ カバレッジ: XX%
```

チャットにも同じ内容を報告：

```
TEST-ADD-001 完了

✅ quotation_model_test.dart 作成完了
✅ sales_model_test.dart 作成完了
✅ customer_model_test.dart 作成完了
✅ quotation_repository_test.dart 作成完了
✅ document_card_test.dart 作成完了
✅ empty_state_widget_test.dart 作成完了
✅ flutter test: すべてパス
✅ カバレッジ: XX%

次のタスク指示を待機します。
```

---

## ✅ 完了条件

- [ ] モデルクラス3つの単体テスト作成
- [ ] リポジトリクラス3つの単体テスト作成
- [ ] ウィジェット2つのテスト作成
- [ ] `flutter test` すべてパス
- [ ] カバレッジ70%以上
- [ ] `docs/PROGRESS.md` に完了報告を追記
- [ ] チャットに完了報告

---

## 🔧 トラブルシューティング

### エラー: "No such file or directory"
**原因**: テストファイルのパスが間違っている  
**解決**: `test/` ディレクトリの構造を確認し、正しいパスに修正

### エラー: "Database is locked"
**原因**: テスト間でデータベースが共有されている  
**解決**: 各テストでin-memoryデータベースを使用する

### エラー: "Cannot find widget"
**原因**: MaterialAppでウィジェットをラップしていない  
**解決**: テスト対象のウィジェットをMaterialAppでラップする

### カバレッジが低い
**原因**: 重要なメソッドがテストされていない  
**解決**: カバレッジレポートを確認し、未テストのメソッドを追加

---

## 📚 参考資料

### 必須
- **Flutterテストガイド**: https://docs.flutter.dev/testing
- **テストクックブック**: https://docs.flutter.dev/cookbook/testing

### 補足
- **mockitoパッケージ**: https://pub.dev/packages/mockito
- **fake_asyncパッケージ**: https://pub.dev/packages/fake_async

---

## 🔄 次のタスク

このタスク完了後、`docs/NEXT_TASK.md` を以下に更新：

**次のタスクID**: STAGE-I  
**タスク名**: 仕入モジュール完成

---

このタスクを完了したら、必ず完了報告を行ってください。
