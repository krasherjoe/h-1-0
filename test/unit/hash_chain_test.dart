import 'package:flutter_test/flutter_test.dart';
import 'package:h_1/services/hash_utils.dart';
import 'package:h_1/models/customer_model.dart' show Customer;
import 'package:h_1/models/product_model.dart' show Product;

void main() {
  group('HASH Chain - SHA256 Calculation', () {
    test('SHA256 generates 64-character hex string', () {
      final hash = HashUtils.calculateSha256('test');
      expect(hash.length, equals(64));
      expect(hash, matches(RegExp(r'^[a-f0-9]+$')));
    });

    test('Same input produces same hash', () {
      const input = 'customer_123|テスト会社|テスト株式会社';
      final hash1 = HashUtils.calculateSha256(input);
      final hash2 = HashUtils.calculateSha256(input);
      expect(hash1, equals(hash2));
    });

    test('Different input produces different hash', () {
      final hash1 = HashUtils.calculateSha256('input1');
      final hash2 = HashUtils.calculateSha256('input2');
      expect(hash1, isNot(equals(hash2)));
    });
  });

  group('HASH Chain - Customer Hash Calculation', () {
    test('Customer hash includes all fields', () {
      final hash = HashUtils.calculateCustomerHash(
        id: 'cust_001',
        displayName: 'テスト会社',
        formalName: 'テスト株式会社',
        title: '様',
        department: '営業部',
        address: '東京都渋谷区',
        tel: '03-1234-5678',
        email: 'test@example.com',
        contactVersionId: 1,
        odooId: 'odoo_123',
        isLocked: false,
        isHidden: false,
        headChar1: 'テ',
        headChar2: 'ス',
        validFrom: DateTime(2024, 1, 1),
        validTo: null,
        isCurrentFlag: true,
        version: 1,
        previousHash: null,
      );

      expect(hash.length, equals(64));
      expect(hash, matches(RegExp(r'^[a-f0-9]+$')));
    });

    test('Customer hash changes with field modification', () {
      final hash1 = HashUtils.calculateCustomerHash(
        id: 'cust_001',
        displayName: 'テスト会社',
        formalName: 'テスト株式会社',
        title: '様',
        isLocked: false,
        version: 1,
        previousHash: null,
      );

      final hash2 = HashUtils.calculateCustomerHash(
        id: 'cust_001',
        displayName: '変更会社', // Changed
        formalName: 'テスト株式会社',
        title: '様',
        isLocked: false,
        version: 1,
        previousHash: null,
      );

      expect(hash1, isNot(equals(hash2)));
    });

    test('Customer hash includes previous_hash for chain', () {
      const prevHash = 'abc123def456';

      final hash1 = HashUtils.calculateCustomerHash(
        id: 'cust_001',
        displayName: 'テスト会社',
        formalName: 'テスト株式会社',
        title: '様',
        previousHash: null,
      );

      final hash2 = HashUtils.calculateCustomerHash(
        id: 'cust_001',
        displayName: 'テスト会社',
        formalName: 'テスト株式会社',
        title: '様',
        previousHash: prevHash,
      );

      expect(hash1, isNot(equals(hash2)));
    });

    test('Customer integrity verification works', () {
      final customer = Customer(
        id: 'cust_001',
        displayName: 'テスト会社',
        formalName: 'テスト株式会社',
        title: '様',
        department: '営業部',
        address: '東京都渋谷区',
        tel: '03-1234-5678',
        email: 'test@example.com',
        contactVersionId: 1,
        odooId: 'odoo_123',
        isLocked: false,
        isHidden: false,
        headChar1: 'テ',
        headChar2: 'ス',
        validFrom: DateTime(2024, 1, 1),
        version: 1,
      );

      final hash = HashUtils.calculateCustomerHash(
        id: customer.id!,
        displayName: customer.displayName,
        formalName: customer.formalName,
        title: customer.title,
        department: customer.department,
        address: customer.address,
        tel: customer.tel,
        email: customer.email,
        contactVersionId: customer.contactVersionId,
        odooId: customer.odooId,
        isLocked: customer.isLocked,
        isHidden: customer.isHidden,
        headChar1: customer.headChar1,
        headChar2: customer.headChar2,
        validFrom: customer.validFrom,
        version: customer.version,
      );

      final isValid = HashUtils.verifyCustomerIntegrity(
        contentHash: hash,
        id: customer.id!,
        displayName: customer.displayName,
        formalName: customer.formalName,
        title: customer.title,
        department: customer.department,
        address: customer.address,
        tel: customer.tel,
        email: customer.email,
        contactVersionId: customer.contactVersionId,
        odooId: customer.odooId,
        isLocked: customer.isLocked,
        isHidden: customer.isHidden,
        headChar1: customer.headChar1,
        headChar2: customer.headChar2,
        validFrom: customer.validFrom,
        version: customer.version,
      );

      expect(isValid, isTrue);
    });

    test('Tampered data fails integrity check', () {
      final hash = HashUtils.calculateCustomerHash(
        id: 'cust_001',
        displayName: 'テスト会社',
        formalName: 'テスト株式会社',
        title: '様',
        isLocked: false,
        version: 1,
      );

      // Tamper with the data
      final isValid = HashUtils.verifyCustomerIntegrity(
        contentHash: hash,
        id: 'cust_001',
        displayName: '改ざん会社', // Tampered!
        formalName: 'テスト株式会社',
        title: '様',
        isLocked: false,
        version: 1,
      );

      expect(isValid, isFalse);
    });
  });

  group('HASH Chain - Product Hash Calculation', () {
    test('Product hash includes all fields', () {
      final hash = HashUtils.calculateProductHash(
        id: 'prod_001',
        name: 'テスト商品',
        defaultUnitPrice: 1000,
        wholesalePrice: 800,
        barcode: '1234567890123',
        category: '飲料',
        categoryId: 'cat_001',
        stockQuantity: 100,
        odooId: 'odoo_prod_123',
        isLocked: false,
        isHidden: false,
        validFrom: DateTime(2024, 1, 1),
        validTo: null,
        isCurrentFlag: true,
        version: 1,
        previousHash: null,
      );

      expect(hash.length, equals(64));
      expect(hash, matches(RegExp(r'^[a-f0-9]+$')));
    });

    test('Product hash changes with field modification', () {
      final hash1 = HashUtils.calculateProductHash(
        id: 'prod_001',
        name: 'テスト商品',
        defaultUnitPrice: 1000,
        wholesalePrice: 800,
        isLocked: false,
        version: 1,
      );

      final hash2 = HashUtils.calculateProductHash(
        id: 'prod_001',
        name: '変更商品', // Changed
        defaultUnitPrice: 1000,
        wholesalePrice: 800,
        isLocked: false,
        version: 1,
      );

      expect(hash1, isNot(equals(hash2)));
    });

    test('Product integrity verification works', () {
      final product = Product(
        id: 'prod_001',
        name: 'テスト商品',
        defaultUnitPrice: 1000,
        wholesalePrice: 800,
        barcode: '1234567890123',
        category: '飲料',
        categoryId: 'cat_001',
        stockQuantity: 100,
        odooId: 'odoo_prod_123',
        isLocked: false,
        isHidden: false,
        validFrom: DateTime(2024, 1, 1),
        version: 1,
      );

      final hash = HashUtils.calculateProductHash(
        id: product.id!,
        name: product.name,
        defaultUnitPrice: product.defaultUnitPrice,
        wholesalePrice: product.wholesalePrice,
        barcode: product.barcode,
        category: product.category,
        categoryId: product.categoryId,
        stockQuantity: product.stockQuantity,
        odooId: product.odooId,
        isLocked: product.isLocked,
        isHidden: product.isHidden,
        validFrom: product.validFrom,
        version: product.version,
      );

      final isValid = HashUtils.verifyProductIntegrity(
        contentHash: hash,
        id: product.id!,
        name: product.name,
        defaultUnitPrice: product.defaultUnitPrice,
        wholesalePrice: product.wholesalePrice,
        barcode: product.barcode,
        category: product.category,
        categoryId: product.categoryId,
        stockQuantity: product.stockQuantity,
        odooId: product.odooId,
        isLocked: product.isLocked,
        isHidden: product.isHidden,
        validFrom: product.validFrom,
        version: product.version,
      );

      expect(isValid, isTrue);
    });

    test('Tampered product data fails integrity check', () {
      final hash = HashUtils.calculateProductHash(
        id: 'prod_001',
        name: 'テスト商品',
        defaultUnitPrice: 1000,
        wholesalePrice: 800,
        isLocked: false,
        version: 1,
      );

      // Tamper with the data
      final isValid = HashUtils.verifyProductIntegrity(
        contentHash: hash,
        id: 'prod_001',
        name: '改ざん商品', // Tampered!
        defaultUnitPrice: 1000,
        wholesalePrice: 800,
        isLocked: false,
        version: 1,
      );

      expect(isValid, isFalse);
    });
  });

  group('HASH Chain - Version Increment', () {
    test('Version increments correctly on update', () {
      const prevHash = 'prev_hash_abc123';

      final hashV1 = HashUtils.calculateCustomerHash(
        id: 'cust_001',
        displayName: 'テスト会社',
        formalName: 'テスト株式会社',
        title: '様',
        version: 1,
        previousHash: null,
      );

      final hashV2 = HashUtils.calculateCustomerHash(
        id: 'cust_001',
        displayName: 'テスト会社',
        formalName: 'テスト株式会社',
        title: '様',
        version: 2, // Version incremented
        previousHash: prevHash, // Previous hash linked
      );

      expect(hashV1, isNot(equals(hashV2)));

      // Verify chain integrity
      final v1Valid = HashUtils.verifyCustomerIntegrity(
        contentHash: hashV1,
        id: 'cust_001',
        displayName: 'テスト会社',
        formalName: 'テスト株式会社',
        title: '様',
        version: 1,
        previousHash: null,
      );

      final v2Valid = HashUtils.verifyCustomerIntegrity(
        contentHash: hashV2,
        id: 'cust_001',
        displayName: 'テスト会社',
        formalName: 'テスト株式会社',
        title: '様',
        version: 2,
        previousHash: prevHash,
      );

      expect(v1Valid, isTrue);
      expect(v2Valid, isTrue);
    });
  });
}
