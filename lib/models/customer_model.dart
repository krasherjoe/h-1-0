import 'package:uuid/uuid.dart';

class Customer {
  final String id;
  final String displayName; // 表示用（電話帳名など）
  final String formalName;  // 請求書用正式名称
  final String title;       // 敬称（様、殿など）
  final String? department; // 部署名
  final String? address;    // 住所

  Customer({
    required this.id,
    required this.displayName,
    required this.formalName,
    this.title = "様",
    this.department,
    this.address,
  });

  String get invoiceName {
    String name = formalName;
    if (department != null && department!.isNotEmpty) {
      name = "$formalName\n$department";
    }
    return "$name $title";
  }

  Customer copyWith({
    String? id,
    String? displayName,
    String? formalName,
    String? title,
    String? department,
    String? address,
  }) {
    return Customer(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      formalName: formalName ?? this.formalName,
      title: title ?? this.title,
      department: department ?? this.department,
      address: address ?? this.address,
    );
  }
}
