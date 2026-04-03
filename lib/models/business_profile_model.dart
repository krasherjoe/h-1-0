/// 業種プロファイル（Lite版）
/// 今後の業種カスタマイズ（Phase1）に向けた最小限の実装
enum BusinessType {
  retail,     // 小売
  service,    // サービス
  manufacturing, // 製造
  wholesale,  // 卸売
  restaurant, // 飲食
  construction, // 建設
  other,      // その他
}

/// 業務フロータイプ（簡易版）
enum WorkflowType {
  sales,      // 販売中心
  purchase,   // 仕入中心
  both,       // 販売・仕入両方
  service,    // サービス提供
}

/// 価格体系タイプ（簡易版）
enum PricingType {
  standard,   // 標準価格
  tiered,     // 段階価格
  custom,     // カスタム価格
}

/// 業種プロファイルモデル
class BusinessProfile {
  final String id;
  final BusinessType businessType;
  final List<String> productUnits;
  final bool needsInventory;
  final bool needsGPS;
  final bool needsPhotos;
  final WorkflowType workflow;
  final PricingType pricing;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BusinessProfile({
    required this.id,
    required this.businessType,
    this.productUnits = const ['個', '式'],
    this.needsInventory = true,
    this.needsGPS = false,
    this.needsPhotos = false,
    this.workflow = WorkflowType.both,
    this.pricing = PricingType.standard,
    required this.createdAt,
    required this.updatedAt,
  });

  /// デフォルトプロファイルを生成
  factory BusinessProfile.defaultProfile() {
    final now = DateTime.now();
    return BusinessProfile(
      id: 'default',
      businessType: BusinessType.retail,
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

  /// 業種名を取得
  String get businessTypeName {
    switch (businessType) {
      case BusinessType.retail:
        return '小売';
      case BusinessType.service:
        return 'サービス';
      case BusinessType.manufacturing:
        return '製造';
      case BusinessType.wholesale:
        return '卸売';
      case BusinessType.restaurant:
        return '飲食';
      case BusinessType.construction:
        return '建設';
      case BusinessType.other:
        return 'その他';
    }
  }

  /// 業務フロー名を取得
  String get workflowName {
    switch (workflow) {
      case WorkflowType.sales:
        return '販売中心';
      case WorkflowType.purchase:
        return '仕入中心';
      case WorkflowType.both:
        return '販売・仕入両方';
      case WorkflowType.service:
        return 'サービス提供';
    }
  }

  /// 価格体系名を取得
  String get pricingName {
    switch (pricing) {
      case PricingType.standard:
        return '標準価格';
      case PricingType.tiered:
        return '段階価格';
      case PricingType.custom:
        return 'カスタム価格';
    }
  }

  /// Mapに変換（DB保存用）
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_type': businessType.name,
      'product_units': productUnits.join(','),
      'needs_inventory': needsInventory ? 1 : 0,
      'needs_gps': needsGPS ? 1 : 0,
      'needs_photos': needsPhotos ? 1 : 0,
      'workflow': workflow.name,
      'pricing': pricing.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Mapから生成（DB読み込み用）
  factory BusinessProfile.fromMap(Map<String, dynamic> map) {
    return BusinessProfile(
      id: map['id'] as String,
      businessType: BusinessType.values.firstWhere(
        (e) => e.name == map['business_type'],
        orElse: () => BusinessType.retail,
      ),
      productUnits: (map['product_units'] as String? ?? '個,式').split(','),
      needsInventory: (map['needs_inventory'] as int? ?? 1) == 1,
      needsGPS: (map['needs_gps'] as int? ?? 0) == 1,
      needsPhotos: (map['needs_photos'] as int? ?? 0) == 1,
      workflow: WorkflowType.values.firstWhere(
        (e) => e.name == map['workflow'],
        orElse: () => WorkflowType.both,
      ),
      pricing: PricingType.values.firstWhere(
        (e) => e.name == map['pricing'],
        orElse: () => PricingType.standard,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// コピーを作成
  BusinessProfile copyWith({
    String? id,
    BusinessType? businessType,
    List<String>? productUnits,
    bool? needsInventory,
    bool? needsGPS,
    bool? needsPhotos,
    WorkflowType? workflow,
    PricingType? pricing,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BusinessProfile(
      id: id ?? this.id,
      businessType: businessType ?? this.businessType,
      productUnits: productUnits ?? this.productUnits,
      needsInventory: needsInventory ?? this.needsInventory,
      needsGPS: needsGPS ?? this.needsGPS,
      needsPhotos: needsPhotos ?? this.needsPhotos,
      workflow: workflow ?? this.workflow,
      pricing: pricing ?? this.pricing,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BusinessProfile &&
        other.id == id &&
        other.businessType == businessType &&
        other.productUnits.toString() == productUnits.toString() &&
        other.needsInventory == needsInventory &&
        other.needsGPS == needsGPS &&
        other.needsPhotos == needsPhotos &&
        other.workflow == workflow &&
        other.pricing == pricing;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      businessType,
      productUnits,
      needsInventory,
      needsGPS,
      needsPhotos,
      workflow,
      pricing,
    );
  }

  @override
  String toString() {
    return 'BusinessProfile(id: $id, businessType: $businessType, needsInventory: $needsInventory)';
  }
}
