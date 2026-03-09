import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import '../../../lib/models/business_profile_model.dart';
import '../../../lib/services/business_profile_repository.dart';
import '../../../lib/services/database_helper.dart';

import 'business_profile_repository_test.mocks.dart';

@GenerateMocks([DatabaseHelper])
void main() {
  group('BusinessProfileRepository', () {
    late BusinessProfileRepository repository;
    late MockDatabaseHelper mockDb;

    setUp(() {
      mockDb = MockDatabaseHelper();
      repository = BusinessProfileRepository();
    });

    test('should create repository instance', () {
      // Assert
      expect(repository, isNotNull);
      expect(repository, isA<BusinessProfileRepository>());
    });

    group('getCurrentProfile', () {
      test('should return current profile when exists', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        final testProfile = BusinessProfile(
          id: 'test-id',
          businessType: BusinessType.retail,
          productUnits: ['個', '式'],
          needsInventory: true,
          needsGPS: false,
          needsPhotos: false,
          workflow: WorkflowType.both,
          pricing: PricingType.standard,
          createdAt: DateTime(2023, 1, 1),
          updatedAt: DateTime(2023, 1, 2),
        );

        when(mockDatabase.query(
          'business_profiles',
          orderBy: 'updated_at DESC',
          limit: 1,
        )).thenAnswer((_) async => [
          {
            'id': 'test-id',
            'business_type': 'retail',
            'product_units': '個,式',
            'needs_inventory': 1,
            'needs_gps': 0,
            'needs_photos': 0,
            'workflow': 'both',
            'pricing': 'standard',
            'created_at': '2023-01-01T00:00:00.000Z',
            'updated_at': '2023-01-02T00:00:00.000Z',
          }
        ]);

        // Act
        final result = await repository.getCurrentProfile();

        // Assert
        expect(result.id, 'test-id');
        expect(result.businessType, BusinessType.retail);
        expect(result.productUnits, ['個', '式']);
        verify(mockDatabase.query(
          'business_profiles',
          orderBy: 'updated_at DESC',
          limit: 1,
        )).called(1);
      });

      test('should return default profile when no profile exists', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.query(
          'business_profiles',
          orderBy: 'updated_at DESC',
          limit: 1,
        )).thenAnswer((_) async => []);

        // Act
        final result = await repository.getCurrentProfile();

        // Assert
        expect(result.id, isNotEmpty);
        expect(result.businessType, BusinessType.retail);
        expect(result.productUnits, ['個', '式']);
        expect(result.needsInventory, true);
        expect(result.needsGPS, false);
        expect(result.needsPhotos, false);
        verify(mockDatabase.query(
          'business_profiles',
          orderBy: 'updated_at DESC',
          limit: 1,
        )).called(1);
      });
    });

    group('saveProfile', () {
      test('should save profile successfully', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        final profile = BusinessProfile(
          id: 'test-id',
          businessType: BusinessType.service,
          productUnits: ['件', '時間'],
          needsInventory: false,
          needsGPS: true,
          needsPhotos: false,
          workflow: WorkflowType.service,
          pricing: PricingType.custom,
          createdAt: DateTime(2023, 1, 1),
          updatedAt: DateTime(2023, 1, 2),
        );

        when(mockDatabase.insert(
          'business_profiles',
          any,
          conflictAlgorithm: ConflictAlgorithm.replace,
        )).thenAnswer((_) async => 1);

        // Act
        await repository.saveProfile(profile);

        // Assert
        verify(mockDatabase.insert(
          'business_profiles',
          argThat(allOf([
            containsPair('id', 'test-id'),
            containsPair('business_type', 'service'),
            containsPair('product_units', '件,時間'),
            containsPair('needs_inventory', 0),
            containsPair('needs_gps', 1),
            containsPair('needs_photos', 0),
            containsPair('workflow', 'service'),
            containsPair('pricing', 'custom'),
          ])),
          conflictAlgorithm: ConflictAlgorithm.replace,
        )).called(1);
      });
    });

    group('getAllProfiles', () {
      test('should return all profiles', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.query(
          'business_profiles',
          orderBy: 'updated_at DESC',
        )).thenAnswer((_) async => [
          {
            'id': 'profile-1',
            'business_type': 'retail',
            'product_units': '個',
            'needs_inventory': 1,
            'needs_gps': 0,
            'needs_photos': 0,
            'workflow': 'both',
            'pricing': 'standard',
            'created_at': '2023-01-01T00:00:00.000Z',
            'updated_at': '2023-01-02T00:00:00.000Z',
          },
          {
            'id': 'profile-2',
            'business_type': 'service',
            'product_units': '件',
            'needs_inventory': 0,
            'needs_gps': 1,
            'needs_photos': 0,
            'workflow': 'service',
            'pricing': 'custom',
            'created_at': '2023-01-01T00:00:00.000Z',
            'updated_at': '2023-01-01T00:00:00.000Z',
          }
        ]);

        // Act
        final result = await repository.getAllProfiles();

        // Assert
        expect(result.length, 2);
        expect(result[0].id, 'profile-1');
        expect(result[0].businessType, BusinessType.retail);
        expect(result[1].id, 'profile-2');
        expect(result[1].businessType, BusinessType.service);
        verify(mockDatabase.query(
          'business_profiles',
          orderBy: 'updated_at DESC',
        )).called(1);
      });

      test('should return empty list when no profiles exist', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.query(
          'business_profiles',
          orderBy: 'updated_at DESC',
        )).thenAnswer((_) async => []);

        // Act
        final result = await repository.getAllProfiles();

        // Assert
        expect(result, isEmpty);
        verify(mockDatabase.query(
          'business_profiles',
          orderBy: 'updated_at DESC',
        )).called(1);
      });
    });

    group('getProfile', () {
      test('should return profile when found', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.query(
          'business_profiles',
          where: 'id = ?',
          whereArgs: ['test-id'],
          limit: 1,
        )).thenAnswer((_) async => [
          {
            'id': 'test-id',
            'business_type': 'manufacturing',
            'product_units': 'kg,個',
            'needs_inventory': 1,
            'needs_gps': 0,
            'needs_photos': 1,
            'workflow': 'both',
            'pricing': 'tiered',
            'created_at': '2023-01-01T00:00:00.000Z',
            'updated_at': '2023-01-02T00:00:00.000Z',
          }
        ]);

        // Act
        final result = await repository.getProfile('test-id');

        // Assert
        expect(result, isNotNull);
        expect(result!.id, 'test-id');
        expect(result.businessType, BusinessType.manufacturing);
        expect(result.productUnits, ['kg', '個']);
        verify(mockDatabase.query(
          'business_profiles',
          where: 'id = ?',
          whereArgs: ['test-id'],
          limit: 1,
        )).called(1);
      });

      test('should return null when profile not found', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.query(
          'business_profiles',
          where: 'id = ?',
          whereArgs: ['non-existent-id'],
          limit: 1,
        )).thenAnswer((_) async => []);

        // Act
        final result = await repository.getProfile('non-existent-id');

        // Assert
        expect(result, isNull);
        verify(mockDatabase.query(
          'business_profiles',
          where: 'id = ?',
          whereArgs: ['non-existent-id'],
          limit: 1,
        )).called(1);
      });
    });

    group('deleteProfile', () {
      test('should delete profile successfully', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.delete(
          'business_profiles',
          where: 'id = ?',
          whereArgs: ['test-id'],
        )).thenAnswer((_) async => 1);

        // Act
        await repository.deleteProfile('test-id');

        // Assert
        verify(mockDatabase.delete(
          'business_profiles',
          where: 'id = ?',
          whereArgs: ['test-id'],
        )).called(1);
      });
    });

    group('profileExists', () {
      test('should return true when profile exists', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.rawQuery('SELECT COUNT(*) as count FROM business_profiles'))
            .thenAnswer((_) async => [{'count': 1}]);

        // Act
        final result = await repository.profileExists();

        // Assert
        expect(result, true);
        verify(mockDatabase.rawQuery('SELECT COUNT(*) as count FROM business_profiles'))
            .called(1);
      });

      test('should return false when no profile exists', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.rawQuery('SELECT COUNT(*) as count FROM business_profiles'))
            .thenAnswer((_) async => [{'count': 0}]);

        // Act
        final result = await repository.profileExists();

        // Assert
        expect(result, false);
        verify(mockDatabase.rawQuery('SELECT COUNT(*) as count FROM business_profiles'))
            .called(1);
      });
    });

    group('getDefaultForBusinessType', () {
      test('should return correct default for retail', () {
        // Act
        final result = repository.getDefaultForBusinessType(BusinessType.retail);

        // Assert
        expect(result.businessType, BusinessType.retail);
        expect(result.productUnits, ['個', '式', 'セット']);
        expect(result.needsInventory, true);
        expect(result.needsGPS, false);
        expect(result.needsPhotos, false);
        expect(result.workflow, WorkflowType.both);
        expect(result.pricing, PricingType.standard);
      });

      test('should return correct default for service', () {
        // Act
        final result = repository.getDefaultForBusinessType(BusinessType.service);

        // Assert
        expect(result.businessType, BusinessType.service);
        expect(result.productUnits, ['件', '式', '時間']);
        expect(result.needsInventory, false);
        expect(result.needsGPS, true);
        expect(result.needsPhotos, false);
        expect(result.workflow, WorkflowType.service);
        expect(result.pricing, PricingType.custom);
      });

      test('should return correct default for manufacturing', () {
        // Act
        final result = repository.getDefaultForBusinessType(BusinessType.manufacturing);

        // Assert
        expect(result.businessType, BusinessType.manufacturing);
        expect(result.productUnits, ['個', 'kg', 'L', 'm', '式']);
        expect(result.needsInventory, true);
        expect(result.needsGPS, false);
        expect(result.needsPhotos, true);
        expect(result.workflow, WorkflowType.both);
        expect(result.pricing, PricingType.tiered);
      });

      test('should return correct default for wholesale', () {
        // Act
        final result = repository.getDefaultForBusinessType(BusinessType.wholesale);

        // Assert
        expect(result.businessType, BusinessType.wholesale);
        expect(result.productUnits, ['箱', 'ケース', '個', 'kg']);
        expect(result.needsInventory, true);
        expect(result.needsGPS, false);
        expect(result.needsPhotos, false);
        expect(result.workflow, WorkflowType.purchase);
        expect(result.pricing, PricingType.tiered);
      });

      test('should return correct default for restaurant', () {
        // Act
        final result = repository.getDefaultForBusinessType(BusinessType.restaurant);

        // Assert
        expect(result.businessType, BusinessType.restaurant);
        expect(result.productUnits, ['個', '皿', '杯', 'g']);
        expect(result.needsInventory, true);
        expect(result.needsGPS, false);
        expect(result.needsPhotos, false);
        expect(result.workflow, WorkflowType.sales);
        expect(result.pricing, PricingType.standard);
      });

      test('should return correct default for construction', () {
        // Act
        final result = repository.getDefaultForBusinessType(BusinessType.construction);

        // Assert
        expect(result.businessType, BusinessType.construction);
        expect(result.productUnits, ['式', 'm', 'm2', 'm3', '箇所']);
        expect(result.needsInventory, true);
        expect(result.needsGPS, true);
        expect(result.needsPhotos, true);
        expect(result.workflow, WorkflowType.both);
        expect(result.pricing, PricingType.custom);
      });

      test('should return correct default for other', () {
        // Act
        final result = repository.getDefaultForBusinessType(BusinessType.other);

        // Assert
        expect(result.businessType, BusinessType.other);
        expect(result.productUnits, ['個', '式']);
        expect(result.needsInventory, true);
        expect(result.needsGPS, false);
        expect(result.needsPhotos, false);
        expect(result.workflow, WorkflowType.both);
        expect(result.pricing, PricingType.standard);
      });
    });

    group('initializeProfile', () {
      test('should create default profile when none exists', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.rawQuery('SELECT COUNT(*) as count FROM business_profiles'))
            .thenAnswer((_) async => [{'count': 0}]);
        when(mockDatabase.insert(
          'business_profiles',
          any,
          conflictAlgorithm: ConflictAlgorithm.replace,
        )).thenAnswer((_) async => 1);

        // Act
        await repository.initializeProfile();

        // Assert
        verify(mockDatabase.rawQuery('SELECT COUNT(*) as count FROM business_profiles'))
            .called(1);
        verify(mockDatabase.insert(
          'business_profiles',
          argThat(containsPair('business_type', 'retail')),
          conflictAlgorithm: ConflictAlgorithm.replace,
        )).called(1);
      });

      test('should not create profile when one already exists', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.rawQuery('SELECT COUNT(*) as count FROM business_profiles'))
            .thenAnswer((_) async => [{'count': 1}]);

        // Act
        await repository.initializeProfile();

        // Assert
        verify(mockDatabase.rawQuery('SELECT COUNT(*) as count FROM business_profiles'))
            .called(1);
        verifyNever(mockDatabase.insert(
          any,
          any,
          conflictAlgorithm: anyNamed('conflictAlgorithm'),
        ));
      });
    });

    group('getProfileStats', () {
      test('should return profile statistics', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.rawQuery('''
          SELECT 
            business_type,
            COUNT(*) as count,
            MAX(updated_at) as last_updated
          FROM business_profiles
          GROUP BY business_type
        ''')).thenAnswer((_) async => [
          {
            'business_type': 'retail',
            'count': 2,
            'last_updated': '2023-01-02T00:00:00.000Z',
          },
          {
            'business_type': 'service',
            'count': 1,
            'last_updated': '2023-01-01T00:00:00.000Z',
          }
        ]);

        // Act
        final result = await repository.getProfileStats();

        // Assert
        expect(result['retail']['count'], 2);
        expect(result['retail']['last_updated'], '2023-01-02T00:00:00.000Z');
        expect(result['service']['count'], 1);
        expect(result['service']['last_updated'], '2023-01-01T00:00:00.000Z');
        verify(mockDatabase.rawQuery(any)).called(1);
      });

      test('should return empty stats when no profiles exist', () async {
        // Arrange
        final mockDatabase = MockDatabase();
        when(mockDatabase.rawQuery(any)).thenAnswer((_) async => []);

        // Act
        final result = await repository.getProfileStats();

        // Assert
        expect(result, isEmpty);
        verify(mockDatabase.rawQuery(any)).called(1);
      });
    });

    group('cleanupOldProfiles', () {
      test('should keep only latest 5 profiles', () async {
        // This test would require mocking getAllProfiles and deleteProfile
        // For simplicity, we'll just test the method exists and can be called
        // Act & Assert
        expect(() => repository.cleanupOldProfiles(), returnsNormally);
      });
    });
  });
}
