import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:sqflite/sqflite.dart';
import '../../../lib/models/inventory_location_model.dart';
import '../../../lib/services/inventory_location_repository.dart';
import '../../../lib/services/database_helper.dart';

import 'inventory_location_repository_test.mocks.dart';

@GenerateMocks([DatabaseHelper])
void main() {
  group('InventoryLocationRepository', () {
    late InventoryLocationRepository repository;
    late MockDatabaseHelper mockDb;

    setUp(() {
      mockDb = MockDatabaseHelper();
      repository = InventoryLocationRepository();
    });

    test('should create repository instance', () {
      // Assert
      expect(repository, isNotNull);
      expect(repository, isA<InventoryLocationRepository>());
    });

    group('getAllLocations', () {
      test('should return all locations', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.query(
          'inventory_locations',
          orderBy: 'warehouse_id, location_code',
        )).thenAnswer((_) async => [
          {
            'id': 'location-1',
            'warehouse_id': 'warehouse-1',
            'location_code': 'A-01',
            'location_name': 'ロケーションA-01',
            'description': 'テスト用ロケーション1',
            'is_active': 1,
            'created_at': '2023-01-01T00:00:00.000Z',
            'updated_at': '2023-01-02T00:00:00.000Z',
          },
          {
            'id': 'location-2',
            'warehouse_id': 'warehouse-2',
            'location_code': 'B-01',
            'location_name': 'ロケーションB-01',
            'description': 'テスト用ロケーション2',
            'is_active': 0,
            'created_at': '2023-01-01T00:00:00.000Z',
            'updated_at': '2023-01-01T00:00:00.000Z',
          }
        ]);

        // Act
        final result = await repository.getAllLocations();

        // Assert
        expect(result.length, 2);
        expect(result[0].id, 'location-1');
        expect(result[0].warehouseId, 'warehouse-1');
        expect(result[0].locationCode, 'A-01');
        expect(result[0].isActive, true);
        expect(result[1].id, 'location-2');
        expect(result[1].warehouseId, 'warehouse-2');
        expect(result[1].locationCode, 'B-01');
        expect(result[1].isActive, false);
        verify(mockDatabase.query(
          'inventory_locations',
          orderBy: 'warehouse_id, location_code',
        )).called(1);
      });

      test('should return empty list when no locations exist', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.query(
          'inventory_locations',
          orderBy: 'warehouse_id, location_code',
        )).thenAnswer((_) async => []);

        // Act
        final result = await repository.getAllLocations();

        // Assert
        expect(result, isEmpty);
        verify(mockDatabase.query(
          'inventory_locations',
          orderBy: 'warehouse_id, location_code',
        )).called(1);
      });
    });

    group('getLocationsByWarehouse', () {
      test('should return locations for specific warehouse', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.query(
          'inventory_locations',
          where: 'warehouse_id = ?',
          whereArgs: ['warehouse-1'],
          orderBy: 'location_code',
        )).thenAnswer((_) async => [
          {
            'id': 'location-1',
            'warehouse_id': 'warehouse-1',
            'location_code': 'A-01',
            'location_name': 'ロケーションA-01',
            'description': 'テスト用ロケーション1',
            'is_active': 1,
            'created_at': '2023-01-01T00:00:00.000Z',
            'updated_at': '2023-01-02T00:00:00.000Z',
          },
          {
            'id': 'location-2',
            'warehouse_id': 'warehouse-1',
            'location_code': 'A-02',
            'location_name': 'ロケーションA-02',
            'description': 'テスト用ロケーション2',
            'is_active': 1,
            'created_at': '2023-01-01T00:00:00.000Z',
            'updated_at': '2023-01-01T00:00:00.000Z',
          }
        ]);

        // Act
        final result = await repository.getLocationsByWarehouse('warehouse-1');

        // Assert
        expect(result.length, 2);
        expect(result.every((loc) => loc.warehouseId == 'warehouse-1'), true);
        expect(result[0].locationCode, 'A-01');
        expect(result[1].locationCode, 'A-02');
        verify(mockDatabase.query(
          'inventory_locations',
          where: 'warehouse_id = ?',
          whereArgs: ['warehouse-1'],
          orderBy: 'location_code',
        )).called(1);
      });

      test('should return empty list for warehouse with no locations', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.query(
          'inventory_locations',
          where: 'warehouse_id = ?',
          whereArgs: ['empty-warehouse'],
          orderBy: 'location_code',
        )).thenAnswer((_) async => []);

        // Act
        final result = await repository.getLocationsByWarehouse('empty-warehouse');

        // Assert
        expect(result, isEmpty);
        verify(mockDatabase.query(
          'inventory_locations',
          where: 'warehouse_id = ?',
          whereArgs: ['empty-warehouse'],
          orderBy: 'location_code',
        )).called(1);
      });
    });

    group('getActiveLocations', () {
      test('should return only active locations', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.query(
          'inventory_locations',
          where: 'is_active = ?',
          whereArgs: [1],
          orderBy: 'warehouse_id, location_code',
        )).thenAnswer((_) async => [
          {
            'id': 'location-1',
            'warehouse_id': 'warehouse-1',
            'location_code': 'A-01',
            'location_name': 'ロケーションA-01',
            'description': 'テスト用ロケーション1',
            'is_active': 1,
            'created_at': '2023-01-01T00:00:00.000Z',
            'updated_at': '2023-01-02T00:00:00.000Z',
          },
          {
            'id': 'location-3',
            'warehouse_id': 'warehouse-2',
            'location_code': 'C-01',
            'location_name': 'ロケーションC-01',
            'description': 'テスト用ロケーション3',
            'is_active': 1,
            'created_at': '2023-01-01T00:00:00.000Z',
            'updated_at': '2023-01-01T00:00:00.000Z',
          }
        ]);

        // Act
        final result = await repository.getActiveLocations();

        // Assert
        expect(result.length, 2);
        expect(result.every((loc) => loc.isActive), true);
        verify(mockDatabase.query(
          'inventory_locations',
          where: 'is_active = ?',
          whereArgs: [1],
          orderBy: 'warehouse_id, location_code',
        )).called(1);
      });
    });

    group('getLocation', () {
      test('should return location when found', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.query(
          'inventory_locations',
          where: 'id = ?',
          whereArgs: ['location-1'],
          limit: 1,
        )).thenAnswer((_) async => [
          {
            'id': 'location-1',
            'warehouse_id': 'warehouse-1',
            'location_code': 'A-01',
            'location_name': 'ロケーションA-01',
            'description': 'テスト用ロケーション',
            'is_active': 1,
            'created_at': '2023-01-01T00:00:00.000Z',
            'updated_at': '2023-01-02T00:00:00.000Z',
          }
        ]);

        // Act
        final result = await repository.getLocation('location-1');

        // Assert
        expect(result, isNotNull);
        expect(result!.id, 'location-1');
        expect(result.locationCode, 'A-01');
        expect(result.isActive, true);
        verify(mockDatabase.query(
          'inventory_locations',
          where: 'id = ?',
          whereArgs: ['location-1'],
          limit: 1,
        )).called(1);
      });

      test('should return null when location not found', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.query(
          'inventory_locations',
          where: 'id = ?',
          whereArgs: ['non-existent'],
          limit: 1,
        )).thenAnswer((_) async => []);

        // Act
        final result = await repository.getLocation('non-existent');

        // Assert
        expect(result, isNull);
        verify(mockDatabase.query(
          'inventory_locations',
          where: 'id = ?',
          whereArgs: ['non-existent'],
          limit: 1,
        )).called(1);
      });
    });

    group('saveLocation', () {
      test('should save location successfully', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        final location = InventoryLocation(
          id: 'location-1',
          warehouseId: 'warehouse-1',
          locationCode: 'A-01',
          locationName: 'ロケーションA-01',
          description: 'テスト用ロケーション',
          isActive: true,
          createdAt: DateTime(2023, 1, 1),
          updatedAt: DateTime(2023, 1, 2),
        );

        when(mockDatabase.insert(
          'inventory_locations',
          any,
          conflictAlgorithm: ConflictAlgorithm.replace,
        )).thenAnswer((_) async => 1);

        // Act
        await repository.saveLocation(location);

        // Assert
        verify(mockDatabase.insert(
          'inventory_locations',
          argThat(allOf([
            containsPair('id', 'location-1'),
            containsPair('warehouse_id', 'warehouse-1'),
            containsPair('location_code', 'A-01'),
            containsPair('location_name', 'ロケーションA-01'),
            containsPair('description', 'テスト用ロケーション'),
            containsPair('is_active', 1),
          ])),
          conflictAlgorithm: ConflictAlgorithm.replace,
        )).called(1);
      });
    });

    group('deleteLocation', () {
      test('should delete location successfully', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.delete(
          'inventory_locations',
          where: 'id = ?',
          whereArgs: ['location-1'],
        )).thenAnswer((_) async => 1);

        // Act
        await repository.deleteLocation('location-1');

        // Assert
        verify(mockDatabase.delete(
          'inventory_locations',
          where: 'id = ?',
          whereArgs: ['location-1'],
        )).called(1);
      });
    });

    group('deactivateLocation', () {
      test('should deactivate location successfully', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.update(
          'inventory_locations',
          argThat(allOf([
            containsPair('is_active', 0),
            contains('updated_at'),
          ])),
          where: 'id = ?',
          whereArgs: ['location-1'],
        )).thenAnswer((_) async => 1);

        // Act
        await repository.deactivateLocation('location-1');

        // Assert
        verify(mockDatabase.update(
          'inventory_locations',
          argThat(containsPair('is_active', 0)),
          where: 'id = ?',
          whereArgs: ['location-1'],
        )).called(1);
      });
    });

    group('locationCodeExists', () {
      test('should return true when location code exists', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.query(
          'inventory_locations',
          where: 'warehouse_id = ? AND location_code = ?',
          whereArgs: ['warehouse-1', 'A-01'],
          limit: 1,
        )).thenAnswer((_) async => [
          {'id': 'existing-location'}
        ]);

        // Act
        final result = await repository.locationCodeExists('warehouse-1', 'A-01');

        // Assert
        expect(result, true);
        verify(mockDatabase.query(
          'inventory_locations',
          where: 'warehouse_id = ? AND location_code = ?',
          whereArgs: ['warehouse-1', 'A-01'],
          limit: 1,
        )).called(1);
      });

      test('should return false when location code does not exist', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.query(
          'inventory_locations',
          where: 'warehouse_id = ? AND location_code = ?',
          whereArgs: ['warehouse-1', 'NEW-CODE'],
          limit: 1,
        )).thenAnswer((_) async => []);

        // Act
        final result = await repository.locationCodeExists('warehouse-1', 'NEW-CODE');

        // Assert
        expect(result, false);
        verify(mockDatabase.query(
          'inventory_locations',
          where: 'warehouse_id = ? AND location_code = ?',
          whereArgs: ['warehouse-1', 'NEW-CODE'],
          limit: 1,
        )).called(1);
      });

      test('should exclude specified ID from check', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.query(
          'inventory_locations',
          where: 'warehouse_id = ? AND location_code = ? AND id != ?',
          whereArgs: ['warehouse-1', 'A-01', 'location-1'],
          limit: 1,
        )).thenAnswer((_) async => []);

        // Act
        final result = await repository.locationCodeExists('warehouse-1', 'A-01', excludeId: 'location-1');

        // Assert
        expect(result, false);
        verify(mockDatabase.query(
          'inventory_locations',
          where: 'warehouse_id = ? AND location_code = ? AND id != ?',
          whereArgs: ['warehouse-1', 'A-01', 'location-1'],
          limit: 1,
        )).called(1);
      });
    });

    group('createDefaultLocation', () {
      test('should return existing location when warehouse has locations', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.query(
          'inventory_locations',
          where: 'warehouse_id = ?',
          whereArgs: ['warehouse-1'],
          orderBy: 'location_code',
        )).thenAnswer((_) async => [
          {
            'id': 'existing-location',
            'warehouse_id': 'warehouse-1',
            'location_code': 'A-01',
            'location_name': '既存ロケーション',
            'is_active': 1,
            'created_at': '2023-01-01T00:00:00.000Z',
            'updated_at': '2023-01-02T00:00:00.000Z',
          }
        ]);

        // Act
        final result = await repository.createDefaultLocation('warehouse-1');

        // Assert
        expect(result.id, 'existing-location');
        expect(result.locationCode, 'A-01');
        expect(result.isActive, true);
        verifyNever(mockDatabase.insert(any, any));
      });

      test('should create default location when warehouse has no locations', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.query(
          'inventory_locations',
          where: 'warehouse_id = ?',
          whereArgs: ['warehouse-1'],
          orderBy: 'location_code',
        )).thenAnswer((_) async => []);
        when(mockDatabase.insert(
          'inventory_locations',
          any,
          conflictAlgorithm: ConflictAlgorithm.replace,
        )).thenAnswer((_) async => 1);

        // Act
        final result = await repository.createDefaultLocation('warehouse-1');

        // Assert
        expect(result.warehouseId, 'warehouse-1');
        expect(result.locationCode, 'DEFAULT');
        expect(result.locationName, 'デフォルト');
        expect(result.isActive, true);
        verify(mockDatabase.insert(
          'inventory_locations',
          argThat(allOf([
            containsPair('warehouse_id', 'warehouse-1'),
            containsPair('location_code', 'DEFAULT'),
            containsPair('location_name', 'デフォルト'),
            containsPair('is_active', 1),
          ])),
          conflictAlgorithm: ConflictAlgorithm.replace,
        )).called(1);
      });
    });
  });

  group('InventoryMovementRepository', () {
    late InventoryMovementRepository repository;
    late MockDatabaseHelper mockDb;

    setUp(() {
      mockDb = MockDatabaseHelper();
      repository = InventoryMovementRepository();
    });

    test('should create repository instance', () {
      // Assert
      expect(repository, isNotNull);
      expect(repository, isA<InventoryMovementRepository>());
    });

    group('getAllMovements', () {
      test('should return all movements', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.query(
          'inventory_movements',
          orderBy: 'movement_date DESC, created_at DESC',
        )).thenAnswer((_) async => [
          {
            'id': 'movement-1',
            'product_id': 'product-1',
            'warehouse_id': 'warehouse-1',
            'location_id': 'location-1',
            'movement_type': 'stockIn',
            'quantity': 10,
            'reference_id': 'ref-1',
            'reference_type': 'purchase',
            'notes': 'テスト入庫',
            'movement_date': '2023-01-02T00:00:00.000Z',
            'created_at': '2023-01-02T00:00:00.000Z',
            'updated_at': '2023-01-02T00:00:00.000Z',
          },
          {
            'id': 'movement-2',
            'product_id': 'product-2',
            'warehouse_id': 'warehouse-1',
            'location_id': 'location-1',
            'movement_type': 'stockOut',
            'quantity': 5,
            'reference_id': 'ref-2',
            'reference_type': 'sales',
            'notes': 'テスト出庫',
            'movement_date': '2023-01-01T00:00:00.000Z',
            'created_at': '2023-01-01T00:00:00.000Z',
            'updated_at': '2023-01-01T00:00:00.000Z',
          }
        ]);

        // Act
        final result = await repository.getAllMovements();

        // Assert
        expect(result.length, 2);
        expect(result[0].id, 'movement-1');
        expect(result[0].movementType, InventoryMovementType.stockIn);
        expect(result[1].id, 'movement-2');
        expect(result[1].movementType, InventoryMovementType.stockOut);
        // Should be ordered by date descending
        expect(result[0].movementDate.isAfter(result[1].movementDate), true);
        verify(mockDatabase.query(
          'inventory_movements',
          orderBy: 'movement_date DESC, created_at DESC',
        )).called(1);
      });
    });

    group('getMovementsByProduct', () {
      test('should return movements for specific product', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.query(
          'inventory_movements',
          where: 'product_id = ?',
          whereArgs: ['product-1'],
          orderBy: 'movement_date DESC, created_at DESC',
        )).thenAnswer((_) async => [
          {
            'id': 'movement-1',
            'product_id': 'product-1',
            'warehouse_id': 'warehouse-1',
            'movement_type': 'stockIn',
            'quantity': 10,
            'movement_date': '2023-01-02T00:00:00.000Z',
            'created_at': '2023-01-02T00:00:00.000Z',
            'updated_at': '2023-01-02T00:00:00.000Z',
          }
        ]);

        // Act
        final result = await repository.getMovementsByProduct('product-1');

        // Assert
        expect(result.length, 1);
        expect(result[0].productId, 'product-1');
        expect(result[0].quantity, 10);
        verify(mockDatabase.query(
          'inventory_movements',
          where: 'product_id = ?',
          whereArgs: ['product-1'],
          orderBy: 'movement_date DESC, created_at DESC',
        )).called(1);
      });
    });

    group('recordMovement', () {
      test('should record movement successfully', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        final movement = InventoryMovement(
          id: 'movement-1',
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
          updatedAt: DateTime(2023, 1, 1),
        );

        when(mockDatabase.insert(
          'inventory_movements',
          any,
          conflictAlgorithm: ConflictAlgorithm.replace,
        )).thenAnswer((_) async => 1);

        // Act
        await repository.recordMovement(movement);

        // Assert
        verify(mockDatabase.insert(
          'inventory_movements',
          argThat(allOf([
            containsPair('id', 'movement-1'),
            containsPair('product_id', 'product-1'),
            containsPair('warehouse_id', 'warehouse-1'),
            containsPair('movement_type', 'stockIn'),
            containsPair('quantity', 10),
          ])),
          conflictAlgorithm: ConflictAlgorithm.replace,
        )).called(1);
      });
    });

    group('recordStockIn', () {
      test('should record stock in movement', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.insert(
          'inventory_movements',
          any,
          conflictAlgorithm: ConflictAlgorithm.replace,
        )).thenAnswer((_) async => 1);

        // Act
        await repository.recordStockIn(
          productId: 'product-1',
          warehouseId: 'warehouse-1',
          locationId: 'location-1',
          quantity: 10,
          referenceId: 'purchase-1',
          referenceType: 'purchase',
          notes: '入庫記録',
        );

        // Assert
        verify(mockDatabase.insert(
          'inventory_movements',
          argThat(allOf([
            containsPair('product_id', 'product-1'),
            containsPair('warehouse_id', 'warehouse-1'),
            containsPair('location_id', 'location-1'),
            containsPair('movement_type', 'stockIn'),
            containsPair('quantity', 10),
            containsPair('reference_id', 'purchase-1'),
            containsPair('reference_type', 'purchase'),
            containsPair('notes', '入庫記録'),
          ])),
          conflictAlgorithm: ConflictAlgorithm.replace,
        )).called(1);
      });
    });

    group('recordStockOut', () {
      test('should record stock out movement', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.insert(
          'inventory_movements',
          any,
          conflictAlgorithm: ConflictAlgorithm.replace,
        )).thenAnswer((_) async => 1);

        // Act
        await repository.recordStockOut(
          productId: 'product-1',
          warehouseId: 'warehouse-1',
          locationId: 'location-1',
          quantity: 5,
          referenceId: 'sales-1',
          referenceType: 'sales',
          notes: '出庫記録',
        );

        // Assert
        verify(mockDatabase.insert(
          'inventory_movements',
          argThat(allOf([
            containsPair('product_id', 'product-1'),
            containsPair('warehouse_id', 'warehouse-1'),
            containsPair('location_id', 'location-1'),
            containsPair('movement_type', 'stockOut'),
            containsPair('quantity', 5),
            containsPair('reference_id', 'sales-1'),
            containsPair('reference_type', 'sales'),
            containsPair('notes', '出庫記録'),
          ])),
          conflictAlgorithm: ConflictAlgorithm.replace,
        )).called(1);
      });
    });

    group('recordStocktake', () {
      test('should record stocktake movement', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.insert(
          'inventory_movements',
          any,
          conflictAlgorithm: ConflictAlgorithm.replace,
        )).thenAnswer((_) async => 1);

        // Act
        await repository.recordStocktake(
          productId: 'product-1',
          warehouseId: 'warehouse-1',
          locationId: 'location-1',
          countedQuantity: 15,
          notes: '棚卸記録',
        );

        // Assert
        verify(mockDatabase.insert(
          'inventory_movements',
          argThat(allOf([
            containsPair('product_id', 'product-1'),
            containsPair('warehouse_id', 'warehouse-1'),
            containsPair('location_id', 'location-1'),
            containsPair('movement_type', 'stocktake'),
            containsPair('quantity', 15),
            containsPair('notes', '棚卸記録'),
          ])),
          conflictAlgorithm: ConflictAlgorithm.replace,
        )).called(1);
      });
    });

    group('deleteMovement', () {
      test('should delete movement successfully', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.delete(
          'inventory_movements',
          where: 'id = ?',
          whereArgs: ['movement-1'],
        )).thenAnswer((_) async => 1);

        // Act
        await repository.deleteMovement('movement-1');

        // Assert
        verify(mockDatabase.delete(
          'inventory_movements',
          where: 'id = ?',
          whereArgs: ['movement-1'],
        )).called(1);
      });
    });

    group('getMovementStats', () {
      test('should return movement statistics', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.rawQuery('''
          SELECT 
            movement_type,
            COUNT(*) as count,
            SUM(quantity) as total_quantity
          FROM inventory_movements
          WHERE 1=1
          GROUP BY movement_type
        ''')).thenAnswer((_) async => [
          {
            'movement_type': 'stockIn',
            'count': 3,
            'total_quantity': 30,
          },
          {
            'movement_type': 'stockOut',
            'count': 2,
            'total_quantity': 15,
          }
        ]);

        // Act
        final result = await repository.getMovementStats();

        // Assert
        expect(result['stockIn']['count'], 3);
        expect(result['stockIn']['total_quantity'], 30);
        expect(result['stockOut']['count'], 2);
        expect(result['stockOut']['total_quantity'], 15);
        verify(mockDatabase.rawQuery(any)).called(1);
      });

      test('should filter stats by warehouse', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.rawQuery('''
          SELECT 
            movement_type,
            COUNT(*) as count,
            SUM(quantity) as total_quantity
          FROM inventory_movements
          WHERE warehouse_id = ?
          GROUP BY movement_type
        ''', ['warehouse-1'])).thenAnswer((_) async => [
          {
            'movement_type': 'stockIn',
            'count': 2,
            'total_quantity': 20,
          }
        ]);

        // Act
        final result = await repository.getMovementStats(warehouseId: 'warehouse-1');

        // Assert
        expect(result['stockIn']['count'], 2);
        expect(result['stockIn']['total_quantity'], 20);
        expect(result.containsKey('stockOut'), false);
        verify(mockDatabase.rawQuery(any, ['warehouse-1'])).called(1);
      });
    });
  });
}
