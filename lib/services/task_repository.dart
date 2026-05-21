import 'package:uuid/uuid.dart';

import '../models/task_model.dart';
import 'database_helper.dart';

/// タスクリポジトリ
class TaskRepository {
  final DatabaseHelper _db = DatabaseHelper();

  /// 案件のタスク一覧（マイルストーン別、sort_order順）
  Future<List<Task>> getByProject(String projectId) async {
    final db = await _db.database;
    final rows = await db.query(
      'tasks',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'sort_order ASC, created_at ASC',
    );
    return rows.map(Task.fromMap).toList();
  }

  /// マイルストーン配下のタスク一覧
  Future<List<Task>> getByMilestone(String milestoneId) async {
    final db = await _db.database;
    final rows = await db.query(
      'tasks',
      where: 'milestone_id = ?',
      whereArgs: [milestoneId],
      orderBy: 'sort_order ASC, created_at ASC',
    );
    return rows.map(Task.fromMap).toList();
  }

  /// タスクを作成
  Future<Task> create({
    required String projectId,
    String? milestoneId,
    required String title,
    DateTime? dueDate,
    double estimatedHours = 0,
    int sortOrder = 0,
  }) async {
    final db = await _db.database;
    final t = Task(
      id: const Uuid().v4(),
      projectId: projectId,
      milestoneId: milestoneId,
      title: title,
      dueDate: dueDate,
      estimatedHours: estimatedHours,
      sortOrder: sortOrder,
      createdAt: DateTime.now(),
    );
    await db.insert('tasks', t.toMap());
    return t;
  }

  /// タスクを更新
  Future<void> update(Task t) async {
    final db = await _db.database;
    await db.update('tasks', t.toMap(), where: 'id = ?', whereArgs: [t.id]);
  }

  /// ステータス変更
  Future<Task> changeStatus(Task t, TaskStatus status) async {
    final updated = t.copyWith(status: status);
    await update(updated);
    return updated;
  }

  /// タスクを削除（工数ログも削除）
  Future<void> delete(String taskId) async {
    final db = await _db.database;
    await db.delete('time_logs', where: 'task_id = ?', whereArgs: [taskId]);
    await db.delete('tasks', where: 'id = ?', whereArgs: [taskId]);
  }

  /// 案件の完了率 (0.0〜1.0) を計算
  Future<double> calcProgress(String projectId) async {
    final db = await _db.database;
    final all = await db.query('tasks', columns: ['status'], where: 'project_id = ?', whereArgs: [projectId]);
    if (all.isEmpty) return 0;
    final done = all.where((r) => r['status'] == 'done').length;
    return done / all.length;
  }
}
