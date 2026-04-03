class Supplier {
  final String id;
  final String displayName;  // 表示名
  final String formalName;   // 正式名称
  final String title;        // 敬称
  final String? department;  // 部署
  final String? address;     // 住所
  final String? tel;         // 電話番号
  final String? email;       // メール
  final String? contactPerson; // 担当者
  final String? paymentTerms; // 支払条件
  final String? bankAccount;  // 銀行口座
  final int? closingDay;     // 締め日
  final int paymentSiteDays; // 支払サイト
  final String? notes;       // 備考
  final bool isLocked;
  final bool isHidden;
  final DateTime updatedAt;
  final String? headChar1;
  final String? headChar2;

  Supplier({
    required this.id,
    required this.displayName,
    required this.formalName,
    this.title = "様",
    this.department,
    this.address,
    this.tel,
    this.email,
    this.contactPerson,
    this.paymentTerms,
    this.bankAccount,
    this.closingDay,
    this.paymentSiteDays = 30,
    this.notes,
    this.isLocked = false,
    this.isHidden = false,
    DateTime? updatedAt,
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

  String get name => displayName;

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
      'contact_person': contactPerson,
      'payment_terms': paymentTerms,
      'bank_account': bankAccount,
      'closing_day': closingDay,
      'payment_site_days': paymentSiteDays,
      'notes': notes,
      'is_locked': isLocked ? 1 : 0,
      'is_hidden': isHidden ? 1 : 0,
      'updated_at': updatedAt.toIso8601String(),
      'head_char1': headChar1,
      'head_char2': headChar2,
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'] as String,
      displayName: map['display_name'] as String,
      formalName: map['formal_name'] as String,
      title: map['title'] as String? ?? "様",
      department: map['department'],
      address: map['address'],
      tel: map['tel'],
      email: map['email'],
      contactPerson: map['contact_person'],
      paymentTerms: map['payment_terms'],
      bankAccount: map['bank_account'],
      closingDay: map['closing_day'],
      paymentSiteDays: map['payment_site_days'] as int? ?? 30,
      notes: map['notes'],
      isLocked: (map['is_locked'] ?? 0) == 1,
      isHidden: (map['is_hidden'] ?? 0) == 1,
      updatedAt: DateTime.parse(map['updated_at']),
      headChar1: map['head_char1'],
      headChar2: map['head_char2'],
    );
  }

  Supplier copyWith({
    String? id,
    String? displayName,
    String? formalName,
    String? title,
    String? department,
    String? address,
    String? tel,
    String? email,
    String? contactPerson,
    String? paymentTerms,
    String? bankAccount,
    int? closingDay,
    int? paymentSiteDays,
    String? notes,
    bool? isLocked,
    bool? isHidden,
    DateTime? updatedAt,
    String? headChar1,
    String? headChar2,
  }) {
    return Supplier(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      formalName: formalName ?? this.formalName,
      title: title ?? this.title,
      department: department ?? this.department,
      address: address ?? this.address,
      tel: tel ?? this.tel,
      email: email ?? this.email,
      contactPerson: contactPerson ?? this.contactPerson,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      bankAccount: bankAccount ?? this.bankAccount,
      closingDay: closingDay ?? this.closingDay,
      paymentSiteDays: paymentSiteDays ?? this.paymentSiteDays,
      notes: notes ?? this.notes,
      isLocked: isLocked ?? this.isLocked,
      isHidden: isHidden ?? this.isHidden,
      updatedAt: updatedAt ?? this.updatedAt,
      headChar1: headChar1 ?? this.headChar1,
      headChar2: headChar2 ?? this.headChar2,
    );
  }
}
