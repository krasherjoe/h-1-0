class CompanyInfo {
  final String name;
  final String? zipCode;
  final String? address;
  final String? address2;
  final String? tel;
  final String? fax;
  final String? email;
  final String? url;
  final double defaultTaxRate;
  final String? sealPath; // 角印（印鑑）の画像パス
  final double sealOffsetX; // 角印の右端からのオフセット（PDF座標）
  final double sealOffsetY; // 角印の上端からのオフセット（PDF座標）
  final double sealRotation; // 角印の回転角度（度数）
  final String taxDisplayMode; // 'normal', 'hidden', 'text_only'
  final String? registrationNumber; // 追加: インボイス登録番号 (T番号)

  CompanyInfo({
    required this.name,
    this.zipCode,
    this.address,
    this.address2,
    this.tel,
    this.fax,
    this.email,
    this.url,
    this.defaultTaxRate = 0.10,
    this.sealPath,
    this.sealOffsetX = 10.0,
    this.sealOffsetY = 50.0,
    this.sealRotation = 0.0,
    this.taxDisplayMode = 'normal',
    this.registrationNumber, // 追加
  });

  Map<String, dynamic> toMap() {
    return {
      'id': 1, // 常に1行のみ保持
      'name': name,
      'zip_code': zipCode,
      'address': address,
      'address2': address2,
      'tel': tel,
      'fax': fax,
      'email': email,
      'url': url,
      'default_tax_rate': defaultTaxRate,
      'seal_path': sealPath,
      'seal_offset_x': sealOffsetX,
      'seal_offset_y': sealOffsetY,
      'seal_rotation': sealRotation,
      'tax_display_mode': taxDisplayMode,
      'registration_number': registrationNumber, // 追加
    };
  }

  factory CompanyInfo.fromMap(Map<String, dynamic> map) {
    return CompanyInfo(
      name: map['name'] ?? "",
      zipCode: map['zip_code'],
      address: map['address'],
      address2: map['address2'],
      tel: map['tel'],
      fax: map['fax'],
      email: map['email'],
      url: map['url'],
      defaultTaxRate: (map['default_tax_rate'] ?? 0.10).toDouble(),
      sealPath: map['seal_path'],
      sealOffsetX: (map['seal_offset_x'] as num?)?.toDouble() ?? 10.0,
      sealOffsetY: (map['seal_offset_y'] as num?)?.toDouble() ?? 50.0,
      sealRotation: (map['seal_rotation'] as num?)?.toDouble() ?? 0.0,
      taxDisplayMode: map['tax_display_mode'] ?? 'normal',
      registrationNumber: map['registration_number'], // 追加
    );
  }

  CompanyInfo copyWith({
    String? name,
    String? zipCode,
    String? address,
    String? address2,
    String? tel,
    String? fax,
    String? email,
    String? url,
    double? defaultTaxRate,
    String? sealPath,
    double? sealOffsetX,
    double? sealOffsetY,
    double? sealRotation,
    String? taxDisplayMode,
    String? registrationNumber, // 追加
  }) {
    return CompanyInfo(
      name: name ?? this.name,
      zipCode: zipCode ?? this.zipCode,
      address: address ?? this.address,
      address2: address2 ?? this.address2,
      tel: tel ?? this.tel,
      fax: fax ?? this.fax,
      email: email ?? this.email,
      url: url ?? this.url,
      defaultTaxRate: defaultTaxRate ?? this.defaultTaxRate,
      sealPath: sealPath ?? this.sealPath,
      sealOffsetX: sealOffsetX ?? this.sealOffsetX,
      sealOffsetY: sealOffsetY ?? this.sealOffsetY,
      sealRotation: sealRotation ?? this.sealRotation,
      taxDisplayMode: taxDisplayMode ?? this.taxDisplayMode,
      registrationNumber: registrationNumber ?? this.registrationNumber, // 追加
    );
  }
}
