import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:h_1/services/sales_repository.dart';
import 'package:h_1/services/database_helper.dart';

void main() {
  sqfliteFfiInit();

  group('SalesRepository - items loading', () {
    late Database database;
    late SalesRepository repository;

    setUp(() async {
      database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      DatabaseHelper.testDatabase = database;
      repository = SalesRepository();

      // Create sales table
      await database.execute('''
        CREATE TABLE sales (
          id TEXT PRIMARY KEY, document_number TEXT NOT NULL, date TEXT NOT NULL,
          customer_id TEXT, subtotal INTEGER NOT NULL, tax_amount INTEGER NOT NULL,
          total INTEGER NOT NULL, tax_rate REAL NOT NULL, notes TEXT, subject TEXT,
          status TEXT NOT NULL, invoice_ids TEXT, invoice_id TEXT,
          created_at TEXT NOT NULL, updated_at TEXT NOT NULL
        )
      ''');

      // Create sales_items table
      await database.execute('''
        CREATE TABLE sales_items (
          id TEXT PRIMARY KEY, sales_id TEXT NOT NULL, product_id TEXT NOT NULL,
          product_name TEXT NOT NULL, quantity INTEGER NOT NULL,
          unit_price INTEGER NOT NULL, subtotal INTEGER NOT NULL,
          tax_rate REAL NOT NULL, notes TEXT
        )
      ''');

      // Create customers table (minimal columns for CustomerRepository query)
      await database.execute('''
        CREATE TABLE customers (
          id TEXT PRIMARY KEY, display_name TEXT NOT NULL, formal_name TEXT NOT NULL,
          is_hidden INTEGER DEFAULT 0, is_current INTEGER DEFAULT 1,
          valid_to TEXT, updated_at TEXT NOT NULL
        )
      ''');

      // Create customer_contacts table (needed by CustomerRepository.getAllCustomers)
      await database.execute('''
        CREATE TABLE customer_contacts (
          id TEXT PRIMARY KEY, customer_id TEXT NOT NULL,
          address TEXT, tel TEXT, email TEXT,
          is_active INTEGER DEFAULT 0, version INTEGER DEFAULT 1,
          created_at TEXT
        )
      ''');

      // Create master_hidden table (needed by CustomerRepository.getAllCustomers)
      await database.execute('''
        CREATE TABLE master_hidden (
          master_type TEXT NOT NULL, master_id TEXT NOT NULL,
          is_hidden INTEGER DEFAULT 0,
          PRIMARY KEY (master_type, master_id)
        )
      ''');
    });

    tearDown(() async {
      DatabaseHelper.testDatabase = null;
      await database.close();
    });

    test('getSales returns Sales with items loaded when items exist', () async {
      // Insert a customer (must satisfy CustomerRepository query filter)
      await database.insert('customers', {
        'id': 'cust-1',
        'display_name': 'テスト顧客',
        'formal_name': 'テスト顧客',
        'is_current': 1,
        'valid_to': null,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Insert a sales record
      final now = DateTime.now().toIso8601String();
      await database.insert('sales', {
        'id': 'sales-1',
        'document_number': 'S-2026-001',
        'date': now,
        'customer_id': 'cust-1',
        'subtotal': 50000,
        'tax_amount': 5000,
        'total': 55000,
        'tax_rate': 0.1,
        'status': 'confirmed',
        'created_at': now,
        'updated_at': now,
      });

      // Insert items
      await database.insert('sales_items', {
        'id': 'si-1',
        'sales_id': 'sales-1',
        'product_id': 'prod-1',
        'product_name': '商品A',
        'quantity': 1,
        'unit_price': 30000,
        'subtotal': 30000,
        'tax_rate': 0.1,
      });
      await database.insert('sales_items', {
        'id': 'si-2',
        'sales_id': 'sales-1',
        'product_id': 'prod-2',
        'product_name': '商品B',
        'quantity': 2,
        'unit_price': 10000,
        'subtotal': 20000,
        'tax_rate': 0.1,
      });

      final result = await repository.getSales('sales-1');

      expect(result, isNotNull);
      expect(result!.items.length, 2);
      expect(result.items[0].productName, '商品A');
      expect(result.items[0].quantity, 1);
      expect(result.items[0].subtotal, 30000);
      expect(result.items[1].productName, '商品B');
      expect(result.items[1].quantity, 2);
      expect(result.items[1].subtotal, 20000);
    });

    test('getSales returns Sales with empty items when no items exist', () async {
      final now = DateTime.now().toIso8601String();
      await database.insert('sales', {
        'id': 'sales-empty',
        'document_number': 'S-2026-002',
        'date': now,
        'subtotal': 0,
        'tax_amount': 0,
        'total': 0,
        'tax_rate': 0.1,
        'status': 'draft',
        'created_at': now,
        'updated_at': now,
      });

      final result = await repository.getSales('sales-empty');

      expect(result, isNotNull);
      expect(result!.items, isEmpty);
    });

    test('getAllSales returns all Sales with items loaded', () async {
      final now = DateTime.now().toIso8601String();

      // Insert two sales
      await database.insert('sales', {
        'id': 'sales-1',
        'document_number': 'S-2026-001',
        'date': now,
        'subtotal': 50000,
        'tax_amount': 5000,
        'total': 55000,
        'tax_rate': 0.1,
        'status': 'confirmed',
        'created_at': now,
        'updated_at': now,
      });
      await database.insert('sales', {
        'id': 'sales-2',
        'document_number': 'S-2026-002',
        'date': now,
        'subtotal': 10000,
        'tax_amount': 1000,
        'total': 11000,
        'tax_rate': 0.1,
        'status': 'draft',
        'created_at': now,
        'updated_at': now,
      });

      // Insert items for sales-1 only
      await database.insert('sales_items', {
        'id': 'si-1',
        'sales_id': 'sales-1',
        'product_id': 'prod-1',
        'product_name': '商品A',
        'quantity': 1,
        'unit_price': 50000,
        'subtotal': 50000,
        'tax_rate': 0.1,
      });

      final results = await repository.getAllSales();

      expect(results.length, 2);
      expect(results[0].items.length, 1); // sales-1 has items
      expect(results[0].items[0].productName, '商品A');
      expect(results[1].items, isEmpty); // sales-2 has no items
    });

    test('getAllSales returns empty list when no sales exist', () async {
      final results = await repository.getAllSales();
      expect(results, isEmpty);
    });

    test('getSalesByInvoiceId returns Sales with items loaded', () async {
      final now = DateTime.now().toIso8601String();

      await database.insert('sales', {
        'id': 'sales-inv',
        'document_number': 'S-2026-003',
        'date': now,
        'subtotal': 30000,
        'tax_amount': 3000,
        'total': 33000,
        'tax_rate': 0.1,
        'status': 'confirmed',
        'invoice_id': 'inv-1',
        'created_at': now,
        'updated_at': now,
      });

      await database.insert('sales_items', {
        'id': 'si-3',
        'sales_id': 'sales-inv',
        'product_id': 'prod-3',
        'product_name': '商品C',
        'quantity': 1,
        'unit_price': 30000,
        'subtotal': 30000,
        'tax_rate': 0.1,
      });

      final results = await repository.getSalesByInvoiceId('inv-1');

      expect(results.length, 1);
      expect(results.first.id, 'sales-inv');
      expect(results.first.items.length, 1);
      expect(results.first.items[0].productName, '商品C');
    });

    test('getSalesByInvoiceId returns empty list when invoice has no sales', () async {
      final results = await repository.getSalesByInvoiceId('non-existent-invoice');
      expect(results, isEmpty);
    });
  });
}
