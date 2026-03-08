import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h_1/models/quotation_model.dart';
import 'package:h_1/models/customer_model.dart';
import 'package:h_1/models/base_document.dart';
import 'package:h_1/widgets/document_card.dart';

void main() {
  group('QuotationModel', () {
    late Quotation quotation;
    late Customer customer;

    setUp(() {
      customer = Customer(
        id: 'test-customer-1',
        formalName: 'テスト顧客',
        displayName: 'テスト顧客',
        updatedAt: DateTime.now(),
      );

      quotation = Quotation(
        id: 'test-quotation-1',
        documentNumber: 'Q-2026-001',
        date: DateTime(2026, 3, 8),
        customer: customer,
        items: [],
        subtotal: 0,
        taxAmount: 0,
        total: 0,
        taxRate: 0.1,
        status: DocumentStatus.draft,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    });

    test('should create quotation with required fields', () {
      expect(quotation.id, 'test-quotation-1');
      expect(quotation.documentNumber, 'Q-2026-001');
      expect(quotation.customer, customer);
      expect(quotation.date, DateTime(2026, 3, 8));
      expect(quotation.items, isEmpty);
      expect(quotation.subtotal, 0);
      expect(quotation.taxAmount, 0);
      expect(quotation.total, 0);
      expect(quotation.taxRate, 0.1);
      expect(quotation.status, DocumentStatus.draft);
    });

    test('should return correct display title', () {
      expect(quotation.getDisplayTitle(), 'テスト顧客');
    });

    test('should return correct display subtitle', () {
      expect(quotation.getDisplaySubtitle(), '');
    });

    test('should return correct display amount', () {
      expect(quotation.getDisplayAmount(), '¥0');
    });

    test('should return correct theme color', () {
      expect(quotation.getThemeColor(), Colors.blue);
    });

    test('should return correct status color', () {
      expect(quotation.getStatusColor(), Colors.orange); // draft status
    });

    test('should return correct document type name', () {
      expect(quotation.getDocumentTypeName(), '見積');
    });

    test('should convert to map correctly', () {
      final map = quotation.toMap();
      
      expect(map['id'], 'test-quotation-1');
      expect(map['document_number'], 'Q-2026-001');
      expect(map['customer_id'], 'test-customer-1');
      expect(map['status'], 'draft');
    });

    test('should create from map correctly', () {
      final map = {
        'id': 'test-quotation-2',
        'document_number': 'Q-2026-002',
        'date': '2026-03-08T00:00:00.000Z',
        'customer_id': 'test-customer-1',
        'subtotal': 10000,
        'tax_amount': 1000,
        'total': 11000,
        'tax_rate': 0.1,
        'status': 'confirmed',
        'created_at': '2026-03-08T00:00:00.000Z',
        'updated_at': '2026-03-08T00:00:00.000Z',
      };

      final fromMapQuotation = Quotation.fromMap(map, customer);
      
      expect(fromMapQuotation.id, 'test-quotation-2');
      expect(fromMapQuotation.documentNumber, 'Q-2026-002');
      expect(fromMapQuotation.status, DocumentStatus.confirmed);
      expect(fromMapQuotation.total, 11000);
    });

    test('should handle copyWith correctly', () {
      final copiedQuotation = quotation.copyWith(
        status: DocumentStatus.confirmed,
        notes: 'テスト備考',
      );

      expect(copiedQuotation.id, quotation.id);
      expect(copiedQuotation.status, DocumentStatus.confirmed);
      expect(copiedQuotation.notes, 'テスト備考');
      expect(copiedQuotation.customer, quotation.customer);
    });

    test('should handle different status colors', () {
      final confirmedQuotation = quotation.copyWith(status: DocumentStatus.confirmed);
      final cancelledQuotation = quotation.copyWith(status: DocumentStatus.cancelled);

      expect(confirmedQuotation.getStatusColor(), Colors.blue);
      expect(cancelledQuotation.getStatusColor(), Colors.grey);
    });

    test('should handle null customer', () {
      final quotationWithoutCustomer = Quotation(
        id: 'test-2',
        documentNumber: 'Q-2026-002',
        date: DateTime.now(),
        customer: null,
        items: [],
        subtotal: 0,
        taxAmount: 0,
        total: 0,
        taxRate: 0.1,
        status: DocumentStatus.draft,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(quotationWithoutCustomer.getDisplayTitle(), '一般客');
    });
  });
}
