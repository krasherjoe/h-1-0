import 'package:uuid/uuid.dart';

import '../models/time_log_model.dart';
import 'database_helper.dart';

/// 工数ログリポジトリ
class TimeLogRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<TimeLog>> getAll({int limit = 100}) async {
    final db = await _db.database;
    final rows = await db.query('time_logs', orderBy: 'date DESC, created_at DESC', limit: limit);
    return rows.map(TimeLog.fromMap).toList();
  }

  /// タスクの工数ログ一覧（日付降順）
  Future<List<TimeLog>> getByTask(String taskId) async {
    final db = await _db.database;
    final rows = await db.query(
      'time_logs',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'date DESC',
    );
    return rows.map(TimeLog.fromMap).toList();
  }

  /// 案件全体の工数ログ一覧（日付降順）
  Future<List<TimeLog>> getByProject(String projectId) async {
    final db = await _db.database;
    final rows = await db.query(
      'time_logs',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'date DESC',
    );
    return rows.map(TimeLog.fromMap).toList();
  }

  /// 工数ログを追加
  Future<TimeLog> add({
    required String taskId,
    required String projectId,
    required DateTime date,
    required double hours,
    String? memo,
  }) async {
    final db = await _db.database;
    final log = TimeLog(
      id: const Uuid().v4(),
      taskId: taskId,
      projectId: projectId,
      date: date,
      hours: hours,
      memo: memo,
      createdAt: DateTime.now(),
    );
    await db.insert('time_logs', log.toMap());
    return log;
  }

  /// 工数ログを削除
  Future<void> delete(String logId) async {
    final db = await _db.database;
    await db.delete('time_logs', where: 'id = ?', whereArgs: [logId]);
  }

  /// タスクの合計工数を取得
  Future<double> totalHoursForTask(String taskId) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(hours), 0) as total FROM time_logs WHERE task_id = ?',
      [taskId],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  /// 案件の合計工数を取得
  Future<double> totalHoursForProject(String projectId) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(hours), 0) as total FROM time_logs WHERE project_id = ?',
      [projectId],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }
}
