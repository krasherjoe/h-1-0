import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/pipeline_stages.dart';
import '../models/project_model.dart';
import 'activity_log_repository.dart';
import 'database_helper.dart';

/// 案件グループリポジトリ
/// 複数の伝票（請求書・見積・売上等）を1案件として束ねる管理を提供する
class ProjectRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ActivityLogRepository _logRepo = ActivityLogRepository();

  // ===== CRUD =====

  /// 全案件を取得（ステータス降順: active→won→lost→suspended）
  Future<List<Project>> getAllProjects() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'projects',
      orderBy: "CASE status WHEN 'active' THEN 0 WHEN 'won' THEN 1 WHEN 'suspended' THEN 2 ELSE 3 END, updated_at DESC",
    );
    return rows.map((r) => Project.fromMap(r)).toList();
  }

  /// 得意先IDで案件を取得
  Future<List<Project>> getProjectsByCustomer(String customerId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'projects',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'updated_at DESC',
    );
    return rows.map((r) => Project.fromMap(r)).toList();
  }

  /// IDで案件を1件取得
  Future<Project?> getProjectById(String id) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'projects',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Project.fromMap(rows.first);
  }

  /// 案件を新規作成
  Future<Project> createProject({
    required String name,
    String? customerId,
    String? customerName,
    ProjectStatus status = ProjectStatus.active,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    ProjectType type = ProjectType.sales,
    String? pipelineStage,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final stage = pipelineStage ?? stagesFor(type).first;
    final project = Project(
      id: const Uuid().v4(),
      name: name,
      customerId: customerId,
      customerName: customerName,
      status: status,
      startDate: startDate,
      endDate: endDate,
      notes: notes,
      totalAmount: 0,
      createdAt: now,
      updatedAt: now,
      type: type,
      pipelineStage: stage,
    );

    await db.insert('projects', project.toMap());
    await _logRepo.logAction(
      action: 'CREATE_PROJECT',
      targetType: 'PROJECT',
      targetId: project.id,
      details: '案件名: ${project.name}',
    );
    return project;
  }

  /// 案件を更新
  Future<void> updateProject(Project project) async {
    final db = await _dbHelper.database;
    final updated = project.copyWith(updatedAt: DateTime.now());
    await db.update(
      'projects',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [project.id],
    );
    await _logRepo.logAction(
      action: 'UPDATE_PROJECT',
      targetType: 'PROJECT',
      targetId: project.id,
      details: '案件名: ${project.name}, ステータス: ${project.status.displayName}',
    );
  }

  /// 案件を削除（伝票の project_id はNULLに）
  Future<void> deleteProject(String projectId) async {
    final db = await _dbHelper.database;

    // 紐づく工数ログ・タスク・マイルストーンを削除（project_id NOT NULL のため）
    await _safeDelete(db, 'time_logs', projectId);
    await _safeDelete(db, 'tasks', projectId);
    await _safeDelete(db, 'milestones', projectId);

    // 紐づく伝票の project_id を NULL にリセット（テーブルが存在しない場合はスキップ）
    for (final table in _linkedTables) {
      await _safeNullProjectId(db, table, projectId);
    }

    await db.delete('projects', where: 'id = ?', whereArgs: [projectId]);
    await _logRepo.logAction(
      action: 'DELETE_PROJECT',
      targetType: 'PROJECT',
      targetId: projectId,
      details: '案件削除・マイルストーン/タスク/工数ログも削除、伝票のproject_idをNULLに',
    );
  }

  // ===== 内部ヘルパー =====

  /// テーブルが存在しない場合はスキップして project_id を NULL に更新
  Future<void> _safeNullProjectId(Database db, String table, String projectId) async {
    try {
      await db.update(
        table,
        {'project_id': null},
        where: 'project_id = ?',
        whereArgs: [projectId],
      );
    } catch (_) {
      // テーブルが存在しない DB バージョンではスキップ
    }
  }

  /// テーブルが存在しない場合はスキップして project_id に紐づくレコードを削除
  Future<void> _safeDelete(Database db, String table, String projectId) async {
    try {
      await db.delete(table, where: 'project_id = ?', whereArgs: [projectId]);
    } catch (_) {
      // テーブルが存在しない DB バージョンではスキップ
    }
  }

  // ===== 伝票リンク =====

  static const _linkedTables = ['invoices', 'quotations', 'sales', 'purchase_orders'];

  /// 伝票を案件に紐づける
  Future<void> linkDocument({
    required String projectId,
    required String table,
    required String documentId,
  }) async {
    assert(_linkedTables.contains(table), '未対応テーブル: $table');
    final db = await _dbHelper.database;
    await db.update(
      table,
      {'project_id': projectId, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [documentId],
    );

    // 自動ステージ更新：伝票種別に応じてパイプラインを進める
    const stageAdvanceMap = {
      'quotations': '見積',
      'sales': '納品/発送',
      'invoices': '請求',
    };
    final suggestedStage = stageAdvanceMap[table];
    if (suggestedStage != null) {
      final projRows = await db.query(
        'projects',
        columns: ['type', 'pipeline_stage'],
        where: 'id = ?',
        whereArgs: [projectId],
        limit: 1,
      );
      if (projRows.isNotEmpty) {
        final typeStr = projRows.first['type'] as String? ?? 'sales';
        final currentStage = projRows.first['pipeline_stage'] as String? ?? '';
        final type = typeStr == 'development'
            ? ProjectType.development
            : typeStr == 'sales'
                ? ProjectType.sales
                : ProjectType.other;
        final stages = stagesFor(type);
        final currentIdx = stages.indexOf(currentStage);
        final newIdx = stages.indexOf(suggestedStage);
        // 新ステージがパイプライン上で現在より後ろなら進める
        if (newIdx != -1 && (currentIdx == -1 || newIdx > currentIdx)) {
          await db.update(
            'projects',
            {
              'pipeline_stage': suggestedStage,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [projectId],
          );
        }
      }
    }

    await _recalcTotalAmount(projectId);
    await _logRepo.logAction(
      action: 'LINK_DOCUMENT',
      targetType: 'PROJECT',
      targetId: projectId,
      details: '$table / $documentId の案件紐付け',
    );
  }

  /// 伝票の案件紐づけを解除
  Future<void> unlinkDocument({
    required String table,
    required String documentId,
  }) async {
    assert(_linkedTables.contains(table), '未対応テーブル: $table');
    final db = await _dbHelper.database;

    final rows = await db.query(table, columns: ['project_id'], where: 'id = ?', whereArgs: [documentId], limit: 1);
    final projectId = rows.isNotEmpty ? rows.first['project_id'] as String? : null;

    await db.update(
      table,
      {'project_id': null, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [documentId],
    );

    if (projectId != null) await _recalcTotalAmount(projectId);
  }

  // ===== 案件サマリー =====

  /// 案件に紐づく全伝票IDとテーブルを取得
  Future<Map<String, List<String>>> getLinkedDocumentIds(String projectId) async {
    final db = await _dbHelper.database;
    final result = <String, List<String>>{};

    for (final table in _linkedTables) {
      final rows = await db.query(
        table,
        columns: ['id'],
        where: 'project_id = ?',
        whereArgs: [projectId],
      );
      if (rows.isNotEmpty) {
        result[table] = rows.map((r) => r['id'] as String).toList();
      }
    }
    return result;
  }

  /// 案件に紐づく請求書IDリストを取得
  Future<List<String>> getInvoiceIds(String projectId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'invoices',
      columns: ['id'],
      where: 'project_id = ?',
      whereArgs: [projectId],
    );
    return rows.map((r) => r['id'] as String).toList();
  }

  /// 案件の合計金額を請求書の total_amount から再計算して保存
  Future<void> _recalcTotalAmount(String projectId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(total_amount), 0) as total FROM invoices WHERE project_id = ? AND is_draft = 0',
      [projectId],
    );
    final total = (result.first['total'] as num?)?.toInt() ?? 0;
    await db.update(
      'projects',
      {'total_amount': total, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [projectId],
    );
  }

  /// 案件の合計金額を外部から強制再計算
  Future<void> recalcTotalAmount(String projectId) => _recalcTotalAmount(projectId);
}
