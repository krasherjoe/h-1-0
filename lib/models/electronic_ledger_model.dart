/// 電子帳簿保存法対応データモデル
/// 
/// 電子帳簿保存法の要件を満たすためのデータモデル群。
/// 
/// 電子帳簿ドキュメントタイプ
enum ElectronicLedgerDocumentType {
  invoice('invoice', '請求書'),
  receipt('receipt', '領収書'),
  purchaseOrder('purchase_order', '発注書'),
  purchaseReturn('purchase_return', '仕入返品書'),
  estimate('estimate', '見積書'),
  quotation('quotation', '見積書'),
  salesOrder('sales_order', '受注書'),
  salesReturn('sales_return', '売上返品書'),
  deliveryNote('delivery_note', '納品書'),
  paymentRecord('payment_record', '支払記録'),
  bankTransaction('bank_transaction', '銀行取引'),
  expense('expense', '経費'),
  inventoryAdjustment('inventory_adjustment', '在庫調整'),
  stocktake('stocktake', '棚卸'),
  other('other', 'その他');

  const ElectronicLedgerDocumentType(this.code, this.displayName);
  
  final String code;
  final String displayName;
}

/// 電子帳簿ドキュメント
class ElectronicLedger {
  final String id;
  final ElectronicLedgerDocumentType documentType;
  final Map<String, dynamic> documentData;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String businessProfileId;
  final String documentHash;
  final Map<String, dynamic> metadata;
  final bool isActive;

  const ElectronicLedger({
    required this.id,
    required this.documentType,
    required this.documentData,
    required this.createdAt,
    required this.updatedAt,
    required this.businessProfileId,
    required this.documentHash,
    required this.metadata,
    required this.isActive,
  });

  /// コピーを作成
  ElectronicLedger copyWith({
    String? id,
    ElectronicLedgerDocumentType? documentType,
    Map<String, dynamic>? documentData,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? businessProfileId,
    String? documentHash,
    Map<String, dynamic>? metadata,
    bool? isActive,
  }) {
    return ElectronicLedger(
      id: id ?? this.id,
      documentType: documentType ?? this.documentType,
      documentData: documentData ?? this.documentData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      businessProfileId: businessProfileId ?? this.businessProfileId,
      documentHash: documentHash ?? this.documentHash,
      metadata: metadata ?? this.metadata,
      isActive: isActive ?? this.isActive,
    );
  }

  /// JSONから変換
  factory ElectronicLedger.fromJson(Map<String, dynamic> json) {
    return ElectronicLedger(
      id: json['id'] as String,
      documentType: ElectronicLedgerDocumentType.values.firstWhere(
        (type) => type.code == json['documentType'],
        orElse: () => ElectronicLedgerDocumentType.other,
      ),
      documentData: json['documentData'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      businessProfileId: json['businessProfileId'] as String,
      documentHash: json['documentHash'] as String,
      metadata: json['metadata'] as Map<String, dynamic>,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'documentType': documentType.code,
      'documentData': documentData,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'businessProfileId': businessProfileId,
      'documentHash': documentHash,
      'metadata': metadata,
      'isActive': isActive,
    };
  }

  /// 等価性チェック
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ElectronicLedger &&
        other.id == id &&
        other.documentType == documentType &&
        other.documentHash == documentHash;
  }

  @override
  int get hashCode {
    return id.hashCode ^ documentType.hashCode ^ documentHash.hashCode;
  }

  @override
  String toString() {
    return 'ElectronicLedger(id: $id, type: $documentType, createdAt: $createdAt)';
  }
}

/// 電子帳簿ドキュメント履歴
class ElectronicLedgerHistory {
  final String id;
  final String ledgerId;
  final Map<String, dynamic> documentData;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String documentHash;
  final Map<String, dynamic> metadata;

  const ElectronicLedgerHistory({
    required this.id,
    required this.ledgerId,
    required this.documentData,
    required this.createdAt,
    required this.updatedAt,
    required this.documentHash,
    required this.metadata,
  });

  /// JSONから変換
  factory ElectronicLedgerHistory.fromJson(Map<String, dynamic> json) {
    return ElectronicLedgerHistory(
      id: json['id'] as String,
      ledgerId: json['ledgerId'] as String,
      documentData: json['documentData'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      documentHash: json['documentHash'] as String,
      metadata: json['metadata'] as Map<String, dynamic>,
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ledgerId': ledgerId,
      'documentData': documentData,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'documentHash': documentHash,
      'metadata': metadata,
    };
  }
}

/// 電子帳簿保存要件
class ElectronicLedgerRequirement {
  final String id;
  final String name;
  final String description;
  final bool isRequired;
  final String? legalReference;
  final DateTime effectiveDate;
  final DateTime? expiryDate;

  const ElectronicLedgerRequirement({
    required this.id,
    required this.name,
    required this.description,
    required this.isRequired,
    this.legalReference,
    required this.effectiveDate,
    this.expiryDate,
  });

  /// JSONから変換
  factory ElectronicLedgerRequirement.fromJson(Map<String, dynamic> json) {
    return ElectronicLedgerRequirement(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      isRequired: json['isRequired'] as bool,
      legalReference: json['legalReference'] as String?,
      effectiveDate: DateTime.parse(json['effectiveDate'] as String),
      expiryDate: json['expiryDate'] != null 
          ? DateTime.parse(json['expiryDate'] as String)
          : null,
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'isRequired': isRequired,
      'legalReference': legalReference,
      'effectiveDate': effectiveDate.toIso8601String(),
      'expiryDate': expiryDate?.toIso8601String(),
    };
  }
}

/// 電子帳簿保存期間
enum ElectronicLedgerRetentionPeriod {
  sevenYears('7_years', '7年間'),
  tenYears('10_years', '10年間'),
  permanent('permanent', '永久');

