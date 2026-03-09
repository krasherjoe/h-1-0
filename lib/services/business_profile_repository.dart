import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../models/business_profile_model.dart';
import 'database_helper.dart';

/// BusinessProfileリポジトリ
class BusinessProfileRepository {
  final DatabaseHelper _db = DatabaseHelper();

  /// 現在のプロファイルを取得
  Future<BusinessProfile> getCurrentProfile() async {
    final database = await _db.database;
    final maps = await database.query(
      'business_profiles',
      orderBy: 'updated_at DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return BusinessProfile.fromMap(maps.first);
    }

    // デフォルトプロファイルを返す
    return BusinessProfile.defaultProfile();
  }

  /// プロファイルを保存
  Future<void> saveProfile(BusinessProfile profile) async {
    final database = await _db.database;
    final now = DateTime.now();
    final updatedProfile = profile.copyWith(updatedAt: now);

    await database.insert(
      'business_profiles',
      updatedProfile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// すべてのプロファイルを取得
  Future<List<BusinessProfile>> getAllProfiles() async {
    final database = await _db.database;
    final maps = await database.query(
      'business_profiles',
      orderBy: 'updated_at DESC',
    );

    return maps.map((map) => BusinessProfile.fromMap(map)).toList();
  }

  /// IDでプロファイルを取得
  Future<BusinessProfile?> getProfile(String id) async {
    final database = await _db.database;
    final maps = await database.query(
      'business_profiles',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return BusinessProfile.fromMap(maps.first);
  }

  /// プロファイルを削除
  Future<void> deleteProfile(String id) async {
    final database = await _db.database;
    await database.delete(
      'business_profiles',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// プロファイルが存在するか確認
  Future<bool> profileExists() async {
    final database = await _db.database;
    final result = await database.rawQuery(
      'SELECT COUNT(*) as count FROM business_profiles',
    );
    final count = Sqflite.firstIntValue(result) ?? 0;
    return count > 0;
  }

  /// 業種別のデフォルト設定を取得
  BusinessProfile getDefaultForBusinessType(BusinessType businessType) {
    final now = DateTime.now();
    switch (businessType) {
      case BusinessType.retail:
        return BusinessProfile(
          id: 'retail_default',
          businessType: BusinessType.retail,
          productUnits: const ['個', '式', 'セット'],
          needsInventory: true,
          needsGPS: false,
          needsPhotos: false,
          workflow: WorkflowType.both,
          pricing: PricingType.standard,
          createdAt: now,
          updatedAt: now,
        );
      case BusinessType.service:
        return BusinessProfile(
          id: 'service_default',
          businessType: BusinessType.service,
          productUnits: const ['件', '式', '時間'],
          needsInventory: false,
          needsGPS: true,
          needsPhotos: false,
          workflow: WorkflowType.service,
          pricing: PricingType.custom,
          createdAt: now,
          updatedAt: now,
        );
      case BusinessType.manufacturing:
        return BusinessProfile(
          id: 'manufacturing_default',
          businessType: BusinessType.manufacturing,
          productUnits: const ['個', 'kg', 'L', 'm', '式'],
          needsInventory: true,
          needsGPS: false,
          needsPhotos: true,
          workflow: WorkflowType.both,
          pricing: PricingType.tiered,
          createdAt: now,
          updatedAt: now,
        );
      case BusinessType.wholesale:
        return BusinessProfile(
          id: 'wholesale_default',
          businessType: BusinessType.wholesale,
          productUnits: const ['箱', 'ケース', '個', 'kg'],
          needsInventory: true,
          needsGPS: false,
          needsPhotos: false,
          workflow: WorkflowType.purchase,
          pricing: PricingType.tiered,
          createdAt: now,
          updatedAt: now,
        );
      case BusinessType.restaurant:
        return BusinessProfile(
          id: 'restaurant_default',
          businessType: BusinessType.restaurant,
          productUnits: const ['個', '皿', '杯', 'g'],
          needsInventory: true,
          needsGPS: false,
          needsPhotos: false,
          workflow: WorkflowType.sales,
          pricing: PricingType.standard,
          createdAt: now,
          updatedAt: now,
        );
      case BusinessType.construction:
        return BusinessProfile(
          id: 'construction_default',
          businessType: BusinessType.construction,
          productUnits: const ['式', 'm', 'm2', 'm3', '箇所'],
          needsInventory: true,
          needsGPS: true,
          needsPhotos: true,
          workflow: WorkflowType.both,
          pricing: PricingType.custom,
          createdAt: now,
          updatedAt: now,
        );
      case BusinessType.other:
        return BusinessProfile(
          id: 'other_default',
          businessType: BusinessType.other,
          productUnits: const ['個', '式'],
          needsInventory: true,
          needsGPS: false,
          needsPhotos: false,
          workflow: WorkflowType.both,
          pricing: PricingType.standard,
          createdAt: now,
          updatedAt: now,
        );
    }
  }

  /// プロファイルを初期化（初回起動時）
  Future<void> initializeProfile() async {
    final exists = await profileExists();
    if (!exists) {
      final defaultProfile = BusinessProfile.defaultProfile();
      await saveProfile(defaultProfile);
    }
  }

  /// プロファイル統計情報を取得
  Future<Map<String, dynamic>> getProfileStats() async {
    final database = await _db.database;
    final result = await database.rawQuery('''
      SELECT 
        business_type,
        COUNT(*) as count,
        MAX(updated_at) as last_updated
      FROM business_profiles
      GROUP BY business_type
    ''');

    final stats = <String, dynamic>{};
    for (final row in result) {
      stats[row['business_type'] as String] = {
        'count': row['count'] as int,
        'last_updated': row['last_updated'] as String,
      };
    }

    return stats;
  }

  /// 古いプロファイルをクリーンアップ（最新の5件を残す）
  Future<void> cleanupOldProfiles() async {
    final allProfiles = await getAllProfiles();
    
    if (allProfiles.length <= 5) return;

    final profilesToDelete = allProfiles.skip(5);
    for (final profile in profilesToDelete) {
      await deleteProfile(profile.id);
    }
  }
}
