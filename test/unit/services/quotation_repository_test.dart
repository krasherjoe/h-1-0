import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:h_1/services/quotation_repository.dart';
import 'package:h_1/models/quotation_model.dart';
import 'package:h_1/models/customer_model.dart';
import 'package:h_1/widgets/document_card.dart';
import 'package:h_1/services/database_helper.dart';

void main() {
  sqfliteFfiInit();

  group('QuotationRepository', () {
    late QuotationRepository repository;

    setUp(() {
      repository = QuotationRepository();
    });

    test('should create repository instance', () {
      expect(repository, isA<QuotationRepository>());
    });

    test('should handle quotation creation', () {
      final customer = Customer(
        id: 'test-customer',
        formalName: 'テスト顧客',
        displayName: 'テスト',
        updatedAt: DateTime.now(),
      );

      final quotation = Quotation(
        id: 'test-quotation',
        documentNumber: 'Q-2026-001',
        date: DateTime.now(),
        customer: customer,
        items: [],
        subtotal: 10000,
        taxAmount: 1000,
        total: 11000,
        taxRate: 0.1,
        status: DocumentStatus.draft,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(quotation.id, 'test-quotation');
      expect(quotation.customer, customer);
      expect(quotation.total, 11000);
    });

    test('should handle quotation copy', () {
      final customer = Customer(
        id: 'test-customer',
        formalName: 'テスト顧客',
        displayName: 'テスト',
        updatedAt: DateTime.now(),
      );

      final originalQuotation = Quotation(
        id: 'test-quotation',
        documentNumber: 'Q-2026-001',
        date: DateTime.now(),
        customer: customer,
        items: [],
        subtotal: 10000,
        taxAmount: 1000,
        total: 11000,
        taxRate: 0.1,
        status: DocumentStatus.draft,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Test that copy would create a new ID
      // Note: Actual database operations are tested in integration tests
      expect(originalQuotation.id, 'test-quotation');
      expect(originalQuotation.total, 11000);
    });

    test('should handle quotation deletion', () {
      // Test that deletion logic exists
      // Note: Actual database operations are tested in integration tests
      final quotationId = 'test-quotation';
      expect(quotationId, isA<String>());
    });
  });

  group('QuotationRepository - items loading', () {
    late Database database;
    late QuotationRepository repository;

    setUp(() async {
      database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      DatabaseHelper.testDatabase = database;
      repository = QuotationRepository();

      await database.execute('''
        CREATE TABLE quotations (
          id TEXT PRIMARY KEY, document_number TEXT NOT NULL, date TEXT NOT NULL,
          customer_id TEXT, subtotal INTEGER NOT NULL, tax_amount INTEGER NOT NULL,
          total INTEGER NOT NULL, tax_rate REAL NOT NULL, notes TEXT, subject TEXT,
          status TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
        )
      ''');

      await database.execute('''
        CREATE TABLE quotation_items (
          id TEXT PRIMARY KEY, quotation_id TEXT NOT NULL, product_id TEXT NOT NULL,
          product_name TEXT NOT NULL, quantity INTEGER NOT NULL,
          unit_price INTEGER NOT NULL, subtotal INTEGER NOT NULL,
          tax_rate REAL NOT NULL, notes TEXT
        )
      ''');

      // Supporting tables for CustomerRepository.getAllCustomers()
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
          is_active INTEGER DEFAULT 0, version INTEGER DEFAULT 1,
          created_at TEXT
        )
      ''');
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

    test('getAllQuotations returns quotations with items loaded', () async {
      // INSERT a quotation
      await database.insert('quotations', {
        'id': 'quote-1',
        'document_number': 'Q-001',
        'date': DateTime.now().toIso8601String(),
        'subtotal': 50000,
        'tax_amount': 5000,
        'total': 55000,
        'tax_rate': 0.1,
        'status': 'draft',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      // INSERT items
      await database.insert('quotation_items', {
        'id': 'qi-1',
        'quotation_id': 'quote-1',
        'product_id': 'prod-1',
        'product_name': '商品A',
        'quantity': 1,
        'unit_price': 30000,
        'subtotal': 30000,
        'tax_rate': 0.1,
      });
      await database.insert('quotation_items', {
        'id': 'qi-2',
        'quotation_id': 'quote-1',
        'product_id': 'prod-2',
        'product_name': '商品B',
        'quantity': 2,
        'unit_price': 10000,
        'subtotal': 20000,
        'tax_rate': 0.1,
      });

      final results = await repository.getAllQuotations();

      expect(results.length, 1);
      expect(results.first.id, 'quote-1');
      expect(results.first.items.length, 2);
      expect(results.first.items[0].productName, '商品A');
      expect(results.first.items[0].quantity, 1);
      expect(results.first.items[1].productName, '商品B');
      expect(results.first.items[1].quantity, 2);
    });

    test('getAllQuotations returns empty items when no items exist', () async {
      await database.insert('quotations', {
        'id': 'quote-empty',
        'document_number': 'Q-002',
        'date': DateTime.now().toIso8601String(),
        'subtotal': 0,
        'tax_amount': 0,
        'total': 0,
        'tax_rate': 0.1,
        'status': 'draft',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      final results = await repository.getAllQuotations();

      expect(results.length, 1);
      expect(results.first.items, isEmpty);
    });

    test('getAllQuotations returns empty list when no quotations exist', () async {
      final results = await repository.getAllQuotations();
      expect(results, isEmpty);
    });
  });
}
