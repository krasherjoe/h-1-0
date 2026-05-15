/// 案件ステータス
enum ProjectStatus {
  active,    // 進行中
  won,       // 成約
  lost,      // 失注
  suspended, // 保留
}

extension ProjectStatusX on ProjectStatus {
  String get displayName {
    switch (this) {
      case ProjectStatus.active:    return '進行中';
      case ProjectStatus.won:       return '成約';
      case ProjectStatus.lost:      return '失注';
      case ProjectStatus.suspended: return '保留';
    }
  }
}

/// 案件グループモデル
/// 複数の伝票（請求書・見積・売上等）を1つの案件として束ねる
class Project {
  final String id;
  final String name;         // 案件名
  final String? customerId;  // 得意先ID
  final String? customerName; // 得意先名（表示用キャッシュ）
  final ProjectStatus status;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? notes;
  final int totalAmount;     // 合計金額（集計キャッシュ）
  final DateTime createdAt;
  final DateTime updatedAt;

  const Project({
    required this.id,
    required this.name,
    this.customerId,
    this.customerName,
    this.status = ProjectStatus.active,
    this.startDate,
    this.endDate,
    this.notes,
    this.totalAmount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'customer_id': customerId,
      'customer_name': customerName,
      'status': status.name,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'notes': notes,
      'total_amount': totalAmount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Project.fromMap(Map<String, dynamic> map) {
    ProjectStatus status = ProjectStatus.active;
    final statusRaw = map['status'] as String?;
    if (statusRaw != null) {
      try {
        status = ProjectStatus.values.firstWhere((e) => e.name == statusRaw);
      } catch (_) {}
    }

    return Project(
      id: map['id'] as String,
      name: map['name'] as String,
      customerId: map['customer_id'] as String?,
      customerName: map['customer_name'] as String?,
      status: status,
      startDate: map['start_date'] != null ? DateTime.tryParse(map['start_date'] as String) : null,
      endDate: map['end_date'] != null ? DateTime.tryParse(map['end_date'] as String) : null,
      notes: map['notes'] as String?,
      totalAmount: map['total_amount'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Project copyWith({
    String? id,
    String? name,
    String? customerId,
    String? customerName,
    ProjectStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    int? totalAmount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      notes: notes ?? this.notes,
      totalAmount: totalAmount ?? this.totalAmount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
