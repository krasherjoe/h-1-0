import 'package:flutter_test/flutter_test.dart';
import '../../../lib/models/inventory_location_model.dart';

void main() {
  group('InventoryLocation', () {
    test('should create inventory location correctly', () {
      // Arrange
      final now = DateTime.now();

      // Act
      final location = InventoryLocation(
        id: 'test-id',
        warehouseId: 'warehouse-1',
        locationCode: 'A-01',
        locationName: 'ロケーションA-01',
        description: 'テスト用ロケーション',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      // Assert
      expect(location.id, 'test-id');
      expect(location.warehouseId, 'warehouse-1');
      expect(location.locationCode, 'A-01');
      expect(location.locationName, 'ロケーションA-01');
      expect(location.description, 'テスト用ロケーション');
      expect(location.isActive, true);
      expect(location.createdAt, now);
      expect(location.updatedAt, now);
    });

    test('should convert to map correctly', () {
      // Arrange
      final location = InventoryLocation(
        id: 'test-id',
        warehouseId: 'warehouse-1',
        locationCode: 'A-01',
        locationName: 'ロケーションA-01',
        description: 'テスト用ロケーション',
        isActive: true,
        createdAt: DateTime(2023, 1, 1),
        updatedAt: DateTime(2023, 1, 2),
      );

      // Act
      final map = location.toMap();

      // Assert
      expect(map['id'], 'test-id');
      expect(map['warehouse_id'], 'warehouse-1');
      expect(map['location_code'], 'A-01');
      expect(map['location_name'], 'ロケーションA-01');
      expect(map['description'], 'テスト用ロケーション');
      expect(map['is_active'], 1);
      expect(map['created_at'], '2023-01-01T00:00:00.000');
      expect(map['updated_at'], '2023-01-02T00:00:00.000');
    });

    test('should create from map correctly', () {
      // Arrange
      final map = {
        'id': 'test-id',
        'warehouse_id': 'warehouse-1',
        'location_code': 'B-02',
        'location_name': 'ロケーションB-02',
        'description': '別のテスト用ロケーション',
        'is_active': 0,
        'created_at': '2023-01-01T00:00:00.000',
        'updated_at': '2023-01-02T00:00:00.000',
      };

      // Act
      final location = InventoryLocation.fromMap(map);

      // Assert
      expect(location.id, 'test-id');
      expect(location.warehouseId, 'warehouse-1');
      expect(location.locationCode, 'B-02');
      expect(location.locationName, 'ロケーションB-02');
      expect(location.description, '別のテスト用ロケーション');
      expect(location.isActive, false);
      expect(location.createdAt, DateTime(2023, 1, 1));
      expect(location.updatedAt, DateTime(2023, 1, 2));
    });

    test('should handle copyWith correctly', () {
      // Arrange
      final original = InventoryLocation(
        id: 'test-id',
        warehouseId: 'warehouse-1',
        locationCode: 'A-01',
        locationName: 'ロケーションA-01',
        description: 'テスト用ロケーション',
        isActive: true,
        createdAt: DateTime(2023, 1, 1),
        updatedAt: DateTime(2023, 1, 2),
      );
      final newTime = DateTime(2023, 12, 31);

      // Act
      final updated = original.copyWith(
        locationCode: 'A-02',
        isActive: false,
        updatedAt: newTime,
      );

      // Assert
      expect(updated.id, original.id);
      expect(updated.warehouseId, original.warehouseId);
      expect(updated.locationCode, 'A-02');
      expect(updated.locationName, original.locationName);
      expect(updated.description, original.description);
      expect(updated.isActive, false);
      expect(updated.createdAt, original.createdAt);
      expect(updated.updatedAt, newTime);
    });

    test('should handle null description correctly', () {
      // Arrange
      final map = {
        'id': 'test-id',
        'warehouse_id': 'warehouse-1',
        'location_code': 'A-01',
        'location_name': 'ロケーションA-01',
        'is_active': 1,
        'created_at': '2023-01-01T00:00:00.000Z',
        'updated_at': '2023-01-02T00:00:00.000Z',
      };

      // Act
      final location = InventoryLocation.fromMap(map);

      // Assert
      expect(location.description, isNull);
    });

    test('should handle boolean conversion correctly', () {
      // Test true value
      expect(InventoryLocation.fromMap({
        'id': 'test1',
        'warehouse_id': 'warehouse-1',
        'location_code': 'A-01',
        'location_name': 'ロケーションA-01',
        'is_active': 1,
        'created_at': '2023-01-01T00:00:00.000Z',
        'updated_at': '2023-01-02T00:00:00.000Z',
      }).isActive, true);

      // Test false value
      expect(InventoryLocation.fromMap({
        'id': 'test2',
        'warehouse_id': 'warehouse-1',
        'location_code': 'A-01',
        'location_name': 'ロケーションA-01',
        'is_active': 0,
        'created_at': '2023-01-01T00:00:00.000Z',
        'updated_at': '2023-01-02T00:00:00.000Z',
      }).isActive, false);

      // Test default value (should default to true)
      expect(InventoryLocation.fromMap({
        'id': 'test3',
        'warehouse_id': 'warehouse-1',
        'location_code': 'A-01',
        'location_name': 'ロケーションA-01',
        'is_active': null,
        'created_at': '2023-01-01T00:00:00.000Z',
        'updated_at': '2023-01-02T00:00:00.000Z',
      }).isActive, true);
    });

    test('should handle equality correctly', () {
      // Arrange
      final now = DateTime.now();

      final location1 = InventoryLocation(
        id: 'same-id',
        warehouseId: 'warehouse-1',
        locationCode: 'A-01',
        locationName: 'ロケーションA-01',
        description: 'テスト用ロケーション',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final location2 = InventoryLocation(
        id: 'same-id',
        warehouseId: 'warehouse-1',
        locationCode: 'A-01',
        locationName: 'ロケーションA-01',
        description: 'テスト用ロケーション',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final location3 = InventoryLocation(
        id: 'different-id',
        warehouseId: 'warehouse-2',
        locationCode: 'B-01',
        locationName: 'ロケーションB-01',
        description: '別のロケーション',
        isActive: false,
        createdAt: now,
        updatedAt: now,
      );

      // Assert
      expect(location1, equals(location2));
      expect(location1, isNot(equals(location3)));
    });

    test('should have correct string representation', () {
      // Arrange
      final location = InventoryLocation(
        id: 'test-id',
        warehouseId: 'warehouse-1',
        locationCode: 'A-01',
        locationName: 'ロケーションA-01',
        description: 'テスト用ロケーション',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Act
      final stringRepresentation = location.toString();

      // Assert
      expect(stringRepresentation, contains('InventoryLocation'));
      expect(stringRepresentation, contains('test-id'));
      expect(stringRepresentation, contains('A-01'));
      expect(stringRepresentation, contains('ロケーションA-01'));
      expect(stringRepresentation, contains('active: true'));
    });

    test('should handle inactive location string representation', () {
      // Arrange
      final location = InventoryLocation(
        id: 'test-id',
        warehouseId: 'warehouse-1',
        locationCode: 'A-01',
        locationName: 'ロケーションA-01',
        isActive: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Act
      final stringRepresentation = location.toString();

      // Assert
      expect(stringRepresentation, contains('active: false'));
    });
  });

  group('InventoryMovement', () {
    test('should create inventory movement correctly', () {
      // Arrange
      final now = DateTime.now();

      // Act
      final movement = InventoryMovement(
        id: 'test-id',
        productId: 'product-1',
        warehouseId: 'warehouse-1',
        locationId: 'location-1',
        movementType: InventoryMovementType.stockIn,
        quantity: 10,
        referenceId: 'ref-1',
        referenceType: 'purchase',
        notes: 'テスト入庫',
        movementDate: now,
        createdAt: now,
        updatedAt: now,
      );

      // Assert
      expect(movement.id, 'test-id');
      expect(movement.productId, 'product-1');
      expect(movement.warehouseId, 'warehouse-1');
      expect(movement.locationId, 'location-1');
      expect(movement.movementType, InventoryMovementType.stockIn);
      expect(movement.quantity, 10);
      expect(movement.referenceId, 'ref-1');
      expect(movement.referenceType, 'purchase');
      expect(movement.notes, 'テスト入庫');
      expect(movement.movementDate, now);
      expect(movement.createdAt, now);
      expect(movement.updatedAt, now);
    });

    test('should convert to map correctly', () {
      // Arrange
      final movement = InventoryMovement(
        id: 'test-id',
        productId: 'product-1',
        warehouseId: 'warehouse-1',
        locationId: 'location-1',
        movementType: InventoryMovementType.stockOut,
        quantity: 5,
        referenceId: 'ref-1',
        referenceType: 'sales',
        notes: 'テスト出庫',
        movementDate: DateTime(2023, 1, 1),
        createdAt: DateTime(2023, 1, 1),
        updatedAt: DateTime(2023, 1, 2),
      );

      // Act
      final map = movement.toMap();

      // Assert
      expect(map['id'], 'test-id');
      expect(map['product_id'], 'product-1');
      expect(map['warehouse_id'], 'warehouse-1');
      expect(map['location_id'], 'location-1');
      expect(map['movement_type'], 'stockOut');
      expect(map['quantity'], 5);
      expect(map['reference_id'], 'ref-1');
      expect(map['reference_type'], 'sales');
      expect(map['notes'], 'テスト出庫');
      expect(map['movement_date'], '2023-01-01T00:00:00.000');
      expect(map['created_at'], '2023-01-01T00:00:00.000');
      expect(map['updated_at'], '2023-01-02T00:00:00.000');
    });

    test('should create from map correctly', () {
      // Arrange
      final map = {
        'id': 'test-id',
        'product_id': 'product-1',
        'warehouse_id': 'warehouse-1',
        'location_id': 'location-1',
        'movement_type': 'transfer',
        'quantity': 3,
        'reference_id': 'ref-1',
        'reference_type': 'transfer',
        'notes': 'テスト移動',
        'movement_date': '2023-01-01T00:00:00.000',
        'created_at': '2023-01-01T00:00:00.000',
        'updated_at': '2023-01-02T00:00:00.000',
      };

      // Act
      final movement = InventoryMovement.fromMap(map);

      // Assert
      expect(movement.id, 'test-id');
      expect(movement.productId, 'product-1');
      expect(movement.warehouseId, 'warehouse-1');
      expect(movement.locationId, 'location-1');
      expect(movement.movementType, InventoryMovementType.transfer);
      expect(movement.quantity, 3);
      expect(movement.referenceId, 'ref-1');
      expect(movement.referenceType, 'transfer');
      expect(movement.notes, 'テスト移動');
      expect(movement.movementDate, DateTime(2023, 1, 1));
      expect(movement.createdAt, DateTime(2023, 1, 1));
      expect(movement.updatedAt, DateTime(2023, 1, 2));
    });

    test('should handle null optional fields correctly', () {
      // Arrange
      final map = {
        'id': 'test-id',
        'product_id': 'product-1',
        'warehouse_id': 'warehouse-1',
        'movement_type': 'adjustment',
        'quantity': 2,
        'movement_date': '2023-01-01T00:00:00.000Z',
        'created_at': '2023-01-01T00:00:00.000Z',
        'updated_at': '2023-01-02T00:00:00.000Z',
      };

      // Act
      final movement = InventoryMovement.fromMap(map);

      // Assert
      expect(movement.locationId, isNull);
      expect(movement.referenceId, isNull);
      expect(movement.referenceType, isNull);
      expect(movement.notes, isNull);
    });

    test('should handle copyWith correctly', () {
      // Arrange
      final original = InventoryMovement(
        id: 'test-id',
        productId: 'product-1',
        warehouseId: 'warehouse-1',
        locationId: 'location-1',
        movementType: InventoryMovementType.stockIn,
        quantity: 10,
        referenceId: 'ref-1',
        referenceType: 'purchase',
        notes: 'テスト入庫',
        movementDate: DateTime(2023, 1, 1),
        createdAt: DateTime(2023, 1, 1),
        updatedAt: DateTime(2023, 1, 2),
      );
      final newTime = DateTime(2023, 12, 31);

      // Act
      final updated = original.copyWith(
        quantity: 15,
        notes: '更新された入庫',
        updatedAt: newTime,
      );

      // Assert
      expect(updated.id, original.id);
      expect(updated.productId, original.productId);
      expect(updated.warehouseId, original.warehouseId);
      expect(updated.locationId, original.locationId);
      expect(updated.movementType, original.movementType);
      expect(updated.quantity, 15);
      expect(updated.referenceId, original.referenceId);
      expect(updated.referenceType, original.referenceType);
      expect(updated.notes, '更新された入庫');
      expect(updated.movementDate, original.movementDate);
      expect(updated.createdAt, original.createdAt);
      expect(updated.updatedAt, newTime);
    });

    test('should handle movement type names correctly', () {
      // Test all movement types
      expect(InventoryMovementType.stockIn.name, 'stockIn');
      expect(InventoryMovementType.stockOut.name, 'stockOut');
      expect(InventoryMovementType.transfer.name, 'transfer');
      expect(InventoryMovementType.adjustment.name, 'adjustment');
      expect(InventoryMovementType.stocktake.name, 'stocktake');
    });

    test('should handle equality correctly', () {
      // Arrange
      final now = DateTime.now();

      final movement1 = InventoryMovement(
        id: 'same-id',
        productId: 'product-1',
        warehouseId: 'warehouse-1',
        locationId: 'location-1',
        movementType: InventoryMovementType.stockIn,
        quantity: 10,
        referenceId: 'ref-1',
        referenceType: 'purchase',
        notes: 'テスト入庫',
        movementDate: now,
        createdAt: now,
        updatedAt: now,
      );

      final movement2 = InventoryMovement(
        id: 'same-id',
        productId: 'product-1',
        warehouseId: 'warehouse-1',
        locationId: 'location-1',
        movementType: InventoryMovementType.stockIn,
        quantity: 10,
        referenceId: 'ref-1',
        referenceType: 'purchase',
        notes: 'テスト入庫',
        movementDate: now,
        createdAt: now,
        updatedAt: now,
      );

      final movement3 = InventoryMovement(
        id: 'different-id',
        productId: 'product-2',
        warehouseId: 'warehouse-2',
        locationId: 'location-2',
        movementType: InventoryMovementType.stockOut,
        quantity: 5,
        referenceId: 'ref-2',
        referenceType: 'sales',
        notes: 'テスト出庫',
        movementDate: now,
        createdAt: now,
        updatedAt: now,
      );

      // Assert
      expect(movement1, equals(movement2));
      expect(movement1, isNot(equals(movement3)));
    });

    test('should have correct string representation', () {
      // Arrange
      final movement = InventoryMovement(
        id: 'test-id',
        productId: 'product-1',
        warehouseId: 'warehouse-1',
        locationId: 'location-1',
        movementType: InventoryMovementType.stockIn,
        quantity: 10,
        referenceId: 'ref-1',
        referenceType: 'purchase',
        notes: 'テスト入庫',
        movementDate: DateTime(2023, 1, 1),
        createdAt: DateTime(2023, 1, 1),
        updatedAt: DateTime(2023, 1, 2),
      );

      // Act
      final stringRepresentation = movement.toString();

      // Assert
      expect(stringRepresentation, contains('InventoryMovement'));
      expect(stringRepresentation, contains('test-id'));
      expect(stringRepresentation, contains('stockIn'));
      expect(stringRepresentation, contains('quantity: 10'));
    });

    test('should handle invalid movement type gracefully', () {
      // Arrange
      final map = {
        'id': 'test-id',
        'product_id': 'product-1',
        'warehouse_id': 'warehouse-1',
        'movement_type': 'invalid_type',
        'quantity': 5,
        'movement_date': '2023-01-01T00:00:00.000',
        'created_at': '2023-01-01T00:00:00.000',
        'updated_at': '2023-01-02T00:00:00.000',
      };

      // Act
      final movement = InventoryMovement.fromMap(map);

      // Assert - should default to adjustment
      expect(movement.movementType, InventoryMovementType.adjustment);
      expect(movement.movementType.name, 'adjustment');
    });
  });
}
