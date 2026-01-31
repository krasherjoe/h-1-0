import '../models/invoice_models.dart';

/// 商品情報を管理するモデル
/// 将来的な Odoo 同期を見据えて、外部ID（odooId）を保持できるように設計
class Product {
  final String id;             // ローカル管理用のID
  final int? odooId;           // Odoo上の product.product ID (nullの場合は未同期)
  final String name;           // 商品名
  final int defaultUnitPrice;  // 標準単価
  final String? category;      // カテゴリ

  const Product({
    required this.id,
    this.odooId,
    required this.name,
    required this.defaultUnitPrice,
    this.category,
  });

  /// InvoiceItem への変換
  InvoiceItem toInvoiceItem({int quantity = 1}) {
    return InvoiceItem(
      description: name,
      quantity: quantity,
      unitPrice: defaultUnitPrice,
    );
  }

  /// 状態更新のためのコピーメソッド
  Product copyWith({
    String? id,
    int? odooId,
    String? name,
    int? defaultUnitPrice,
    String? category,
  }) {
    return Product(
      id: id ?? this.id,
      odooId: odooId ?? this.odooId,
      name: name ?? this.name,
      defaultUnitPrice: defaultUnitPrice ?? this.defaultUnitPrice,
      category: category ?? this.category,
    );
  }

  /// JSON変換 (ローカル保存・Odoo同期用)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'odoo_id': odooId,
      'name': name,
      'default_unit_price': defaultUnitPrice,
      'category': category,
    };
  }

  /// JSONからモデルを生成
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      odooId: json['odoo_id'],
      name: json['name'],
      defaultUnitPrice: json['default_unit_price'],
      category: json['category'],
    );
  }
}

/// 商品マスターのテンプレートデータ
class ProductMaster {
  static const List<Product> products = [
    Product(id: 'S001', name: 'システム開発費', defaultUnitPrice: 500000, category: '開発'),
    Product(id: 'S002', name: '保守・メンテナンス費', defaultUnitPrice: 50000, category: '運用'),
    Product(id: 'S003', name: '技術コンサルティング', defaultUnitPrice: 100000, category: '開発'),
    Product(id: 'G001', name: 'ライセンス料 (Pro)', defaultUnitPrice: 15000, category: '製品'),
    Product(id: 'G002', name: '初期導入セットアップ', defaultUnitPrice: 30000, category: '製品'),
    Product(id: 'M001', name: 'ハードウェア一式', defaultUnitPrice: 250000, category: '物品'),
    Product(id: 'Z001', name: '諸経費', defaultUnitPrice: 5000, category: 'その他'),
  ];

  /// カテゴリ一覧の取得
  static List<String> get categories {
    return products.map((p) => p.category ?? 'その他').toSet().toList();
  }

  /// カテゴリ別の商品取得
  static List<Product> getProductsByCategory(String category) {
    return products.where((p) => (p.category ?? 'その他') == category).toList();
  }

  /// 名前またはIDで検索
  static List<Product> search(String query) {
    final q = query.toLowerCase();
    return products.where((p) =>
      p.name.toLowerCase().contains(q) ||
      p.id.toLowerCase().contains(q)
    ).toList();
  }
}
