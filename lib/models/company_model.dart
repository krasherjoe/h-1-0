class CompanyInfo {
  final String name;
  final String? zipCode;
  final String? address;
  final String? tel;
  final double defaultTaxRate;
  final String? sealPath; // 角印（印鑑）の画像パス

  CompanyInfo({
    required this.name,
    this.zipCode,
    this.address,
    this.tel,
    this.defaultTaxRate = 0.10,
    this.sealPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': 1, // 常に1行のみ保持
      'name': name,
      'zip_code': zipCode,
      'address': address,
      'tel': tel,
      'default_tax_rate': defaultTaxRate,
      'seal_path': sealPath,
    };
  }

  factory CompanyInfo.fromMap(Map<String, dynamic> map) {
    return CompanyInfo(
      name: map['name'] ?? "自社名未設定",
      zipCode: map['zip_code'],
      address: map['address'],
      tel: map['tel'],
      defaultTaxRate: map['default_tax_rate'] ?? 0.10,
      sealPath: map['seal_path'],
    );
  }

  CompanyInfo copyWith({
    String? name,
    String? zipCode,
    String? address,
    String? tel,
    double? defaultTaxRate,
    String? sealPath,
  }) {
    return CompanyInfo(
      name: name ?? this.name,
      zipCode: zipCode ?? this.zipCode,
      address: address ?? this.address,
      tel: tel ?? this.tel,
      defaultTaxRate: defaultTaxRate ?? this.defaultTaxRate,
      sealPath: sealPath ?? this.sealPath,
    );
  }
}
