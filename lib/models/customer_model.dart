/// 顧客重複例外
class DuplicateCustomerException implements Exception {
  final Customer customer;

  DuplicateCustomerException(this.customer);

  @override
  String toString() {
    return 'DuplicateCustomerException: 同じ電話番号・メール・社名の顧客が既に存在します。'
        '\n表示名：${customer.displayName}'
        '\n正式名称：${customer.formalName}'
        '\n電話：${customer.tel ?? "N/A"}'
        '\nメール：${customer.email ?? "N/A"}';
  }
}

class Customer {
  final String id;
  final String displayName; // 表示用（電話帳名など）
  final String formalName; // 請求書用正式名称
  final String title; // 敬称（様、殿など）
  final String? department; // 部署名
  final String? address; // 住所（最新連絡先）
  final String? tel; // 電話番号（最新連絡先）
  final String? email; // メール（最新連絡先）
  final int? contactVersionId; // 連絡先バージョン
  final String? odooId; // Odoo側のID
  final bool isSynced; // 同期フラグ
  final DateTime updatedAt; // 最終更新日時
  final bool isLocked; // ロック
  final bool isHidden; // 非表示
  final String? headChar1; // インデックス1
  final String? headChar2; // インデックス2

  Customer({
    required this.id,
    required this.displayName,
    required this.formalName,
    this.title = "様",
    this.department,
    this.address,
    this.tel,
    this.email,
    this.contactVersionId,
    this.odooId,
    this.isSynced = false,
    DateTime? updatedAt,
    this.isLocked = false,
    this.isHidden = false,
    this.headChar1,
    this.headChar2,
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
      'email': email,
      'contact_version_id': contactVersionId,
      'odoo_id': odooId,
      'head_char1': headChar1,
      'head_char2': headChar2,
      'is_locked': isLocked ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
      'is_hidden': isHidden ? 1 : 0,
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
      address: map['contact_address'] ?? map['address'],
      tel: map['contact_tel'] ?? map['tel'],
      email: map['contact_email'] ?? map['email'],
      contactVersionId: map['contact_version_id'],
      odooId: map['odoo_id'],
      isLocked: (map['is_locked'] ?? 0) == 1,
      isSynced: map['is_synced'] == 1,
      isHidden: (map['is_hidden'] ?? 0) == 1,
      updatedAt: DateTime.parse(map['updated_at']),
      headChar1: map['head_char1'],
      headChar2: map['head_char2'],
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
    bool? isLocked,
    bool? isHidden,
    String? email,
    int? contactVersionId,
    String? headChar1,
    String? headChar2,
  }) {
    return Customer(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      formalName: formalName ?? this.formalName,
      title: title ?? this.title,
      department: department ?? this.department,
      address: address ?? this.address,
      tel: tel ?? this.tel,
      email: email ?? this.email,
      contactVersionId: contactVersionId ?? this.contactVersionId,
      odooId: odooId ?? this.odooId,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
      isLocked: isLocked ?? this.isLocked,
      isHidden: isHidden ?? this.isHidden,
      headChar1: headChar1 ?? this.headChar1,
      headChar2: headChar2 ?? this.headChar2,
    );
  }
}
