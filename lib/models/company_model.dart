class CompanyInfo {
  final String name;
  final String? zipCode;
  final String? address;
  final String? tel;
  final String? fax;
  final String? email;
  final String? url;
  final double defaultTaxRate;
  final String? sealPath; // 角印（印鑑）の画像パス
  final String taxDisplayMode; // 'normal', 'hidden', 'text_only'
  final String? registrationNumber; // 追加: インボイス登録番号 (T番号)

  CompanyInfo({
    required this.name,
    this.zipCode,
    this.address,
    this.tel,
    this.fax,
    this.email,
    this.url,
    this.defaultTaxRate = 0.10,
    this.sealPath,
    this.taxDisplayMode = 'normal',
    this.registrationNumber, // 追加
  });

  Map<String, dynamic> toMap() {
    return {
      'id': 1, // 常に1行のみ保持
      'name': name,
      'zip_code': zipCode,
      'address': address,
      'tel': tel,
      'fax': fax,
      'email': email,
      'url': url,
      'default_tax_rate': defaultTaxRate,
      'seal_path': sealPath,
      'tax_display_mode': taxDisplayMode,
      'registration_number': registrationNumber, // 追加
    };
  }

  factory CompanyInfo.fromMap(Map<String, dynamic> map) {
    return CompanyInfo(
      name: map['name'] ?? "",
      zipCode: map['zip_code'],
      address: map['address'],
      tel: map['tel'],
      fax: map['fax'],
      email: map['email'],
      url: map['url'],
      defaultTaxRate: (map['default_tax_rate'] ?? 0.10).toDouble(),
      sealPath: map['seal_path'],
      taxDisplayMode: map['tax_display_mode'] ?? 'normal',
      registrationNumber: map['registration_number'], // 追加
    );
  }

  CompanyInfo copyWith({
    String? name,
    String? zipCode,
    String? address,
    String? tel,
    String? fax,
    String? email,
    String? url,
    double? defaultTaxRate,
    String? sealPath,
    String? taxDisplayMode,
    String? registrationNumber, // 追加
  }) {
    return CompanyInfo(
      name: name ?? this.name,
      zipCode: zipCode ?? this.zipCode,
      address: address ?? this.address,
      tel: tel ?? this.tel,
      fax: fax ?? this.fax,
      email: email ?? this.email,
      url: url ?? this.url,
      defaultTaxRate: defaultTaxRate ?? this.defaultTaxRate,
      sealPath: sealPath ?? this.sealPath,
      taxDisplayMode: taxDisplayMode ?? this.taxDisplayMode,
      registrationNumber: registrationNumber ?? this.registrationNumber, // 追加
    );
  }
}
