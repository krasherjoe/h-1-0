import 'package:flutter/foundation.dart';

@immutable
class Staff {
  const Staff({
    required this.id,
    required this.name,
    this.email,
    this.tel,
    this.department,
    this.position,
    this.notes,
    this.isHidden = false,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? email;
  final String? tel;
  final String? department;
  final String? position;
  final String? notes;
  final bool isHidden;
  final DateTime updatedAt;

  Staff copyWith({
    String? id,
    String? name,
    String? email,
    String? tel,
    String? department,
    String? position,
    String? notes,
    bool? isHidden,
    DateTime? updatedAt,
  }) {
    return Staff(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      tel: tel ?? this.tel,
      department: department ?? this.department,
      position: position ?? this.position,
      notes: notes ?? this.notes,
      isHidden: isHidden ?? this.isHidden,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Staff.fromMap(Map<String, Object?> map) {
    return Staff(
      id: map['id'] as String,
      name: map['name'] as String? ?? '-',
      email: map['email'] as String?,
      tel: map['tel'] as String?,
      department: map['department'] as String?,
      position: map['position'] as String?,
      notes: map['notes'] as String?,
      isHidden: (map['is_hidden'] as int? ?? 0) == 1,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'tel': tel,
      'department': department,
      'position': position,
      'notes': notes,
      'is_hidden': isHidden ? 1 : 0,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
