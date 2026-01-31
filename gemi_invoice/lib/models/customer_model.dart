import 'package:intl/intl.dart';

/// 顧客情報を管理するモデル
/// 将来的な Odoo 同期を見据えて、外部ID（odooId）を保持できるように設計
class Customer {
  final String id;             // ローカル管理用のID
  final int? odooId;           // Odoo上の res.partner ID (nullの場合は未同期)
  final String displayName;     // 電話帳からの表示名（検索用バッファ）
  final String formalName;      // 請求書に記載する正式名称（株式会社〜 など）
  final String? zipCode;        // 郵便番号
  final String? address;        // 住所
  final String? department;     // 部署名
  final String? title;          // 敬称 (様、御中など。デフォルトは御中)
  final DateTime lastUpdatedAt; // 最終更新日時

  Customer({
    required this.id,
    this.odooId,
    required this.displayName,
    required this.formalName,
    this.zipCode,
    this.address,
    this.department,
    this.title = '御中',
    DateTime? lastUpdatedAt,
  }) : this.lastUpdatedAt = lastUpdatedAt ?? DateTime.now();

  /// 請求書表示用のフルネームを取得
  String get invoiceName => department != null && department!.isNotEmpty
      ? "$formalName\n$department $title"
      : "$formalName $title";

  /// 状態更新のためのコピーメソッド
  Customer copyWith({
    String? id,
    int? odooId,
    String? displayName,
    String? formalName,
    String? zipCode,
    String? address,
    String? department,
    String? title,
    DateTime? lastUpdatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      odooId: odooId ?? this.odooId,
      displayName: displayName ?? this.displayName,
      formalName: formalName ?? this.formalName,
      zipCode: zipCode ?? this.zipCode,
      address: address ?? this.address,
      department: department ?? this.department,
      title: title ?? this.title,
      lastUpdatedAt: lastUpdatedAt ?? DateTime.now(),
    );
  }

  /// JSON変換 (ローカル保存・Odoo同期用)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'odoo_id': odooId,
      'display_name': displayName,
      'formal_name': formalName,
      'zip_code': zipCode,
      'address': address,
      'department': department,
      'title': title,
      'last_updated_at': lastUpdatedAt.toIso8601String(),
    };
  }

  /// JSONからモデルを生成
  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'],
      odooId: json['odoo_id'],
      displayName: json['display_name'],
      formalName: json['formal_name'],
      zipCode: json['zip_code'],
      address: json['address'],
      department: json['department'],
      title: json['title'] ?? '御中',
      lastUpdatedAt: DateTime.parse(json['last_updated_at']),
    );
  }
}
