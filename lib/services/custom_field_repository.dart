import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../models/custom_field_model.dart';
import '../models/business_profile_model.dart';
import 'database_helper.dart';

/// カスタムフィールドリポジトリ
class CustomFieldRepository {
  final DatabaseHelper _db = DatabaseHelper();

  /// すべてのカスタムフィールドを取得
  Future<List<CustomField>> getAllFields() async {
    final database = await _db.database;
    final maps = await database.query(
      'custom_fields',
      orderBy: 'display_order ASC, created_at ASC',
    );
    return maps.map((map) => CustomField.fromMap(map)).toList();
  }

  /// ビジネスプロファイルIDでカスタムフィールドを取得
  Future<List<CustomField>> getFieldsByBusinessProfile(String businessProfileId) async {
    final database = await _db.database;
    final maps = await database.query(
      'custom_fields',
      where: 'business_profile_id = ?',
      whereArgs: [businessProfileId],
      orderBy: 'display_order ASC, created_at ASC',
    );
    return maps.map((map) => CustomField.fromMap(map)).toList();
  }

  /// アクティブなカスタムフィールドのみ取得
  Future<List<CustomField>> getActiveFieldsByBusinessProfile(String businessProfileId) async {
    final database = await _db.database;
    final maps = await database.query(
      'custom_fields',
      where: 'business_profile_id = ? AND is_active = ?',
      whereArgs: [businessProfileId, 1],
      orderBy: 'display_order ASC, created_at ASC',
    );
    return maps.map((map) => CustomField.fromMap(map)).toList();
  }

  /// IDでカスタムフィールドを取得
  Future<CustomField?> getField(String id) async {
    final database = await _db.database;
    final maps = await database.query(
      'custom_fields',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return CustomField.fromMap(maps.first);
    }
    return null;
  }

