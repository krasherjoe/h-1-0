import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'project_detail/status_badge.dart';

import '../models/customer_model.dart';
import '../models/invoice_models.dart';
import '../models/milestone_model.dart';
import '../models/pipeline_stages.dart';
import '../models/project_model.dart';
import '../models/task_model.dart';
import '../models/time_log_model.dart';
import '../services/customer_repository.dart';
import '../services/database_helper.dart';
import '../services/milestone_repository.dart';
import '../services/project_repository.dart';
import '../services/task_repository.dart';
import '../services/time_log_repository.dart';
import 'customer_picker_modal.dart';
import 'invoice_input_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  final Project project;
  const ProjectDetailScreen({super.key, required this.project});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  final _repo = ProjectRepository();
  final _db = DatabaseHelper();
  final _milestoneRepo = MilestoneRepository();
  final _taskRepo = TaskRepository();
  final _timeLogRepo = TimeLogRepository();

  late Project _project;
  late TabController _tabController;

  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _quotations = [];
  List<Milestone> _milestones = [];
  List<Task> _tasks = [];
  List<TimeLog> _timeLogs = [];

  bool _salesTableExists = false;
  bool _quotationsTableExists = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([_loadDocs(), _loadTasks(), _loadTimeLogs()]);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadDocs() async {
    final db = await _db.database;
    final inv = await db.query('invoices',
        where: 'project_id = ?', whereArgs: [_project.id], orderBy: 'date DESC');

    List<Map<String, dynamic>> sal = [];
    final salesExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='sales'");
    if (salesExists.isNotEmpty) {
      sal = await db.query('sales',
          where: 'project_id = ?', whereArgs: [_project.id], orderBy: 'date DESC');
    }

    List<Map<String, dynamic>> quo = [];
    final quotExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='quotations'");
    if (quotExists.isNotEmpty) {
      quo = await db.query('quotations',
          where: 'project_id = ?', whereArgs: [_project.id], orderBy: 'date DESC');
    }

    final fresh = await _repo.getProjectById(_project.id);
    if (!mounted) return;
    setState(() {
      _invoices = inv;
      _sales = sal;
      _quotations = quo;
      _salesTableExists = salesExists.isNotEmpty;
      _quotationsTableExists = quotExists.isNotEmpty;
      if (fresh != null) _project = fresh;
    });
  }

  Future<void> _loadTasks() async {
    final milestones = await _milestoneRepo.getByProject(_project.id);
    final tasks = await _taskRepo.getByProject(_project.id);
    if (!mounted) return;
    setState(() {
      _milestones = milestones;
      _tasks = tasks;
    });
  }

  Future<void> _loadTimeLogs() async {
    final logs = await _timeLogRepo.getByProject(_project.id);
    if (!mounted) return;
    setState(() => _timeLogs = logs);
  }

  // ===== パイプラインステージ変更 =====

  Future<void> _changeStage(String newStage) async {
    final updated = _project.copyWith(pipelineStage: newStage);
    await _repo.updateProject(updated);
    if (!mounted) return;
    setState(() => _project = updated);
  }

  // ===== 案件編集ダイアログ =====

  Future<void> _showEditDialog() async {
    final nameCtrl = TextEditingController(text: _project.name);
    final notesCtrl = TextEditingController(text: _project.notes ?? '');
    String? customerId = _project.customerId;
    String? customerName = _project.customerName;
    ProjectStatus status = _project.status;
    ProjectType type = _project.type;
    DateTime? startDate = _project.startDate;
    DateTime? endDate = _project.endDate;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('案件を編集'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '案件名 *'),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                // 種別選択
                const Text('種別', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                SegmentedButton<ProjectType>(
                  segments: ProjectType.values
                      .map((t) => ButtonSegment(value: t, label: Text(t.displayName)))
                      .toList(),
                  selected: {type},
                  onSelectionChanged: (s) => setSt(() => type = s.first),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.person_search),
                  label: Text(customerName ?? '得意先を選択（任意）'),
                  onPressed: () async {
                    await showModalBottomSheet<void>(
                      context: ctx,
                      isScrollControlled: true,
                      builder: (_) => CustomerPickerModal(
                        onCustomerSelected: (c) {
                          setSt(() {
                            customerId = c.id;
                            customerName = c.displayName;
                          });
                          Navigator.pop(ctx);
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                // ステータス
                DropdownButtonFormField<ProjectStatus>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'ステータス'),
                  items: ProjectStatus.values
                      .map((s) => DropdownMenuItem(value: s, child: Text(s.displayName)))
                      .toList(),
                  onChanged: (v) => setSt(() => status = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: '備考'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final updated = _project.copyWith(
                  name: nameCtrl.text.trim(),
                  customerId: customerId,
                  customerName: customerName,
                  status: status,
                  type: type,
                  startDate: startDate,
                  endDate: endDate,
                  notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                );
                await _repo.updateProject(updated);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _loadAll();
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirm() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('案件を削除'),
        content: Text('「${_project.name}」を削除しますか？\n紐づき伝票のリンクは解除されます。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.deleteProject(_project.id);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _showLinkDialog(String table, String tableLabel) async {
    final db = await _db.database;
    final tableExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?", [table]);
    if (tableExists.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$tableLabel テーブルが存在しません')),
      );
      return;
    }

    // 得意先名マッピングを取得
    final customerRows = await db.query('customers', columns: ['id', 'display_name']);
    final customerMap = {for (final r in customerRows) r['id'] as String: r['display_name'] as String};

    final hasProjectCustomer = _project.customerId != null;

    if (!mounted) return;

    final fmt = NumberFormat('#,###');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final searchCtrl = TextEditingController();
          bool showAllCustomers = false;
          bool isSearching = false;

          Future<List<Map<String, dynamic>>> loadRows() async {
            final where = StringBuffer('project_id IS NULL');
            final whereArgs = <Object?>[];

            // 案件の得意先で絞り込み（全顧客表示OFF時）
            if (!showAllCustomers && hasProjectCustomer) {
              where.write(' AND customer_id = ?');
              whereArgs.add(_project.customerId);
            }

            final rows = await db.query(
              table,
              columns: [
                'id',
                'date',
                'customer_id',
                if (table == 'invoices') 'subject',
                if (table == 'invoices') 'total_amount',
                if (table == 'sales') 'document_number',
                if (table == 'sales') 'total',
                if (table == 'quotations') 'subject',
                if (table == 'quotations') 'total_amount',
              ],
              where: where.toString(),
              whereArgs: whereArgs.isEmpty ? null : whereArgs,
              orderBy: 'date DESC',
              limit: 200,
            );
            return rows;
          }

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            minChildSize: 0.3,
            maxChildSize: 0.95,
            builder: (ctx, scroll) => FutureBuilder<List<Map<String, dynamic>>>(
              future: loadRows(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = snap.data ?? [];

                // 検索フィルタ
                var filtered = rows;
                if (searchCtrl.text.isNotEmpty) {
                  final q = searchCtrl.text.toLowerCase();
                  filtered = rows.where((r) {
                    final label = table == 'sales'
                        ? (r['document_number'] as String? ?? '')
                        : (r['subject'] as String? ?? '');
                    final custId = r['customer_id'] as String?;
                    final custName = customerMap[custId] ?? '';
                    return label.toLowerCase().contains(q) ||
                        custName.toLowerCase().contains(q);
                  }).toList();
                }

                return Column(
                  children: [
                    // ヘッダー
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$tableLabelを紐付け',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text('${filtered.length}件',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    // 検索バー
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: TextField(
                        controller: searchCtrl,
                        decoration: InputDecoration(
                          hintText: '顧客名・件名で検索',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    searchCtrl.clear();
                                    setSt(() {});
                                  },
                                )
                              : null,
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (_) => setSt(() {}),
                      ),
                    ),
                    // 顧客絞り込みトグル
                    if (hasProjectCustomer)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.filter_alt,
                                size: 16,
                                color: Theme.of(ctx).colorScheme.primary),
                            const SizedBox(width: 6),
                            Text(
                              showAllCustomers
                                  ? '全顧客の$tableLabelを表示中'
                                  : '${_project.customerName ?? "この顧客"}の$tableLabelのみ',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(ctx).colorScheme.primary),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => setSt(() => showAllCustomers = !showAllCustomers),
                              child: Text(showAllCustomers ? '顧客で絞る' : '全顧客表示'),
                            ),
                          ],
                        ),
                      ),
                    // リスト
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.folder_open,
                                      size: 48,
                                      color: Theme.of(ctx).colorScheme.outlineVariant),
                                  const SizedBox(height: 8),
                                  Text(
                                    searchCtrl.text.isNotEmpty
                                        ? '検索条件に一致する$tableLabelがありません'
                                        : '紐付け可能な$tableLabelがありません',
                                    style: TextStyle(
                                        color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: scroll,
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final r = filtered[i];
                                final id = r['id'] as String;
                                final date = r['date'] as String? ?? '';
                                final label = table == 'sales'
                                    ? (r['document_number'] as String? ?? id.substring(0, 8))
                                    : (r['subject'] as String? ?? id.substring(0, 8));
                                final amount = table == 'sales'
                                    ? (r['total'] as int? ?? 0)
                                    : (r['total_amount'] as int? ?? 0);
                                final custId = r['customer_id'] as String?;
                                final custName = customerMap[custId] ?? '不明な顧客';

                                return ListTile(
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                                  title: Text(label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 14)),
                                  subtitle: Row(
                                    children: [
                                      Icon(Icons.business,
                                          size: 12,
                                          color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                                      const SizedBox(width: 3),
                                      Text(custName,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(ctx)
                                                  .colorScheme
                                                  .onSurfaceVariant)),
                                      const SizedBox(width: 8),
                                      Text(date.length >= 10 ? date.substring(0, 10) : date,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(ctx)
                                                  .colorScheme
                                                  .onSurfaceVariant)),
                                    ],
                                  ),
                                  trailing: Text('¥${fmt.format(amount)}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Theme.of(ctx).colorScheme.primary)),
                                  onTap: () async {
                                    Navigator.pop(ctx);
                                    await _repo.linkDocument(
                                        projectId: _project.id,
                                        table: table,
                                        documentId: id);
                                    _loadDocs();
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  // ===== タスク操作 =====

  Future<void> _showAddMilestoneDialog() async {
    final ctrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('マイルストーン追加'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'マイルストーン名 *'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await _milestoneRepo.create(
                projectId: _project.id,
                title: ctrl.text.trim(),
                sortOrder: _milestones.length,
              );
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _loadTasks();
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddTaskDialog({String? milestoneId}) async {
    final ctrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('タスク追加'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'タスク名 *'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              final tasksInScope = _tasks
                  .where((t) => t.milestoneId == milestoneId)
                  .length;
              await _taskRepo.create(
                projectId: _project.id,
                milestoneId: milestoneId,
                title: ctrl.text.trim(),
                sortOrder: tasksInScope,
              );
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _loadTasks();
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddTimeLogDialog(Task task) async {
    double hours = 1.0;
    final memoCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('工数入力\n${task.title}',
              style: const TextStyle(fontSize: 14)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${hours.toStringAsFixed(1)} 時間',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Slider(
                value: hours,
                min: 0.5,
                max: 12,
                divisions: 23,
                label: '${hours.toStringAsFixed(1)}h',
                onChanged: (v) => setSt(() => hours = v),
              ),
              TextField(
                controller: memoCtrl,
                decoration: const InputDecoration(labelText: 'メモ（任意）'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
            ElevatedButton(
              onPressed: () async {
                await _timeLogRepo.add(
                  taskId: task.id,
                  projectId: _project.id,
                  date: DateTime.now(),
                  hours: hours,
                  memo: memoCtrl.text.trim().isEmpty ? null : memoCtrl.text.trim(),
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _loadTimeLogs();
              },
              child: const Text('記録'),
            ),
          ],
        ),
      ),
    );
  }

  // ===== BUILD =====

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('PJ2:${_project.name}', overflow: TextOverflow.ellipsis),
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(icon: const Icon(Icons.edit), onPressed: _showEditDialog),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'delete') _showDeleteConfirm();
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'delete',
                child: Text('案件を削除',
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.onPrimary,
          unselectedLabelColor: Theme.of(context).colorScheme.onPrimary.withOpacity(0.6),
          indicatorColor: Theme.of(context).colorScheme.onPrimary,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline), text: '概要'),
            Tab(icon: Icon(Icons.checklist), text: 'タスク'),
            Tab(icon: Icon(Icons.timer_outlined), text: '工数'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildTaskTab(),
                _buildTimeLogTab(),
              ],
            ),
    );
  }

  // ===== 概要タブ =====

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoCard(),
          const SizedBox(height: 12),
          _buildStageSelector(),
          const SizedBox(height: 12),
          _buildDocSection(
            label: '請求書',
            icon: Icons.receipt_long,
            table: 'invoices',
            docs: _invoices,
            amountKey: 'total_amount',
            labelKey: 'subject',
            onCreate: () => _createInvoiceFromProject(DocumentType.invoice),
          ),
          if (_quotationsTableExists) ...[
            const SizedBox(height: 8),
            _buildDocSection(
              label: '見積',
              icon: Icons.description,
              table: 'quotations',
              docs: _quotations,
              amountKey: 'total_amount',
              labelKey: 'subject',
              onCreate: () => _createInvoiceFromProject(DocumentType.estimation),
            ),
          ],
          if (_salesTableExists) ...[
            const SizedBox(height: 8),
            _buildDocSection(
              label: '売上伝票',
              icon: Icons.point_of_sale,
              table: 'sales',
              docs: _sales,
              amountKey: 'total',
              labelKey: 'document_number',
              onCreate: () => _createInvoiceFromProject(DocumentType.delivery),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final fmt = NumberFormat('#,###');
    final dateFmt = DateFormat('yyyy/MM/dd');
    final statusColor = _statusColorOf(_project.status, Theme.of(context).colorScheme);
    final doneCount = _tasks.where((t) => t.isDone).length;
    final totalCount = _tasks.length;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 種別バッジ
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_project.type.displayName,
                      style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSecondaryContainer)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_project.name,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
                ProjectStatusBadge(status: _project.status, color: statusColor),
              ],
            ),
            if (_project.customerName != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.business,
                    size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(_project.customerName!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ]),
            ],
            if (_project.startDate != null || _project.endDate != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.calendar_month,
                    size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  [
                    if (_project.startDate != null) dateFmt.format(_project.startDate!),
                    if (_project.endDate != null)
                      '〜 ${dateFmt.format(_project.endDate!)}',
                  ].join(' '),
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ]),
            ],
            if (_project.notes != null && _project.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(_project.notes!,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  maxLines: 2),
            ],
            // タスク進捗バー
            if (totalCount > 0) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: doneCount / totalCount,
                      minHeight: 8,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('$doneCount/$totalCount',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ]),
            ],
            if (_project.totalAmount > 0) ...[
              const Divider(height: 16),
              Row(children: [
                const Text('案件合計', style: TextStyle(fontSize: 12)),
                const Spacer(),
                Text('¥${fmt.format(_project.totalAmount)}',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary)),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStageSelector() {
    final stages = stagesFor(_project.type);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ステージ',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: stages.map((stage) {
                  final isSelected = stage == _project.pipelineStage;
                  final idx = stages.indexOf(stage);
                  final currentIdx = stages.indexOf(_project.pipelineStage);
                  final isPast = idx < currentIdx;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => _changeStage(stage),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : isPast
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withOpacity(0.5)
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                          border: isSelected
                              ? null
                              : Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isPast)
                              Icon(Icons.check_circle,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.primary),
                            if (isPast) const SizedBox(width: 4),
                            Text(
                              stage,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : isPast
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocSection({
    required String label,
    required IconData icon,
    required String table,
    required List<Map<String, dynamic>> docs,
    required String amountKey,
    required String labelKey,
    VoidCallback? onCreate,
  }) {
    final fmt = NumberFormat('#,###');
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(label),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (docs.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${docs.length}件',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary)),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right),
          ],
        ),
        children: [
          ...docs.map((doc) {
            final id = doc['id'] as String;
            final rawDate = doc['date'] as String? ?? '';
            final date = rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;
            final lbl = doc[labelKey] as String? ?? id.substring(0, 8);
            final amount = doc[amountKey] as int? ?? 0;
            final statusInfo =
                _docStatusInfo(table, doc, Theme.of(context).colorScheme);
            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              title: Row(
                children: [
                  Expanded(
                    child: Text(lbl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14)),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusInfo.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusInfo.color.withOpacity(0.5)),
                    ),
                    child: Text(statusInfo.label,
                        style: TextStyle(
                            fontSize: 11,
                            color: statusInfo.color,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              subtitle: Text('発行日: $date', style: const TextStyle(fontSize: 12)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('¥${fmt.format(amount)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  IconButton(
                    icon: Icon(Icons.link_off,
                        size: 18,
                        color: Theme.of(context).colorScheme.error),
                    tooltip: '紐付け解除',
                    onPressed: () async {
                      await _repo.unlinkDocument(table: table, documentId: id);
                      _loadDocs();
                    },
                  ),
                ],
              ),
            );
          }),
          if (onCreate != null)
            ListTile(
              leading: Icon(Icons.add_circle_outline,
                  color: Theme.of(context).colorScheme.primary),
              title: Text('$labelを新規作成'),
              onTap: onCreate,
            ),
          ListTile(
            leading: Icon(Icons.add_link,
                color: Theme.of(context).colorScheme.primary),
            title: Text('$labelを紐付け'),
            onTap: () => _showLinkDialog(table, label),
          ),
        ],
      ),
    );
  }

  Future<void> _createInvoiceFromProject(DocumentType type) async {
    Customer? preselected;
    if (_project.customerId != null) {
      final repo = CustomerRepository();
      preselected = (await repo.getAllCustomers())
          .where((c) => c.id == _project.customerId)
          .firstOrNull;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceInputForm(
          onInvoiceGenerated: (invoice, path) {},
          initialDocumentType: type,
          startViewMode: false,
          showNewBadge: true,
          preselectedCustomer: preselected,
        ),
      ),
    );
    if (!mounted) return;
    _loadDocs();
  }

  // ===== タスクタブ =====

  Widget _buildTaskTab() {
    final freeTasks = _tasks.where((t) => t.milestoneId == null).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // マイルストーン別タスク
        ..._milestones.map((m) => _buildMilestoneSection(m)),
        // マイルストーンなしのタスク
        if (freeTasks.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildFreeTaskSection(freeTasks),
        ],
        const SizedBox(height: 16),
        // 操作ボタン
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.flag_outlined),
                label: const Text('マイルストーン追加'),
                onPressed: _showAddMilestoneDialog,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add_task),
                label: const Text('タスク追加'),
                onPressed: () => _showAddTaskDialog(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMilestoneSection(Milestone m) {
    final mTasks = _tasks.where((t) => t.milestoneId == m.id).toList();
    final doneCount = mTasks.where((t) => t.isDone).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // マイルストーンヘッダー
          ListTile(
            leading: GestureDetector(
              onTap: () async {
                final updated = await _milestoneRepo.toggleComplete(m);
                setState(() {
                  final idx = _milestones.indexWhere((x) => x.id == m.id);
                  if (idx >= 0) _milestones[idx] = updated;
                });
              },
              child: Icon(
                m.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                color: m.isCompleted
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
            ),
            title: Text(m.title,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    decoration:
                        m.isCompleted ? TextDecoration.lineThrough : null)),
            subtitle: mTasks.isNotEmpty
                ? Text('$doneCount/${mTasks.length} 完了',
                    style: const TextStyle(fontSize: 12))
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  tooltip: 'タスクを追加',
                  onPressed: () => _showAddTaskDialog(milestoneId: m.id),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.error),
                  tooltip: '削除',
                  onPressed: () async {
                    await _milestoneRepo.delete(m.id);
                    _loadTasks();
                  },
                ),
              ],
            ),
          ),
          // タスクリスト
          ...mTasks.map((t) => _buildTaskTile(t)),
        ],
      ),
    );
  }

  Widget _buildFreeTaskSection(List<Task> tasks) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('その他のタスク',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          ...tasks.map((t) => _buildTaskTile(t)),
        ],
      ),
    );
  }

  Widget _buildTaskTile(Task t) {
    final statusColor = _taskStatusColor(t.status);
    return ListTile(
      leading: GestureDetector(
        onTap: () async {
          final next = t.status == TaskStatus.done ? TaskStatus.todo : TaskStatus.done;
          final updated = await _taskRepo.changeStatus(t, next);
          setState(() {
            final idx = _tasks.indexWhere((x) => x.id == t.id);
            if (idx >= 0) _tasks[idx] = updated;
          });
        },
        child: Icon(
          t.isDone ? Icons.check_box : Icons.check_box_outline_blank,
          color: t.isDone
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline,
        ),
      ),
      title: Text(t.title,
          style: TextStyle(
              decoration: t.isDone ? TextDecoration.lineThrough : null,
              color: t.isDone
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : null)),
      subtitle: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(t.status.displayName,
                style:
                    TextStyle(fontSize: 10, color: statusColor)),
          ),
          if (t.estimatedHours > 0) ...[
            const SizedBox(width: 6),
            Text('${t.estimatedHours.toStringAsFixed(1)}h見積',
                style: const TextStyle(fontSize: 11)),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.timer_outlined, size: 18),
            tooltip: '工数入力',
            onPressed: () => _showAddTimeLogDialog(t),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                size: 18, color: Theme.of(context).colorScheme.error),
            onPressed: () async {
              await _taskRepo.delete(t.id);
              _loadTasks();
              _loadTimeLogs();
            },
          ),
        ],
      ),
    );
  }

  // ===== 工数タブ =====

  Widget _buildTimeLogTab() {
    if (_timeLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text('工数ログがまだありません',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text('タスクタブの ⏱ ボタンから記録できます',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    final dateFmt = DateFormat('MM/dd');
    double totalHours = _timeLogs.fold(0, (sum, l) => sum + l.hours);

    // タスク名マップ
    final taskMap = {for (final t in _tasks) t.id: t.title};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 合計カード
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.access_time,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                const Text('合計工数',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${totalHours.toStringAsFixed(1)} 時間',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // ログ一覧
        ..._timeLogs.map((log) {
          final taskName = taskMap[log.taskId] ?? '不明なタスク';
          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: CircleAvatar(
                radius: 22,
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  '${log.hours.toStringAsFixed(1)}h',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer),
                ),
              ),
              title: Text(taskName,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                [
                  dateFmt.format(log.date),
                  if (log.memo != null) log.memo!,
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.error),
                onPressed: () async {
                  await _timeLogRepo.delete(log.id);
                  _loadTimeLogs();
                },
              ),
            ),
          );
        }),
      ],
    );
  }

  // ===== ヘルパー =====

  Color _taskStatusColor(TaskStatus s) {
    final cs = Theme.of(context).colorScheme;
    switch (s) {
      case TaskStatus.todo:  return cs.outline;
      case TaskStatus.doing: return cs.secondary;
      case TaskStatus.done:  return cs.primary;
    }
  }

  ({String label, Color color}) _docStatusInfo(
      String table, Map<String, dynamic> doc, ColorScheme cs) {
    if (table == 'invoices' || table == 'quotations') {
      final isDraft = doc['is_draft'] == 1 || doc['is_draft'] == true;
      if (isDraft) return (label: '下書き', color: cs.onSurfaceVariant);
      return (label: '正式発行済', color: cs.primary);
    }
    return (label: '完了', color: cs.tertiary);
  }

  Color _statusColorOf(ProjectStatus s, ColorScheme cs) {
    switch (s) {
      case ProjectStatus.active:    return cs.primary;
      case ProjectStatus.won:       return cs.primary;
      case ProjectStatus.lost:      return cs.error;
      case ProjectStatus.suspended: return cs.secondary;
    }
  }
}
