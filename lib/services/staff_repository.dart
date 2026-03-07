import 'package:sqflite/sqflite.dart';

import '../models/staff_model.dart';
import 'activity_log_repository.dart';
import 'database_helper.dart';

class StaffRepository {
  StaffRepository();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ActivityLogRepository _logRepo = ActivityLogRepository();

  Future<List<Staff>> fetchStaff({bool includeHidden = false}) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'staff',
      where: includeHidden ? null : 'is_hidden = 0',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map((row) => Staff.fromMap(row)).toList();
  }

  Future<void> saveStaff(Staff staff) async {
    final db = await _dbHelper.database;
    await db.insert(
      'staff',
      staff.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _logRepo.logAction(
      action: 'SAVE_STAFF',
      targetType: 'STAFF',
      targetId: staff.id,
      details: '担当者名: ${staff.name}, 部署: ${staff.department ?? "未設定"}',
    );
  }

  Future<void> deleteStaff(String staffId) async {
    final db = await _dbHelper.database;
    await db.delete('staff', where: 'id = ?', whereArgs: [staffId]);

    await _logRepo.logAction(
      action: 'DELETE_STAFF',
      targetType: 'STAFF',
      targetId: staffId,
      details: '担当者を削除しました',
    );
  }

  Future<void> setHidden(String id, bool hidden) async {
    final db = await _dbHelper.database;
    await db.update(
      'staff',
      {'is_hidden': hidden ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );

    await _logRepo.logAction(
      action: hidden ? 'HIDE_STAFF' : 'UNHIDE_STAFF',
      targetType: 'STAFF',
      targetId: id,
      details: hidden ? '担当者を非表示にしました' : '担当者を再表示しました',
    );
  }
}
