/// 電子帳簿保存法対応 - バージョン管理フィールド
extension ProductVersioning on Product {
  /// 現在のバージョンか判定
  bool get isCurrent => isCurrentFlag;

  /// バージョンハッシュ（改ざん検出用）
  String? get contentHashValue => contentHash;

  /// 前バージョンハッシュ（チェーンリンク）
  String? get previousHashValue => previousHash;
}

class Product {
  final String id;
  final String name;
  final int defaultUnitPrice;
  final bool defaultUnitPriceIsTaxInclusive;
  final int wholesalePrice;
  final bool wholesalePriceIsTaxInclusive;
  final String? barcode;
  final String? category;
  final String? categoryId; // カテゴリー ID
  final int? stockQuantity; // null = 在庫管理なし、0 以上 = 在庫数
  final String? odooId;
  final bool isLocked; // ロック
  final bool isHidden; // 非表示

  // 電子帳簿保存法対応 - バージョン管理フィールド
  final DateTime? validFrom; // 有効開始日
  final DateTime? validTo; // 有効終了日（NULL = 現在有効）
  final bool isCurrentFlag; // 現在のバージョンか
  final int version; // バージョン番号
  final String? contentHash; // コンテンツハッシュ（改ざん検出用）
  final String? previousHash; // 前バージョンハッシュ（チェーンリンク）

  Product({
    required this.id,
    required this.name,
    this.defaultUnitPrice = 0,
    this.defaultUnitPriceIsTaxInclusive = false,
    this.wholesalePrice = 0,
    this.wholesalePriceIsTaxInclusive = false,
    this.barcode,
    this.category,
    this.categoryId,
    this.stockQuantity,
    this.odooId,
    this.isLocked = false,
    this.isHidden = false,
    this.validFrom,
    this.validTo,
    this.isCurrentFlag = true,
    this.version = 1,
    this.contentHash,
    this.previousHash,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'default_unit_price': defaultUnitPrice,
      'default_unit_price_is_tax_inclusive': defaultUnitPriceIsTaxInclusive ? 1 : 0,
      'wholesale_price': wholesalePrice,
      'wholesale_price_is_tax_inclusive': wholesalePriceIsTaxInclusive ? 1 : 0,
      'barcode': barcode,
      'category': category,
      'category_id': categoryId,
      'stock_quantity': stockQuantity,
      'is_locked': isLocked ? 1 : 0,
      'odoo_id': odooId,
      'is_hidden': isHidden ? 1 : 0,
      // 電子帳簿保存法対応 - バージョン管理フィールド
      'valid_from': validFrom?.toIso8601String(),
      'valid_to': validTo?.toIso8601String(),
      'is_current': isCurrentFlag ? 1 : 0,
      'version': version,
      'content_hash': contentHash,
      'previous_hash': previousHash,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      defaultUnitPrice: map['default_unit_price'] ?? 0,
      defaultUnitPriceIsTaxInclusive: (map['default_unit_price_is_tax_inclusive'] ?? 0) == 1,
      wholesalePrice: map['wholesale_price'] ?? 0,
      wholesalePriceIsTaxInclusive: (map['wholesale_price_is_tax_inclusive'] ?? 0) == 1,
      barcode: map['barcode'],
      category: map['category'],
      categoryId: map['category_id'],
      stockQuantity: map['stock_quantity'],
      isLocked: (map['is_locked'] ?? 0) == 1,
      odooId: map['odoo_id'],
      isHidden: (map['is_hidden'] ?? 0) == 1,
      // 電子帳簿保存法対応 - バージョン管理フィールド
      validFrom: map['valid_from'] != null
          ? DateTime.parse(map['valid_from'])
          : null,
      validTo: map['valid_to'] != null ? DateTime.parse(map['valid_to']) : null,
      isCurrentFlag: (map['is_current'] ?? 1) == 1,
      version: map['version'] ?? 1,
      contentHash: map['content_hash'],
      previousHash: map['previous_hash'],
    );
  }

  /// 在庫管理対象外カテゴリー（サービス・サポート）か判定
  bool get isNonStockCategory {
    if (category == null || category!.isEmpty) return false;
    const nonStock = ['サポート', 'サービス'];
    return nonStock.contains(category!.trim());
  }

  Product copyWith({
    String? id,
    String? name,
    int? defaultUnitPrice,
    bool? defaultUnitPriceIsTaxInclusive,
    int? wholesalePrice,
    bool? wholesalePriceIsTaxInclusive,
    String? barcode,
    String? category,
    String? categoryId,
    int? stockQuantity,
    String? odooId,
    bool? isLocked,
    bool? isHidden,
    DateTime? validFrom,
    DateTime? validTo,
    bool? isCurrentFlag,
    int? version,
    String? contentHash,
    String? previousHash,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      defaultUnitPrice: defaultUnitPrice ?? this.defaultUnitPrice,
      defaultUnitPriceIsTaxInclusive: defaultUnitPriceIsTaxInclusive ?? this.defaultUnitPriceIsTaxInclusive,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      wholesalePriceIsTaxInclusive: wholesalePriceIsTaxInclusive ?? this.wholesalePriceIsTaxInclusive,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      categoryId: categoryId ?? this.categoryId,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      odooId: odooId ?? this.odooId,
      isLocked: isLocked ?? this.isLocked,
      isHidden: isHidden ?? this.isHidden,
      // 電子帳簿保存法対応 - バージョン管理フィールド
      validFrom: validFrom ?? this.validFrom,
      validTo: validTo ?? this.validTo,
      isCurrentFlag: isCurrentFlag ?? this.isCurrentFlag,
      version: version ?? this.version,
      contentHash: contentHash ?? this.contentHash,
      previousHash: previousHash ?? this.previousHash,
    );
  }
}
