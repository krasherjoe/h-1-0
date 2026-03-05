import 'package:flutter/foundation.dart';

@immutable
class Supplier {
  const Supplier({
    required this.id,
    required this.name,
    this.contactPerson,
    this.email,
    this.tel,
    this.address,
    this.closingDay,
    this.paymentSiteDays = 30,
    this.notes,
    this.isHidden = false,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? contactPerson;
  final String? email;
  final String? tel;
  final String? address;
  final int? closingDay;
  final int paymentSiteDays;
  final String? notes;
  final bool isHidden;
  final DateTime updatedAt;

  Supplier copyWith({
    String? id,
    String? name,
    String? contactPerson,
    String? email,
    String? tel,
    String? address,
    int? closingDay,
    int? paymentSiteDays,
    String? notes,
    bool? isHidden,
    DateTime? updatedAt,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      email: email ?? this.email,
      tel: tel ?? this.tel,
      address: address ?? this.address,
      closingDay: closingDay ?? this.closingDay,
      paymentSiteDays: paymentSiteDays ?? this.paymentSiteDays,
      notes: notes ?? this.notes,
      isHidden: isHidden ?? this.isHidden,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Supplier.fromMap(Map<String, Object?> map) {
    return Supplier(
      id: map['id'] as String,
      name: map['name'] as String? ?? '-',
      contactPerson: map['contact_person'] as String?,
      email: map['email'] as String?,
      tel: map['tel'] as String?,
      address: map['address'] as String?,
      closingDay: map['closing_day'] as int?,
      paymentSiteDays: map['payment_site_days'] as int? ?? 30,
      notes: map['notes'] as String?,
      isHidden: (map['is_hidden'] as int? ?? 0) == 1,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'contact_person': contactPerson,
      'email': email,
      'tel': tel,
      'address': address,
      'closing_day': closingDay,
      'payment_site_days': paymentSiteDays,
      'notes': notes,
      'is_hidden': isHidden ? 1 : 0,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
