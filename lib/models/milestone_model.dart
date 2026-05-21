/// マイルストーンモデル
/// 案件内のフェーズ区切りを表す
class Milestone {
  final String id;
  final String projectId;
  final String title;
  final DateTime? dueDate;
  final DateTime? completedDate;
  final int sortOrder;
  final DateTime createdAt;

  const Milestone({
    required this.id,
    required this.projectId,
    required this.title,
    this.dueDate,
    this.completedDate,
    this.sortOrder = 0,
    required this.createdAt,
  });

  bool get isCompleted => completedDate != null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'title': title,
      'due_date': dueDate?.toIso8601String(),
      'completed_date': completedDate?.toIso8601String(),
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Milestone.fromMap(Map<String, dynamic> map) {
    return Milestone(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      title: map['title'] as String,
      dueDate: map['due_date'] != null ? DateTime.tryParse(map['due_date'] as String) : null,
      completedDate: map['completed_date'] != null ? DateTime.tryParse(map['completed_date'] as String) : null,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Milestone copyWith({
    String? title,
    DateTime? dueDate,
    DateTime? completedDate,
    int? sortOrder,
  }) {
    return Milestone(
      id: id,
      projectId: projectId,
      title: title ?? this.title,
      dueDate: dueDate ?? this.dueDate,
      completedDate: completedDate ?? this.completedDate,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
    );
  }
}
