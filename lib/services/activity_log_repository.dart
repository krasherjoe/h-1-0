import '../models/activity_log_model.dart';
import 'database_helper.dart';

class ActivityLogRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<void> log(ActivityLog log) async {
    final db = await _dbHelper.database;
    await db.insert('activity_logs', log.toMap());
  }

  Future<void> logAction({
    required String action,
    required String targetType,
    String? targetId,
    String? details,
  }) async {
    final activity = ActivityLog.create(
      action: action,
      targetType: targetType,
      targetId: targetId,
      details: details,
    );
    await log(activity);
  }

  Future<List<ActivityLog>> getAllLogs({int limit = 100}) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'activity_logs',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return List.generate(maps.length, (i) => ActivityLog.fromMap(maps[i]));
  }
}
