import 'package:flutter_test/flutter_test.dart';
import 'package:h_1/models/customer_model.dart';

void main() {
  group('CustomerModel', () {
    late Customer customer;

    setUp(() {
      customer = Customer(
        id: 'test-customer-1',
        formalName: '株式会社テスト',
        displayName: 'テスト',
        title: '様',
        department: '営業部',
        tel: '03-1234-5678',
        address: '東京都渋谷区',
        email: 'test@example.com',
        updatedAt: DateTime(2026, 3, 8),
      );
    });

    test('should create customer with all fields', () {
      expect(customer.id, 'test-customer-1');
      expect(customer.formalName, '株式会社テスト');
      expect(customer.displayName, 'テスト');
      expect(customer.title, '様');
      expect(customer.department, '営業部');
      expect(customer.tel, '03-1234-5678');
      expect(customer.address, '東京都渋谷区');
      expect(customer.email, 'test@example.com');
      expect(customer.updatedAt, DateTime(2026, 3, 8));
      expect(customer.isSynced, false);
      expect(customer.isLocked, false);
      expect(customer.isHidden, false);
    });

    test('should create customer with minimal fields', () {
      final minimalCustomer = Customer(
        id: 'test-2',
        formalName: '最小テスト',
        displayName: '最小',
        updatedAt: DateTime.now(),
      );

      expect(minimalCustomer.id, 'test-2');
      expect(minimalCustomer.formalName, '最小テスト');
      expect(minimalCustomer.displayName, '最小');
      expect(minimalCustomer.title, '様'); // default value
      expect(minimalCustomer.department, isNull);
      expect(minimalCustomer.tel, isNull);
      expect(minimalCustomer.address, isNull);
      expect(minimalCustomer.email, isNull);
      expect(minimalCustomer.updatedAt, isA<DateTime>());
    });

    test('should return correct invoice name with department', () {
      expect(customer.invoiceName, '株式会社テスト\n営業部 様');
    });

    test('should return correct invoice name without department', () {
      final customerWithoutDepartment = Customer(
        id: 'test-2',
        formalName: 'テスト会社',
        displayName: 'テスト',
        updatedAt: DateTime.now(),
      );

      expect(customerWithoutDepartment.invoiceName, 'テスト会社 様');
    });

    test('should convert to map correctly', () {
      final map = customer.toMap();
      
      expect(map['id'], 'test-customer-1');
      expect(map['formal_name'], '株式会社テスト');
      expect(map['display_name'], 'テスト');
      expect(map['title'], '様');
      expect(map['department'], '営業部');
      expect(map['tel'], '03-1234-5678');
      expect(map['address'], '東京都渋谷区');
      expect(map['email'], 'test@example.com');
    });

    test('should create from map correctly', () {
      final map = {
        'id': 'test-2',
        'formal_name': 'テスト株式会社',
        'display_name': 'テスト2',
        'title': '殿',
        'department': '経理部',
        'tel': '03-9876-5432',
        'address': '東京都新宿区',
        'email': 'test2@example.com',
        'is_synced': 1,
        'is_locked': 1,
        'is_hidden': 0,
        'updated_at': '2026-03-08T00:00:00.000Z',
      };

      final fromMapCustomer = Customer.fromMap(map);
      
      expect(fromMapCustomer.id, 'test-2');
      expect(fromMapCustomer.formalName, 'テスト株式会社');
      expect(fromMapCustomer.displayName, 'テスト2');
      expect(fromMapCustomer.title, '殿');
      expect(fromMapCustomer.department, '経理部');
      expect(fromMapCustomer.tel, '03-9876-5432');
      expect(fromMapCustomer.address, '東京都新宿区');
      expect(fromMapCustomer.email, 'test2@example.com');
      expect(fromMapCustomer.isSynced, true);
      expect(fromMapCustomer.isLocked, true);
      expect(fromMapCustomer.isHidden, false);
    });

    test('should handle boolean values from map', () {
      final map = {
        'id': 'test-3',
        'formal_name': 'ブールテスト',
        'display_name': 'ブール',
        'is_synced': 0,
        'is_locked': 0,
        'is_hidden': 1,
        'updated_at': '2026-03-08T00:00:00.000Z',
      };

      final fromMapCustomer = Customer.fromMap(map);
      
      expect(fromMapCustomer.isSynced, false);
      expect(fromMapCustomer.isLocked, false);
      expect(fromMapCustomer.isHidden, true);
    });

    test('should handle copyWith correctly', () {
      final copiedCustomer = customer.copyWith(
        displayName: 'コピー済み',
        tel: '03-1111-2222',
      );

      expect(copiedCustomer.id, customer.id);
      expect(copiedCustomer.formalName, customer.formalName);
      expect(copiedCustomer.displayName, 'コピー済み');
      expect(copiedCustomer.tel, '03-1111-2222');
      expect(copiedCustomer.address, customer.address);
    });

    test('should handle empty department in invoice name', () {
      final customerWithEmptyDepartment = Customer(
        id: 'test-2',
        formalName: 'テスト会社',
        displayName: 'テスト',
        department: '',
        updatedAt: DateTime.now(),
      );

      expect(customerWithEmptyDepartment.invoiceName, 'テスト会社 様');
    });

    test('should handle different titles', () {
      final customerWithDifferentTitle = Customer(
        id: 'test-2',
        formalName: 'テスト会社',
        displayName: 'テスト',
        title: '殿',
        updatedAt: DateTime.now(),
      );

      expect(customerWithDifferentTitle.invoiceName, 'テスト会社 殿');
    });

    test('should update timestamp when not provided', () {
      final before = DateTime.now();
      final newCustomer = Customer(
        id: 'test-2',
        formalName: '新規',
        displayName: '新',
        updatedAt: null, // Let it use default
      );
      final after = DateTime.now();

      expect(newCustomer.updatedAt.isAfter(before.subtract(const Duration(seconds: 1))), true);
      expect(newCustomer.updatedAt.isBefore(after.add(const Duration(seconds: 1))), true);
    });
  });
}
