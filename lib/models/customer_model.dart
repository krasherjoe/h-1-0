
class Customer {
  final String id;
  final String displayName; // 表示用（電話帳名など）
  final String formalName;  // 請求書用正式名称
  final String title;       // 敬称（様、殿など）
  final String? department; // 部署名
  final String? address;    // 住所
  final String? tel;         // 電話番号
  final String? odooId;     // Odoo側のID
  final bool isSynced;      // 同期フラグ
  final DateTime updatedAt; // 最終更新日時

  Customer({
    required this.id,
    required this.displayName,
    required this.formalName,
    this.title = "様",
    this.department,
    this.address,
    this.tel,
    this.odooId,
    this.isSynced = false,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  String get invoiceName {
    String name = formalName;
    if (department != null && department!.isNotEmpty) {
      name = "$formalName\n$department";
    }
    return "$name $title";
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'display_name': displayName,
      'formal_name': formalName,
      'title': title,
      'department': department,
      'address': address,
      'tel': tel,
      'odoo_id': odooId,
      'is_synced': isSynced ? 1 : 0,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'],
      displayName: map['display_name'],
      formalName: map['formal_name'],
      title: map['title'] ?? "様",
      department: map['department'],
      address: map['address'],
      tel: map['tel'],
      odooId: map['odoo_id'],
      isSynced: map['is_synced'] == 1,
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Customer copyWith({
    String? id,
    String? displayName,
    String? formalName,
    String? title,
    String? department,
    String? address,
    String? tel,
    String? odooId,
    bool? isSynced,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      formalName: formalName ?? this.formalName,
      title: title ?? this.title,
      department: department ?? this.department,
      address: address ?? this.address,
      tel: tel ?? this.tel,
      odooId: odooId ?? this.odooId,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
