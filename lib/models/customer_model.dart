import 'package:uuid/uuid.dart';

class Customer {
  final String id;
  final String displayName; // 表示用（電話帳名など）
  final String formalName;  // 請求書用正式名称
  final String? department; // 部署名
  final String? address;    // 住所

  Customer({
    required this.id,
    required this.displayName,
    required this.formalName,
    this.department,
    this.address,
  });

  String get invoiceName {
    if (department != null && department!.isNotEmpty) {
      return "$formalName\n$department";
    }
    return formalName;
  }

  Customer copyWith({
    String? id,
    String? displayName,
    String? formalName,
    String? department,
    String? address,
  }) {
    return Customer(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      formalName: formalName ?? this.formalName,
      department: department ?? this.department,
      address: address ?? this.address,
    );
  }
}
