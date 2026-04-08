class ProductCategory {
  final String id;
  final String name;
  final String? description;
  final bool isActive;
  final DateTime createdAt;

  ProductCategory({
    required this.id,
    required this.name,
    this.description,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ProductCategory.fromMap(Map<String, dynamic> map) {
    return ProductCategory(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      isActive: (map['is_active'] ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  ProductCategory copyWith({
    String? id,
    String? name,
    String? description,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return ProductCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
