/// 工数ログモデル
/// タスクに対する実際の作業時間を記録する
class TimeLog {
  final String id;
  final String taskId;
  final String projectId;
  final DateTime date;
  final double hours;   // 例: 1.5 = 1時間30分
  final String? memo;
  final DateTime createdAt;

  const TimeLog({
    required this.id,
    required this.taskId,
    required this.projectId,
    required this.date,
    required this.hours,
    this.memo,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'project_id': projectId,
      'date': date.toIso8601String(),
      'hours': hours,
      'memo': memo,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory TimeLog.fromMap(Map<String, dynamic> map) {
    return TimeLog(
      id: map['id'] as String,
      taskId: map['task_id'] as String,
      projectId: map['project_id'] as String,
      date: DateTime.parse(map['date'] as String),
      hours: (map['hours'] as num).toDouble(),
      memo: map['memo'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  TimeLog copyWith({
    DateTime? date,
    double? hours,
    String? memo,
  }) {
    return TimeLog(
      id: id,
      taskId: taskId,
      projectId: projectId,
      date: date ?? this.date,
      hours: hours ?? this.hours,
      memo: memo ?? this.memo,
      createdAt: createdAt,
    );
  }
}
