import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h_1/models/sales_model.dart';
import 'package:h_1/models/customer_model.dart';
import 'package:h_1/widgets/document_card.dart';

void main() {
  group('SalesModel', () {
    late Sales sales;
    late Customer customer;

    setUp(() {
      customer = Customer(
        id: 'test-customer-1',
        formalName: 'テスト顧客',
        displayName: 'テスト顧客',
        updatedAt: DateTime.now(),
      );

      sales = Sales(
        id: 'test-sales-1',
        documentNumber: 'S-2026-001',
        date: DateTime(2026, 3, 8),
        customer: customer,
        items: [],
        subtotal: 0,
        taxAmount: 0,
        total: 0,
        taxRate: 0.1,
        status: DocumentStatus.confirmed,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    });

    test('should create sales with required fields', () {
      expect(sales.id, 'test-sales-1');
      expect(sales.documentNumber, 'S-2026-001');
      expect(sales.customer, customer);
      expect(sales.date, DateTime(2026, 3, 8));
      expect(sales.items, isEmpty);
      expect(sales.subtotal, 0);
      expect(sales.taxAmount, 0);
      expect(sales.total, 0);
      expect(sales.taxRate, 0.1);
      expect(sales.status, DocumentStatus.confirmed);
    });

    test('should return correct display title', () {
      expect(sales.getDisplayTitle(), 'テスト顧客');
    });

    test('should return correct display subtitle', () {
      expect(sales.getDisplaySubtitle(), '');
    });

    test('should return correct display amount', () {
      expect(sales.getDisplayAmount(), '¥0');
    });

    test('should return correct theme color', () {
      expect(sales.getThemeColor(), Colors.green);
    });

    test('should return correct status color', () {
      expect(sales.getStatusColor(), Colors.green); // confirmed status
    });

    test('should return correct document type name', () {
      expect(sales.getDocumentTypeName(), '売上');
    });

    test('should convert to map correctly', () {
      final map = sales.toMap();

      expect(map['id'], 'test-sales-1');
      expect(map['document_number'], 'S-2026-001');
      expect(map['customer_id'], 'test-customer-1');
      expect(map['status'], 'confirmed');
    });

    test('should create from map correctly', () {
      final map = {
        'id': 'test-sales-2',
        'document_number': 'S-2026-002',
        'date': '2026-03-08T00:00:00.000Z',
        'customer_id': 'test-customer-1',
        'subtotal': 20000,
        'tax_amount': 2000,
        'total': 22000,
        'tax_rate': 0.1,
        'status': 'draft',
        'created_at': '2026-03-08T00:00:00.000Z',
        'updated_at': '2026-03-08T00:00:00.000Z',
      };

      final fromMapSales = Sales.fromMap(map, customer);

      expect(fromMapSales.id, 'test-sales-2');
      expect(fromMapSales.documentNumber, 'S-2026-002');
      expect(fromMapSales.status, DocumentStatus.draft);
      expect(fromMapSales.total, 22000);
    });

    test('should handle copyWith correctly', () {
      final copiedSales = sales.copyWith(
        status: DocumentStatus.draft,
        notes: 'テスト備考',
      );

      expect(copiedSales.id, sales.id);
      expect(copiedSales.status, DocumentStatus.draft);
      expect(copiedSales.notes, 'テスト備考');
      expect(copiedSales.customer, sales.customer);
    });

    test('should handle different status colors', () {
      final draftSales = sales.copyWith(status: DocumentStatus.draft);
      final cancelledSales = sales.copyWith(status: DocumentStatus.cancelled);

      expect(draftSales.getStatusColor(), Colors.orange);
      expect(cancelledSales.getStatusColor(), Colors.grey);
    });

    test('should handle null customer', () {
      final salesWithoutCustomer = Sales(
        id: 'test-2',
        documentNumber: 'S-2026-002',
        date: DateTime.now(),
        customer: null,
        items: [],
        subtotal: 0,
        taxAmount: 0,
        total: 0,
        taxRate: 0.1,
        status: DocumentStatus.confirmed,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(salesWithoutCustomer.getDisplayTitle(), '一般客');
    });

    test('should handle negative total for returns', () {
      final returnSales = Sales(
        id: 'return-1',
        documentNumber: 'SR-2026-001',
        date: DateTime.now(),
        customer: customer,
        items: [],
        subtotal: -10000,
        taxAmount: -1000,
        total: -11000,
        taxRate: 0.1,
        status: DocumentStatus.confirmed,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(returnSales.total, -11000);
      expect(returnSales.getDisplayAmount(), '¥-11,000');
    });
  });
}