  const ElectronicLedgerRetentionPeriod(this.code, this.displayName);
  
  final String code;
  final String displayName;
}

/// 電子帳簿保存設定
class ElectronicLedgerSettings {
  final String id;
  final String businessProfileId;
  final ElectronicLedgerRetentionPeriod retentionPeriod;
  final bool enableCompression;
  final bool enableEncryption;
  final bool enableVersioning;
  final Map<String, dynamic> customSettings;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ElectronicLedgerSettings({
    required this.id,
    required this.businessProfileId,
    required this.retentionPeriod,
    required this.enableCompression,
    required this.enableEncryption,
    required this.enableVersioning,
    required this.customSettings,
    required this.createdAt,
    required this.updatedAt,
  });

  /// デフォルト設定
  factory ElectronicLedgerSettings.defaultSettings({
    required String businessProfileId,
  }) {
    final now = DateTime.now();
    return ElectronicLedgerSettings(
      id: 'settings_${businessProfileId}_${now.millisecondsSinceEpoch}',
      businessProfileId: businessProfileId,
      retentionPeriod: ElectronicLedgerRetentionPeriod.sevenYears,
      enableCompression: true,
      enableEncryption: false,
      enableVersioning: true,
      customSettings: {},
      createdAt: now,
      updatedAt: now,
    );
  }

  /// JSONから変換
  factory ElectronicLedgerSettings.fromJson(Map<String, dynamic> json) {
    return ElectronicLedgerSettings(
      id: json['id'] as String,
      businessProfileId: json['businessProfileId'] as String,
      retentionPeriod: ElectronicLedgerRetentionPeriod.values.firstWhere(
        (period) => period.code == json['retentionPeriod'],
        orElse: () => ElectronicLedgerRetentionPeriod.sevenYears,
      ),
      enableCompression: json['enableCompression'] as bool,
      enableEncryption: json['enableEncryption'] as bool,
      enableVersioning: json['enableVersioning'] as bool,
      customSettings: json['customSettings'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'businessProfileId': businessProfileId,
      'retentionPeriod': retentionPeriod.code,
      'enableCompression': enableCompression,
      'enableEncryption': enableEncryption,
      'enableVersioning': enableVersioning,
      'customSettings': customSettings,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// コピーを作成
  ElectronicLedgerSettings copyWith({
    String? id,
    String? businessProfileId,
    ElectronicLedgerRetentionPeriod? retentionPeriod,
    bool? enableCompression,
    bool? enableEncryption,
    bool? enableVersioning,
    Map<String, dynamic>? customSettings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ElectronicLedgerSettings(
      id: id ?? this.id,
      businessProfileId: businessProfileId ?? this.businessProfileId,
      retentionPeriod: retentionPeriod ?? this.retentionPeriod,
      enableCompression: enableCompression ?? this.enableCompression,
      enableEncryption: enableEncryption ?? this.enableEncryption,
      enableVersioning: enableVersioning ?? this.enableVersioning,
      customSettings: customSettings ?? this.customSettings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// データ整合性チェック結果
class DataIntegrityCheckResult {
  final String documentId;
  final String documentType;
  final String issue;
  final String storedHash;
  final String calculatedHash;
  final DateTime createdAt;

  const DataIntegrityCheckResult({
    required this.documentId,
    required this.documentType,
    required this.issue,
    required this.storedHash,
    required this.calculatedHash,
    required this.createdAt,
  });

  /// JSONから変換
  factory DataIntegrityCheckResult.fromJson(Map<String, dynamic> json) {
    return DataIntegrityCheckResult(
      documentId: json['documentId'] as String,
      documentType: json['documentType'] as String,
      issue: json['issue'] as String,
      storedHash: json['storedHash'] as String,
      calculatedHash: json['calculatedHash'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    return {
      'documentId': documentId,
      'documentType': documentType,
      'issue': issue,
      'storedHash': storedHash,
      'calculatedHash': calculatedHash,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// データベース統計情報
class DatabaseStatistics {
  final int totalDocuments;
  final List<DocumentTypeStatistics> documentsByType;
  final int totalDataSize;
  final double averageDataSize;
  final String lastUpdated;

  const DatabaseStatistics({
    required this.totalDocuments,
    required this.documentsByType,
    required this.totalDataSize,
    required this.averageDataSize,
    required this.lastUpdated,
  });

  /// JSONから変換
  factory DatabaseStatistics.fromJson(Map<String, dynamic> json) {
    return DatabaseStatistics(
      totalDocuments: json['totalDocuments'] as int,
      documentsByType: (json['documentsByType'] as List)
          .map((item) => DocumentTypeStatistics.fromJson(item as Map<String, dynamic>))
          .toList(),
      totalDataSize: json['totalDataSize'] as int,
      averageDataSize: (json['averageDataSize'] as num).toDouble(),
      lastUpdated: json['lastUpdated'] as String,
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    return {
      'totalDocuments': totalDocuments,
      'documentsByType': documentsByType.map((item) => item.toJson()).toList(),
      'totalDataSize': totalDataSize,
      'averageDataSize': averageDataSize,
      'lastUpdated': lastUpdated,
    };
  }
}

/// ドキュメントタイプ統計
class DocumentTypeStatistics {
  final String type;
  final int count;

  const DocumentTypeStatistics({
    required this.type,
    required this.count,
  });

  /// JSONから変換
  factory DocumentTypeStatistics.fromJson(Map<String, dynamic> json) {
    return DocumentTypeStatistics(
      type: json['type'] as String,
      count: json['count'] as int,
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'count': count,
    };
  }
}
