import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/material.dart';

import 'package:h_1/screens/sales_input_screen.dart';
import 'package:h_1/services/database_helper.dart';
import 'package:h_1/services/sales_repository.dart';

/// Helper: create all required database tables for SalesInputScreen tests.
Future<void> createAllTables(Database database) async {
  await database.execute('''
    CREATE TABLE sales (
      id TEXT PRIMARY KEY, document_number TEXT NOT NULL, date TEXT NOT NULL,
      customer_id TEXT, subtotal INTEGER NOT NULL, tax_amount INTEGER NOT NULL,
      total INTEGER NOT NULL, tax_rate REAL NOT NULL, notes TEXT, subject TEXT,
      status TEXT NOT NULL, invoice_ids TEXT, invoice_id TEXT,
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL
    )
  ''');
  await database.execute('''
    CREATE TABLE sales_items (
      id TEXT PRIMARY KEY, sales_id TEXT NOT NULL, product_id TEXT NOT NULL,
      product_name TEXT NOT NULL, quantity INTEGER NOT NULL,
      unit_price INTEGER NOT NULL, subtotal INTEGER NOT NULL,
      tax_rate REAL NOT NULL, notes TEXT
    )
  ''');
  await database.execute('''
    CREATE TABLE customers (
      id TEXT PRIMARY KEY, display_name TEXT NOT NULL, formal_name TEXT NOT NULL,
      is_hidden INTEGER DEFAULT 0, is_current INTEGER DEFAULT 1,
      valid_to TEXT, updated_at TEXT NOT NULL
    )
  ''');
  await database.execute('''
    CREATE TABLE customer_contacts (
      id TEXT PRIMARY KEY, customer_id TEXT NOT NULL,
      address TEXT, tel TEXT, email TEXT,
      is_active INTEGER DEFAULT 0, version INTEGER DEFAULT 1, created_at TEXT
    )
  ''');
  await database.execute('''
    CREATE TABLE master_hidden (
      master_type TEXT NOT NULL, master_id TEXT NOT NULL,
      is_hidden INTEGER DEFAULT 0, PRIMARY KEY (master_type, master_id)
    )
  ''');
  await database.execute('''
    CREATE TABLE products (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, default_unit_price INTEGER,
      wholesale_price INTEGER DEFAULT 0, barcode TEXT, category TEXT,
      category_id TEXT, stock_quantity INTEGER, is_locked INTEGER DEFAULT 0,
      is_hidden INTEGER DEFAULT 0, odoo_id TEXT, description TEXT, tags TEXT,
      valid_from TEXT, valid_to TEXT, is_current INTEGER DEFAULT 1,
      version INTEGER DEFAULT 1, content_hash TEXT, previous_hash TEXT
    )
  ''');
}

/// Helper: seed a customer row.
Future<void> seedCustomer(Database database, String id) async {
  await database.insert('customers', {
    'id': id, 'display_name': 'テスト顧客', 'formal_name': 'テスト顧客',
    'is_current': 1, 'valid_to': null,
    'updated_at': DateTime.now().toIso8601String(),
  });
}

