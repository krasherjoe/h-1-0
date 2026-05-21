import 'package:uuid/uuid.dart';

import '../models/milestone_model.dart';
import 'database_helper.dart';

/// マイルストーンリポジトリ
class MilestoneRepository {
  final DatabaseHelper _db = DatabaseHelper();

  /// 案件のマイルストーン一覧を取得（sort_order順）
  Future<List<Milestone>> getByProject(String projectId) async {
    final db = await _db.database;
    final rows = await db.query(
      'milestones',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'sort_order ASC, created_at ASC',
    );
    return rows.map(Milestone.fromMap).toList();
  }

  /// マイルストーンを作成
  Future<Milestone> create({
    required String projectId,
    required String title,
    DateTime? dueDate,
    int sortOrder = 0,
  }) async {
    final db = await _db.database;
    final m = Milestone(
      id: const Uuid().v4(),
      projectId: projectId,
      title: title,
      dueDate: dueDate,
      sortOrder: sortOrder,
      createdAt: DateTime.now(),
    );
    await db.insert('milestones', m.toMap());
    return m;
  }

  /// マイルストーンを更新
  Future<void> update(Milestone m) async {
    final db = await _db.database;
    await db.update('milestones', m.toMap(), where: 'id = ?', whereArgs: [m.id]);
  }

  /// マイルストーンを完了/未完了トグル
  Future<Milestone> toggleComplete(Milestone m) async {
    final updated = m.copyWith(
      completedDate: m.isCompleted ? null : DateTime.now(),
    );
    await update(updated);
    return updated;
  }

  /// マイルストーンを削除（配下タスクも削除）
  Future<void> delete(String milestoneId) async {
    final db = await _db.database;
    await db.delete('tasks', where: 'milestone_id = ?', whereArgs: [milestoneId]);
    await db.delete('milestones', where: 'id = ?', whereArgs: [milestoneId]);
  }
}
