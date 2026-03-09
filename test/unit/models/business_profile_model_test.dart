import 'package:flutter_test/flutter_test.dart';
import '../../../lib/models/business_profile_model.dart';

void main() {
  group('BusinessProfile', () {
    test('should create default profile correctly', () {
      // Act
      final profile = BusinessProfile.defaultProfile();

      // Assert
      expect(profile.businessType, BusinessType.retail);
      expect(profile.productUnits, ['個', '式']);
      expect(profile.needsInventory, true);
      expect(profile.needsGPS, false);
      expect(profile.needsPhotos, false);
      expect(profile.workflow, WorkflowType.both);
      expect(profile.pricing, PricingType.standard);
      expect(profile.id, isNotEmpty);
      expect(profile.createdAt, isNotNull);
      expect(profile.updatedAt, isNotNull);
    });

    test('should convert to map correctly', () {
      // Arrange
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

      // Act
      final map = profile.toMap();

      // Assert
      expect(map['id'], 'test-id');
      expect(map['business_type'], 'service');
      expect(map['product_units'], '件,時間');
      expect(map['needs_inventory'], 0);
      expect(map['needs_gps'], 1);
      expect(map['needs_photos'], 0);
      expect(map['workflow'], 'service');
      expect(map['pricing'], 'custom');
      expect(map['created_at'], '2023-01-01T00:00:00.000');
      expect(map['updated_at'], '2023-01-02T00:00:00.000');
    });

    test('should create from map correctly', () {
      // Arrange
      final map = {
        'id': 'test-id',
        'business_type': 'manufacturing',
        'product_units': 'kg,個,m',
        'needs_inventory': 1,
        'needs_gps': 0,
        'needs_photos': 1,
        'workflow': 'both',
        'pricing': 'tiered',
        'created_at': '2023-01-01T00:00:00.000',
        'updated_at': '2023-01-02T00:00:00.000',
      };

      // Act
      final profile = BusinessProfile.fromMap(map);

      // Assert
      expect(profile.id, 'test-id');
      expect(profile.businessType, BusinessType.manufacturing);
      expect(profile.productUnits, ['kg', '個', 'm']);
      expect(profile.needsInventory, true);
      expect(profile.needsGPS, false);
      expect(profile.needsPhotos, true);
      expect(profile.workflow, WorkflowType.both);
      expect(profile.pricing, PricingType.tiered);
      expect(profile.createdAt, DateTime(2023, 1, 1));
      expect(profile.updatedAt, DateTime(2023, 1, 2));
    });

    test('should handle copyWith correctly', () {
      // Arrange
      final original = BusinessProfile.defaultProfile();
      final newTime = DateTime(2023, 12, 31);

      // Act
      final updated = original.copyWith(
        businessType: BusinessType.restaurant,
        needsGPS: true,
        updatedAt: newTime,
      );

      // Assert
      expect(updated.id, original.id);
      expect(updated.businessType, BusinessType.restaurant);
      expect(updated.productUnits, original.productUnits);
      expect(updated.needsInventory, original.needsInventory);
      expect(updated.needsGPS, true);
      expect(updated.needsPhotos, original.needsPhotos);
      expect(updated.workflow, original.workflow);
      expect(updated.pricing, original.pricing);
      expect(updated.createdAt, original.createdAt);
      expect(updated.updatedAt, newTime);
    });

    test('should handle business type names correctly', () {
      // Test all business types
      expect(BusinessType.retail.name, 'retail');
      expect(BusinessType.service.name, 'service');
      expect(BusinessType.manufacturing.name, 'manufacturing');
      expect(BusinessType.wholesale.name, 'wholesale');
      expect(BusinessType.restaurant.name, 'restaurant');
      expect(BusinessType.construction.name, 'construction');
      expect(BusinessType.other.name, 'other');
    });

    test('should handle workflow type names correctly', () {
      // Test all workflow types
      expect(WorkflowType.sales.name, 'sales');
      expect(WorkflowType.purchase.name, 'purchase');
      expect(WorkflowType.both.name, 'both');
      expect(WorkflowType.service.name, 'service');
    });

    test('should handle pricing type names correctly', () {
      // Test all pricing types
      expect(PricingType.standard.name, 'standard');
      expect(PricingType.tiered.name, 'tiered');
      expect(PricingType.custom.name, 'custom');
    });

    test('should handle empty product units string', () {
      // Arrange
      final map = {
        'id': 'test-id',
        'business_type': 'retail',
        'product_units': '',
        'needs_inventory': 1,
        'needs_gps': 0,
        'needs_photos': 0,
        'workflow': 'both',
        'pricing': 'standard',
        'created_at': '2023-01-01T00:00:00.000',
        'updated_at': '2023-01-02T00:00:00.000',
      };

      // Act
      final profile = BusinessProfile.fromMap(map);

      // Assert
      expect(profile.productUnits, ['']); // Should preserve empty string
    });

    test('should handle single product unit', () {
      // Arrange
      final map = {
        'id': 'test-id',
        'business_type': 'retail',
        'product_units': '個',
        'needs_inventory': 1,
        'needs_gps': 0,
        'needs_photos': 0,
        'workflow': 'both',
        'pricing': 'standard',
        'created_at': '2023-01-01T00:00:00.000Z',
        'updated_at': '2023-01-02T00:00:00.000Z',
      };

      // Act
      final profile = BusinessProfile.fromMap(map);

      // Assert
      expect(profile.productUnits, ['個']);
    });

    test('should handle boolean conversion correctly', () {
      // Test various boolean values
      expect(BusinessProfile.fromMap({
        'id': 'test1',
        'business_type': 'retail',
        'product_units': '個',
        'needs_inventory': 1,
        'needs_gps': 0,
        'needs_photos': 1,
        'workflow': 'both',
        'pricing': 'standard',
        'created_at': '2023-01-01T00:00:00.000Z',
        'updated_at': '2023-01-02T00:00:00.000Z',
      }).needsInventory, true);

      expect(BusinessProfile.fromMap({
        'id': 'test2',
        'business_type': 'retail',
        'product_units': '個',
        'needs_inventory': 0,
        'needs_gps': 1,
        'needs_photos': 0,
        'workflow': 'both',
        'pricing': 'standard',
        'created_at': '2023-01-01T00:00:00.000Z',
        'updated_at': '2023-01-02T00:00:00.000Z',
      }).needsInventory, false);
    });

    test('should handle equality correctly', () {
      // Arrange
      final profile1 = BusinessProfile(
        id: 'same-id',
        businessType: BusinessType.retail,
        productUnits: ['個'],
        needsInventory: true,
        needsGPS: false,
        needsPhotos: false,
        workflow: WorkflowType.both,
        pricing: PricingType.standard,
        createdAt: DateTime(2023, 1, 1),
        updatedAt: DateTime(2023, 1, 2),
      );

      final profile2 = BusinessProfile(
        id: 'same-id',
        businessType: BusinessType.retail,
        productUnits: ['個'],
        needsInventory: true,
        needsGPS: false,
        needsPhotos: false,
        workflow: WorkflowType.both,
        pricing: PricingType.standard,
        createdAt: DateTime(2023, 1, 1),
        updatedAt: DateTime(2023, 1, 2),
      );

      final profile3 = BusinessProfile(
        id: 'different-id',
        businessType: BusinessType.service,
        productUnits: ['件'],
        needsInventory: false,
        needsGPS: true,
        needsPhotos: false,
        workflow: WorkflowType.service,
        pricing: PricingType.custom,
        createdAt: DateTime(2023, 1, 1),
        updatedAt: DateTime(2023, 1, 2),
      );

      // Assert
      expect(profile1, equals(profile2));
      expect(profile1, isNot(equals(profile3)));
    });

    test('should have correct string representation', () {
      // Arrange
      final profile = BusinessProfile(
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

      // Act
      final stringRepresentation = profile.toString();

      // Assert
      expect(stringRepresentation, contains('BusinessProfile'));
      expect(stringRepresentation, contains('test-id'));
      expect(stringRepresentation, contains('retail'));
    });
  });
}