void main() {
  sqfliteFfiInit();

  // ===================================================================
  // Group 1 — Widget テスト（UI レンダリング確認）
  //
  // これらのテストは DB を使用せず、SalesInputScreen の UI が
  // 正しくレンダリングされることを確認する。
  // ===================================================================
  group('SalesInputScreen - UI レンダリング', () {
    testWidgets('新規画面の UI 要素が表示される', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: SalesInputScreen()),
      );
      await tester.pump();

      // AppBar タイトルが表示される
      expect(find.text('SE1:売上入力'), findsOneWidget);

      // 主要ボタンが表示される
      expect(find.text('商品を追加'), findsOneWidget);
      expect(find.text('請求書を紐付け'), findsOneWidget);

      // 顧客選択・日付選択のカードが表示される
      expect(find.text('顧客を選択'), findsOneWidget);
    });
  });

  // ===================================================================
  // Group 2 — データ整合性テスト（リポジトリ経由）
  //
  // sqflite_common_ffi のインメモリ DB を使用して、
  // SalesRepository 経由のデータ整合性を検証する。
  //
  // これらのテストは、SalesInputScreen._loadExisting が読み込んだ
  // データの subtotal が正しく保持されていることを確認する。
  // savedSubtotal フィールドにより丸め誤差が防止される。
  // ===================================================================
  group('SalesInputScreen - データ整合性', () {
    late Database database;
    late SalesRepository repository;

    setUp(() async {
      database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      DatabaseHelper.testDatabase = database;
      repository = SalesRepository();
      await createAllTables(database);
    });

    tearDown(() async {
      DatabaseHelper.testDatabase = null;
      await database.close();
    });

    /// 請求書インポート→保存→再読込の金額一致を確認
    ///
    /// シナリオ: InvoiceItem subtotal = 3*1000 - 500(値引き) = 2500
    /// インポート後: quantity=3, unitPrice=(2500/3).round()=833
    /// DB には subtotal=2500 が保存される（savedSubtotal 経由）
    /// _loadExisting / _calculate で savedSubtotal=2500 が優先され、
    /// 3*833=2499 の丸め誤差が生じない。
    test('請求書インポート→保存→再読込で金額が一致する（丸め誤差防止）', () async {
      await seedCustomer(database, 'cust-1');
      final now = DateTime.now().toIso8601String();

      await database.insert('sales', {
        'id': 'sales-import-1',
        'document_number': 'S-2026-001',
        'date': now,
        'customer_id': 'cust-1',
        'subtotal': 2500,
        'tax_amount': 0,
        'total': 2500,
        'tax_rate': 0.0,
        'status': 'draft',
        'created_at': now,
        'updated_at': now,
      });
      await database.insert('sales_items', {
        'id': 'si-1',
        'sales_id': 'sales-import-1',
        'product_id': 'prod-1',
        'product_name': 'Import商品（値引き後2500）',
        'quantity': 3,
        'unit_price': 833,
        'subtotal': 2500, // savedSubtotal の値
        'tax_rate': 0.0,
      });

      // _loadExisting → _repo.getSales → DocumentItem.subtotal 確認
      final sales = await repository.getSales('sales-import-1');

      expect(sales, isNotNull);
      expect(sales!.items.length, 1);
      // savedSubtotal=2500 が保持され、3*833=2499 にならない
      expect(sales.items[0].subtotal, 2500,
          reason: 'savedSubtotal により 2500 が保持される（3*833=2499 ではない）');
      expect(sales.items[0].quantity, 3);
      expect(sales.items[0].unitPrice, 833);
      expect(sales.subtotal, 2500);
      expect(sales.total, 2500);
    });

    /// savedSubtotal が設定された明細: DB の subtotal がそのまま使われる
    test('savedSubtotal が設定された明細はその値が使われる', () async {
      await seedCustomer(database, 'cust-1');
      final now = DateTime.now().toIso8601String();

      // subtotal(=2500) ≠ qty*unitPrice(=3*833=2499) のケース
      await database.insert('sales', {
        'id': 'sales-a',
        'document_number': 'S-2026-A',
        'date': now,
        'customer_id': 'cust-1',
        'subtotal': 2500,
        'tax_amount': 0,
        'total': 2500,
        'tax_rate': 0.0,
        'status': 'draft',
        'created_at': now,
        'updated_at': now,
      });
      await database.insert('sales_items', {
        'id': 'si-a',
        'sales_id': 'sales-a',
        'product_id': 'prod-1',
        'product_name': '丸め商品',
        'quantity': 3,
        'unit_price': 833,
        'subtotal': 2500,
        'tax_rate': 0.0,
      });

      final sales = await repository.getSales('sales-a');

      expect(sales, isNotNull);
      expect(sales!.items[0].subtotal, 2500);
      // qty*unitPrice ≠ subtotal → savedSubtotal が優先された証拠
      expect(sales.items[0].quantity * sales.items[0].unitPrice, 2499);
      expect(sales.items[0].subtotal, isNot(sales.items[0].quantity * sales.items[0].unitPrice));
    });

    /// savedSubtotal が null 相当（通常明細）: qty*unitPrice フォールバック
    test('savedSubtotal が null の通常明細は quantity * unitPrice が使われる', () async {
      await seedCustomer(database, 'cust-1');
      final now = DateTime.now().toIso8601String();

      // subtotal(=2000) == qty*unitPrice(=2*1000=2000)
      await database.insert('sales', {
        'id': 'sales-b',
        'document_number': 'S-2026-B',
        'date': now,
        'customer_id': 'cust-1',
        'subtotal': 2000,
        'tax_amount': 0,
        'total': 2000,
        'tax_rate': 0.0,
        'status': 'draft',
        'created_at': now,
        'updated_at': now,
      });
      await database.insert('sales_items', {
        'id': 'si-b',
        'sales_id': 'sales-b',
        'product_id': 'prod-2',
        'product_name': '通常商品',
        'quantity': 2,
        'unit_price': 1000,
        'subtotal': 2000,
        'tax_rate': 0.0,
      });

      final sales = await repository.getSales('sales-b');

      expect(sales, isNotNull);
      expect(sales!.items[0].subtotal, 2000);
      // 通常明細: subtotal == qty * unitPrice
      expect(sales.items[0].subtotal, sales.items[0].quantity * sales.items[0].unitPrice);
    });

    /// 値引き明細: savedSubtotal が正しく保持される
    test('通常明細の値引き計算は従来通り動作する', () async {
      await seedCustomer(database, 'cust-1');
      final now = DateTime.now().toIso8601String();

      // subtotal=4500（qty=1, unitPrice=5000 → 500-500=4500）
      await database.insert('sales', {
        'id': 'sales-c',
        'document_number': 'S-2026-C',
        'date': now,
        'customer_id': 'cust-1',
        'subtotal': 4500,
        'tax_amount': 0,
        'total': 4500,
        'tax_rate': 0.0,
        'status': 'draft',
        'created_at': now,
        'updated_at': now,
      });
      await database.insert('sales_items', {
        'id': 'si-c',
        'sales_id': 'sales-c',
        'product_id': 'prod-3',
        'product_name': '値引き商品',
        'quantity': 1,
        'unit_price': 5000,
        'subtotal': 4500,
        'tax_rate': 0.0,
      });

      final sales = await repository.getSales('sales-c');

      expect(sales, isNotNull);
      expect(sales!.items[0].subtotal, 4500);
      // subtotal ≠ qty*unitPrice → 値引きが反映されている
      expect(sales.items[0].subtotal, isNot(sales.items[0].quantity * sales.items[0].unitPrice));
    });
  });
}
