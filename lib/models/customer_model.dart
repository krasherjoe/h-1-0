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

/// 敬称コード定義
class HonorificCode {
  static const int san = 1;
  static const int onchu = 2;
  static const int dono = 3;
  static const int kisha = 4;

  static String toName(int code) {
    switch (code) {
      case onchu:
        return '御中';
      case dono:
        return '殿';
      case kisha:
        return '貴社';
      default:
        return '様';
    }
  }

  static int toCode(String name) {
    switch (name) {
      case '御中':
        return onchu;
      case '殿':
        return dono;
      case '貴社':
        return kisha;
      default:
        return san;
    }
  }
}

/// 電子帳簿保存法対応 - バージョン管理フィールド
extension CustomerVersioning on Customer {
  /// 現在のバージョンか判定
  bool get isCurrent => isCurrentFlag;

  /// バージョンハッシュ（改ざん検出用）
  String? get contentHashValue => contentHash;

  /// 前バージョンハッシュ（チェーンリンク）
  String? get previousHashValue => previousHash;
}

class Customer {
  final String id;
  final String displayName; // 表示用（電話帳名など）
  final String formalName; // 請求書用正式名称
  final int title; // 敬称コード（1:様, 2:御中, 3:殿, 4:貴社）
  final String? department; // 部署名
  final String? address; // 住所（最新連絡先）
  final String? tel; // 電話番号（最新連絡先）
  final String? email; // メール（最新連絡先）
  final int? contactVersionId; // 連絡先バージョン
  final String? odooId; // Odoo 側の ID
  final bool isSynced; // 同期フラグ
  final DateTime updatedAt; // 最終更新日時
  final bool isLocked; // ロック
  final bool isHidden; // 非表示
  final String? headChar1; // インデックス 1
  final String? headChar2; // インデックス 2

  // 電子帳簿保存法対応 - バージョン管理フィールド
  final DateTime? validFrom; // 有効開始日
  final DateTime? validTo; // 有効終了日（NULL = 現在有効）
  final bool isCurrentFlag; // 現在のバージョンか
  final int version; // バージョン番号
  final String? contentHash; // コンテンツハッシュ（改ざん検出用）
  final String? previousHash; // 前バージョンハッシュ（チェーンリンク）
  final String? nextVersionId; // 次の世代のレコード番号（フォーク時に設定）

  Customer({
    required this.id,
    required this.displayName,
    required this.formalName,
    this.title = HonorificCode.san,
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
    this.validFrom,
    this.validTo,
    this.isCurrentFlag = true,
    this.version = 1,
    this.contentHash,
    this.previousHash,
    this.nextVersionId,
  }) : updatedAt = updatedAt ?? DateTime.now();

  String get invoiceName {
    String name = formalName;
    if (department != null && department!.isNotEmpty) {
      name = "$formalName\n$department";
    }
    return "$name ${HonorificCode.toName(title)}";
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
      // 電子帳簿保存法対応 - バージョン管理フィールド
      'valid_from': validFrom?.toIso8601String(),
      'valid_to': validTo?.toIso8601String(),
      'is_current': isCurrentFlag ? 1 : 0,
      'version': version,
      'content_hash': contentHash,
      'previous_hash': previousHash,
      'next_version_id': nextVersionId,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    final titleValue = map['title'];
    int titleCode;
    if (titleValue is int) {
      titleCode = titleValue;
    } else if (titleValue is String) {
      titleCode = HonorificCode.toCode(titleValue);
    } else {
      titleCode = HonorificCode.san;
    }

    return Customer(
      id: map['id'],
      displayName: map['display_name'],
      formalName: map['formal_name'],
      title: titleCode,
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
      // 電子帳簿保存法対応 - バージョン管理フィールド
      validFrom: map['valid_from'] != null
          ? DateTime.parse(map['valid_from'])
          : null,
      validTo: map['valid_to'] != null ? DateTime.parse(map['valid_to']) : null,
      isCurrentFlag: (map['is_current'] ?? 1) == 1,
      version: map['version'] ?? 1,
      contentHash: map['content_hash'],
      previousHash: map['previous_hash'],
      nextVersionId: map['next_version_id'],
    );
  }

  Customer copyWith({
    String? id,
    String? displayName,
    String? formalName,
    int? title,
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
    DateTime? validFrom,
    DateTime? validTo,
    bool? isCurrentFlag,
    int? version,
    String? contentHash,
    String? previousHash,
    String? nextVersionId,
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
      // 電子帳簿保存法対応 - バージョン管理フィールド
      validFrom: validFrom ?? this.validFrom,
      validTo: validTo ?? this.validTo,
      isCurrentFlag: isCurrentFlag ?? this.isCurrentFlag,
      version: version ?? this.version,
      contentHash: contentHash ?? this.contentHash,
      previousHash: previousHash ?? this.previousHash,
      nextVersionId: nextVersionId ?? this.nextVersionId,
    );
  }
}