  /// カスタムフィールドを保存
  Future<void> saveField(CustomField field) async {
    final database = await _db.database;
    await database.insert(
      'custom_fields',
      field.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// カスタムフィールドを作成
  Future<String> createField({
    required String businessProfileId,
    required String fieldName,
    required String fieldLabel,
    required CustomFieldType fieldType,
    CustomFieldValidation? validation,
    String? description,
    String? defaultValue,
  }) async {
    final field = CustomField.create(
      businessProfileId: businessProfileId,
      fieldName: fieldName,
      fieldLabel: fieldLabel,
      fieldType: fieldType,
      validation: validation,
      description: description,
      defaultValue: defaultValue,
    );
    
    await saveField(field);
    return field.id;
  }

  /// カスタムフィールドを更新
  Future<void> updateField(CustomField field) async {
    await saveField(field.copyWith(updatedAt: DateTime.now()));
  }

  /// カスタムフィールドを削除
  Future<void> deleteField(String id) async {
    final database = await _db.database;
    await database.delete(
      'custom_fields',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// カスタムフィールドを非アクティブ化
  Future<void> deactivateField(String id) async {
    final database = await _db.database;
    await database.update(
      'custom_fields',
      {
        'is_active': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 表示順序を更新
  Future<void> updateDisplayOrder(String fieldId, int newOrder) async {
    final database = await _db.database;
    await database.update(
      'custom_fields',
      {
        'display_order': newOrder,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [fieldId],
    );
  }

  /// フィールド名が既に存在するかチェック
  Future<bool> fieldNameExists(String businessProfileId, String fieldName, {String? excludeId}) async {
    final database = await _db.database;
    
    String whereClause = 'business_profile_id = ? AND field_name = ?';
    List<dynamic> whereArgs = [businessProfileId, fieldName];
    
    if (excludeId != null) {
      whereClause += ' AND id != ?';
      whereArgs.add(excludeId);
    }
    
    final maps = await database.query(
      'custom_fields',
      where: whereClause,
      whereArgs: whereArgs,
      limit: 1,
    );
    
    return maps.isNotEmpty;
  }

  /// カスタムフィールド値を取得
  Future<List<CustomFieldValue>> getFieldValues({
    String? customFieldId,
    String? entityId,
    String? entityType,
  }) async {
    final database = await _db.database;
    
    String whereClause = '1=1';
    List<dynamic> whereArgs = [];
    
    if (customFieldId != null) {
      whereClause += ' AND custom_field_id = ?';
      whereArgs.add(customFieldId);
    }
    
    if (entityId != null) {
      whereClause += ' AND entity_id = ?';
      whereArgs.add(entityId);
    }
    
    if (entityType != null) {
      whereClause += ' AND entity_type = ?';
      whereArgs.add(entityType);
    }
    
    final maps = await database.query(
      'custom_field_values',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
    
    return maps.map((map) => CustomFieldValue.fromMap(map)).toList();
  }

  /// エンティティのすべてのカスタムフィールド値を取得
  Future<Map<String, dynamic>> getEntityFieldValues(String entityId, String entityType) async {
    final values = await getFieldValues(entityId: entityId, entityType: entityType);
    final Map<String, dynamic> result = {};
    
    for (final value in values) {
      final field = await getField(value.customFieldId);
      if (field != null) {
        result[field.fieldName] = value.value;
      }
    }
    
    return result;
  }

  /// カスタムフィールド値を保存
  Future<void> saveFieldValue(CustomFieldValue fieldValue) async {
    final database = await _db.database;
    await database.insert(
      'custom_field_values',
      fieldValue.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// カスタムフィールド値を作成または更新
  Future<void> setFieldValue({
    required String customFieldId,
    required String entityId,
    required String entityType,
    required dynamic value,
  }) async {
    final existingValues = await getFieldValues(
      customFieldId: customFieldId,
      entityId: entityId,
      entityType: entityType,
    );
    
    if (existingValues.isNotEmpty) {
      // 更新
      final existing = existingValues.first;
      await saveFieldValue(existing.copyWith(
        value: value,
        updatedAt: DateTime.now(),
      ));
    } else {
      // 新規作成
      final newValue = CustomFieldValue.create(
        customFieldId: customFieldId,
        entityId: entityId,
        entityType: entityType,
        value: value,
      );
      await saveFieldValue(newValue);
    }
  }

  /// カスタムフィールド値を削除
  Future<void> deleteFieldValue(String id) async {
    final database = await _db.database;
    await database.delete(
      'custom_field_values',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// エンティティのすべてのカスタムフィールド値を削除
  Future<void> deleteEntityFieldValues(String entityId, String entityType) async {
    final database = await _db.database;
    await database.delete(
      'custom_field_values',
      where: 'entity_id = ? AND entity_type = ?',
      whereArgs: [entityId, entityType],
    );
  }

  /// カスタムフィールドと値をまとめて削除
  Future<void> deleteFieldAndValues(String fieldId) async {
    await deleteField(fieldId);
    
    final database = await _db.database;
    await database.delete(
      'custom_field_values',
      where: 'custom_field_id = ?',
      whereArgs: [fieldId],
    );
  }

  /// 業種別の標準フィールドテンプレートを取得
  Future<List<CustomField>> getIndustryTemplateFields(BusinessType businessType) async {
    switch (businessType) {
      case BusinessType.retail:
        return _getRetailTemplateFields();
      case BusinessType.service:
        return _getServiceTemplateFields();
      case BusinessType.manufacturing:
        return _getManufacturingTemplateFields();
      case BusinessType.wholesale:
        return _getWholesaleTemplateFields();
      case BusinessType.restaurant:
        return _getRestaurantTemplateFields();
      case BusinessType.construction:
        return _getConstructionTemplateFields();
      case BusinessType.other:
        return _getOtherTemplateFields();
    }
  }

  /// 小売業種テンプレート
  List<CustomField> _getRetailTemplateFields() {
    return [
      CustomField.create(
        businessProfileId: 'template',
        fieldName: 'store_size',
        fieldLabel: '店舗面積',
        fieldType: CustomFieldType.number,
        validation: const CustomFieldValidation(min: 0),
        description: '店舗の床面積（平方メートル）',
      ),
      CustomField.create(
        businessProfileId: 'template',
        fieldName: 'customer_type',
        fieldLabel: '顧客層',
        fieldType: CustomFieldType.select,
        validation: const CustomFieldValidation(
          options: ['個人', '法人', '観光客', 'リピーター'],
        ),
        description: '主な顧客層',
      ),
      CustomField.create(
        businessProfileId: 'template',
        fieldName: 'payment_methods',
        fieldLabel: '決済方法',
        fieldType: CustomFieldType.multiselect,
        validation: const CustomFieldValidation(
          options: ['現金', 'クレジットカード', '電子マネー', 'QR決済'],
        ),
        description: '利用可能な決済方法',
      ),
    ];
  }

  /// サービス業種テンプレート
  List<CustomField> _getServiceTemplateFields() {
    return [
      CustomField.create(
        businessProfileId: 'template',
        fieldName: 'service_area',
        fieldLabel: 'サービス提供エリア',
        fieldType: CustomFieldType.text,
        validation: const CustomFieldValidation(maxLength: 200),
        description: 'サービス提供地域',
      ),
      CustomField.create(
        businessProfileId: 'template',
        fieldName: 'hourly_rate',
        fieldLabel: '時間単価',
        fieldType: CustomFieldType.currency,
        validation: const CustomFieldValidation(min: 0),
        description: '1時間あたりのサービス料金',
      ),
      CustomField.create(
        businessProfileId: 'template',
        fieldName: 'certifications',
        fieldLabel: '資格・認証',
        fieldType: CustomFieldType.textarea,
        description: '保有する資格や認証情報',
      ),
    ];
  }

  /// 製造業種テンプレート
  List<CustomField> _getManufacturingTemplateFields() {
    return [
      CustomField.create(
        businessProfileId: 'template',
        fieldName: 'production_capacity',
        fieldLabel: '生産能力',
        fieldType: CustomFieldType.text,
        validation: const CustomFieldValidation(maxLength: 100),
        description: '月間生産能力や生産形態',
      ),
      CustomField.create(
        businessProfileId: 'template',
        fieldName: 'quality_standard',
        fieldLabel: '品質管理基準',
        fieldType: CustomFieldType.select,
        validation: const CustomFieldValidation(
          options: ['ISO9001', 'JIS', '独自基準', '未設定'],
        ),
        description: '適用している品質管理基準',
      ),
      CustomField.create(
        businessProfileId: 'template',
        fieldName: 'main_materials',
        fieldLabel: '主要原材料',
        fieldType: CustomFieldType.textarea,
        description: '使用する主要原材料や部品',
      ),
    ];
  }

  /// 卸売業種テンプレート
  List<CustomField> _getWholesaleTemplateFields() {
    return [
      CustomField.create(
        businessProfileId: 'template',
        fieldName: 'min_order_amount',
        fieldLabel: '最小注文額',
        fieldType: CustomFieldType.currency,
        validation: const CustomFieldValidation(min: 0),
        description: '最小注文金額',
      ),
      CustomField.create(
        businessProfileId: 'template',
        fieldName: 'delivery_areas',
        fieldLabel: '配送エリア',
        fieldType: CustomFieldType.multiselect,
        validation: const CustomFieldValidation(
          options: ['関東', '関西', '中部', '九州', '北海道', '東北', '中国', '四国'],
        ),
        description: '配送可能なエリア',
      ),
      CustomField.create(
        businessProfileId: 'template',
        fieldName: 'payment_terms',
        fieldLabel: '支払条件',
        fieldType: CustomFieldType.select,
        validation: const CustomFieldValidation(
          options: ['現金払い', '月末払い', '翌月末払い', 'その他'],
        ),
        description: '取引先との支払条件',
      ),
    ];
  }

  /// 飲食業種テンプレート
  List<CustomField> _getRestaurantTemplateFields() {
    return [
      CustomField.create(
        businessProfileId: 'template',
        fieldName: 'seat_count',
        fieldLabel: '席数',
        fieldType: CustomFieldType.number,
        validation: const CustomFieldValidation(min: 1),
        description: '店内の総席数',
      ),
      CustomField.create(
        businessProfileId: 'template',
        fieldName: 'cuisine_type',
        fieldLabel: '料理ジャンル',
        fieldType: CustomFieldType.multiselect,
        validation: const CustomFieldValidation(
          options: ['和食', '洋食', '中華', 'イタリアン', 'フレンチ', 'その他'],
        ),
        description: '提供する料理のジャンル',
      ),
      CustomField.create(
        businessProfileId: 'template',
        fieldName: 'business_hours',
        fieldLabel: '営業時間',
        fieldType: CustomFieldType.textarea,
        description: '通常の営業時間',
      ),
      CustomField.create(
        businessProfileId: 'template',
        fieldName: 'alcohol_license',
        fieldLabel: '酒類提供',
        fieldType: CustomFieldType.checkbox,
        defaultValue: 'false',
        description: '酒類の提供有無',
      ),
    ];
  }

  /// 建設業種テンプレート
  List<CustomField> _getConstructionTemplateFields() {
    return [
      CustomField.create(
        businessProfileId: 'template',
        fieldName: 'license_class',
        fieldLabel: '建設許可等級',
        fieldType: CustomFieldType.select,
        validation: const CustomFieldValidation(
          options: ['特級', '一級', '二級', '三級'],
        ),
        description: '建設業許可の等級',
      ),
      CustomField.create(
        businessProfileId: 'template',
        fieldName: 'specialized_fields',
        fieldLabel: '専門分野',
        fieldType: CustomFieldType.multiselect,
        validation: const CustomFieldValidation(
          options: ['土木', '建築', '電気', '配管', '空調', 'その他'],
        ),
        description: '得意な専門分野',
      ),
      CustomField.create(
        businessProfileId: 'template',
        fieldName: 'project_scale',
        fieldLabel: '請負規模',
        fieldType: CustomFieldType.select,
        validation: const CustomFieldValidation(
          options: ['小規模', '中規模', '大規模'],
        ),
        description: '主な請負工事の規模',
      ),
      CustomField.create(
        businessProfileId: 'template',
        fieldName: 'insurance_coverage',
        fieldLabel: '保険加入',
        fieldType: CustomFieldType.multiselect,
        validation: const CustomFieldValidation(
          options: ['賠償責任保険', '労災保険', '自動車保険', 'その他'],
        ),
        description: '加入している保険',
      ),
    ];
  }

  /// その他業種テンプレート
  List<CustomField> _getOtherTemplateFields() {
    return [
      CustomField.create(
        businessProfileId: 'template',
        fieldName: 'business_description',
        fieldLabel: '事業内容',
        fieldType: CustomFieldType.textarea,
        validation: const CustomFieldValidation(maxLength: 500),
        description: '事業内容の詳細説明',
      ),
      CustomField.create(
        businessProfileId: 'template',
        fieldName: 'unique_features',
        fieldLabel: '特色',
        fieldType: CustomFieldType.textarea,
        validation: const CustomFieldValidation(maxLength: 300),
        description: '事業の特色や強み',
      ),
    ];
  }
}
