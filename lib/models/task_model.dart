/// タスクステータス
enum TaskStatus {
  todo,   // 未着手
  doing,  // 進行中
  done,   // 完了
}

extension TaskStatusX on TaskStatus {
  String get displayName {
    switch (this) {
      case TaskStatus.todo:  return '未着手';
      case TaskStatus.doing: return '進行中';
      case TaskStatus.done:  return '完了';
    }
  }
}

/// タスクモデル
/// 案件内（マイルストーン配下または直属）のタスク
class Task {
  final String id;
  final String projectId;
  final String? milestoneId;      // nullなら案件直属
  final String title;
  final TaskStatus status;
  final DateTime? dueDate;
  final double estimatedHours;   // 見積工数（0=未設定）
  final int sortOrder;
  final DateTime createdAt;

  const Task({
    required this.id,
    required this.projectId,
    this.milestoneId,
    required this.title,
    this.status = TaskStatus.todo,
    this.dueDate,
    this.estimatedHours = 0,
    this.sortOrder = 0,
    required this.createdAt,
  });

  bool get isDone => status == TaskStatus.done;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'milestone_id': milestoneId,
      'title': title,
      'status': status.name,
      'due_date': dueDate?.toIso8601String(),
      'estimated_hours': estimatedHours,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    TaskStatus status = TaskStatus.todo;
    final rawStatus = map['status'] as String?;
    if (rawStatus != null) {
      try {
        status = TaskStatus.values.firstWhere((e) => e.name == rawStatus);
      } catch (_) {}
    }
    return Task(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      milestoneId: map['milestone_id'] as String?,
      title: map['title'] as String,
      status: status,
      dueDate: map['due_date'] != null ? DateTime.tryParse(map['due_date'] as String) : null,
      estimatedHours: (map['estimated_hours'] as num?)?.toDouble() ?? 0,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Task copyWith({
    String? title,
    TaskStatus? status,
    DateTime? dueDate,
    double? estimatedHours,
    String? milestoneId,
    int? sortOrder,
  }) {
    return Task(
      id: id,
      projectId: projectId,
      milestoneId: milestoneId ?? this.milestoneId,
      title: title ?? this.title,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
    );
  }
}
