import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/pipeline_stages.dart';
import '../models/project_model.dart';
import '../services/project_repository.dart';
import '../services/invoice_repository.dart';
import 'customer_picker_modal.dart';
import 'screen_pj2_project_detail.dart';

class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({super.key});

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen>
    with SingleTickerProviderStateMixin {
  final _repo = ProjectRepository();
  final _invoiceRepo = InvoiceRepository();
  final _searchCtrl = TextEditingController();
  List<Project> _all = [];
  Map<String, int> _projectSales = {};
  bool _loading = true;
  bool _searchOpen = false;
  bool _hideTerminal = true;
  late TabController _typeTab;

  static const _types = [ProjectType.sales, ProjectType.development, ProjectType.other];
  static const _typeLabels = ['販売', '開発', 'その他'];

  @override
  void initState() {
    super.initState();
    _typeTab = TabController(length: 3, vsync: this);
    _typeTab.addListener(() => setState(() {}));
    _searchCtrl.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _typeTab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await _repo.getAllProjects();
    final salesMap = <String, int>{};
    for (final project in list) {
      final sales = await _invoiceRepo.getTotalAmountByProjectId(project.id);
      salesMap[project.id] = sales;
    }
    if (!mounted) return;
    setState(() {
      _all = list;
      _projectSales = salesMap;
      _loading = false;
    });
  }

  ProjectType get _currentType => _types[_typeTab.index];

  String get _query => _searchCtrl.text.trim().toLowerCase();

  List<Project> _projectsForStage(String stage) {
    return _all.where((p) {
      if (p.type != _currentType) return false;
      if (p.pipelineStage != stage) return false;
      if (_query.isNotEmpty) {
        final name = p.name.toLowerCase();
        final customer = (p.customerName ?? '').toLowerCase();
        if (!name.contains(_query) && !customer.contains(_query)) return false;
      }
      return true;
    }).toList();
  }

  List<String> get _visibleStages {
    final stages = stagesFor(_currentType);
    if (!_hideTerminal) return stages;
    return stages.where((s) => !isTerminalStage(s)).toList();
  }

  Future<void> _showCreateDialog() async {
    final nameCtrl = TextEditingController();
    String? customerId;
    String? customerName;
    ProjectType type = _currentType;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('新規案件'),
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
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await _repo.createProject(
                  name: nameCtrl.text.trim(),
                  customerId: customerId,
                  customerName: customerName,
                  type: type,
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _load();
              },
              child: const Text('作成'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: _searchOpen
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: TextStyle(color: cs.onPrimary),
                cursorColor: cs.onPrimary,
                decoration: InputDecoration(
                  hintText: '案件名・得意先で検索...',
                  hintStyle: TextStyle(color: cs.onPrimary.withValues(alpha: 0.6)),
                  border: InputBorder.none,
                ),
              )
            : const Text('PJ1:案件管理'),
        foregroundColor: cs.onPrimary,
        actions: [
          IconButton(
            icon: Icon(_searchOpen ? Icons.close : Icons.search),
            tooltip: _searchOpen ? '検索を閉じる' : '検索',
            onPressed: () {
              setState(() {
                _searchOpen = !_searchOpen;
                if (!_searchOpen) _searchCtrl.clear();
              });
            },
          ),
          IconButton(
            icon: Icon(
              _hideTerminal ? Icons.visibility_off : Icons.visibility,
              color: _hideTerminal ? cs.onPrimary.withValues(alpha: 0.5) : cs.onPrimary,
            ),
            tooltip: _hideTerminal ? '入金済みを表示' : '入金済みを非表示',
            onPressed: () => setState(() => _hideTerminal = !_hideTerminal),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新規案件',
            onPressed: _showCreateDialog,
          ),
        ],
        bottom: TabBar(
          controller: _typeTab,
          labelColor: cs.onPrimary,
          unselectedLabelColor: cs.onPrimary.withValues(alpha: 0.6),
          indicatorColor: cs.onPrimary,
          tabs: _typeLabels.map((l) => Tab(text: l)).toList(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _buildKanban(),
            ),
    );
  }

  Widget _buildKanban() {
    final stages = _visibleStages;
    if (stages.isEmpty) {
      return Center(
        child: Text('表示するステージがありません',
            style: TextStyle(color: Theme.of(context).colorScheme.outlineVariant)),
      );
    }
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      children: stages.map((stage) => _buildColumn(stage)).toList(),
    );
  }

  Widget _buildColumn(String stage) {
    final projects = _projectsForStage(stage);
    final isTerminal = isTerminalStage(stage);
    final cs = Theme.of(context).colorScheme;
    final totalAmount = projects.fold<int>(0, (s, p) => s + (_projectSales[p.id] ?? 0));
    final fmt = NumberFormat('#,###');

    return SizedBox(
      width: 230,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isTerminal ? cs.primaryContainer : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        stage,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isTerminal ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (projects.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${projects.length}件',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold, color: cs.primary),
                        ),
                      ),
                  ],
                ),
                if (totalAmount > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '¥${fmt.format(totalAmount)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isTerminal ? cs.onPrimaryContainer : cs.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: projects.isEmpty
                ? Center(
                    child: Text('なし',
                        style: TextStyle(fontSize: 12, color: cs.outlineVariant)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    itemCount: projects.length,
                    itemBuilder: (_, i) => _KanbanCard(
                      project: projects[i],
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProjectDetailScreen(project: projects[i]),
                          ),
                        );
                        _load();
                      },
                      onStageChange: (newStage) async {
                        final updated = projects[i].copyWith(pipelineStage: newStage);
                        await _repo.updateProject(updated);
                        _load();
                      },
                      allStages: stagesFor(projects[i].type),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _KanbanCard extends StatelessWidget {
  final Project project;
  final VoidCallback onTap;
  final Future<void> Function(String) onStageChange;
  final List<String> allStages;

  const _KanbanCard({
    required this.project,
    required this.onTap,
    required this.onStageChange,
    required this.allStages,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final isOverdue = project.endDate != null &&
        project.endDate!.isBefore(now) &&
        project.status == ProjectStatus.active;
    final isDueSoon = !isOverdue &&
        project.endDate != null &&
        project.endDate!.difference(now).inDays <= 7 &&
        project.status == ProjectStatus.active;

    return GestureDetector(
      onLongPress: () => _showStageSheet(context),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: isOverdue
              ? BorderSide(color: cs.error.withValues(alpha: 0.6), width: 1.5)
              : isDueSoon
                  ? BorderSide(color: cs.tertiary.withValues(alpha: 0.6), width: 1.5)
                  : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ステータスバッジ行
                Row(
                  children: [
                    _StatusChip(status: project.status),
                    const Spacer(),
                    if (project.totalAmount > 0)
                      Text(
                        '¥${fmt.format(project.totalAmount)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                // 案件名
                Text(
                  project.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                // 得意先
                if (project.customerName != null) ...[
                  const SizedBox(height: 3),
                  Row(children: [
                    Icon(Icons.business, size: 11, color: cs.outlineVariant),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        project.customerName!,
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ],
                // 期限
                if (project.endDate != null) ...[
                  const SizedBox(height: 3),
                  Row(children: [
                    Icon(
                      isOverdue ? Icons.warning_amber_rounded : Icons.event,
                      size: 11,
                      color: isOverdue
                          ? cs.error
                          : isDueSoon
                              ? cs.tertiary
                              : cs.outlineVariant,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      isOverdue
                          ? '期限超過: ${DateFormat('MM/dd').format(project.endDate!)}'
                          : DateFormat('MM/dd').format(project.endDate!),
                      style: TextStyle(
                        fontSize: 11,
                        color: isOverdue
                            ? cs.error
                            : isDueSoon
                                ? cs.tertiary
                                : cs.outlineVariant,
                        fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ]),
                ],
                // 進捗バー
                if (project.progress > 0) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: project.progress / 100,
                          minHeight: 4,
                          backgroundColor: cs.surfaceContainerHighest,
                          color: project.progress >= 100 ? cs.tertiary : cs.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${project.progress}%',
                      style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
                    ),
                  ]),
                ],
                // ロングプレスヒント
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.open_with, size: 10, color: cs.outlineVariant),
                  const SizedBox(width: 2),
                  Text('長押しでステージ変更',
                      style: TextStyle(fontSize: 9, color: cs.outlineVariant)),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showStageSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'ステージを変更: ${project.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ...allStages.map((stage) {
                final isCurrent = stage == project.pipelineStage;
                return ListTile(
                  leading: isCurrent
                      ? Icon(Icons.radio_button_checked,
                          color: Theme.of(ctx).colorScheme.primary)
                      : const Icon(Icons.radio_button_unchecked),
                  title: Text(stage),
                  selected: isCurrent,
                  onTap: () async {
                    Navigator.pop(ctx);
                    if (!isCurrent) await onStageChange(stage);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final ProjectStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (label, bg, fg) = switch (status) {
      ProjectStatus.active    => ('進行中', cs.primaryContainer,    cs.onPrimaryContainer),
      ProjectStatus.won       => ('成約',   cs.tertiaryContainer,   cs.onTertiaryContainer),
      ProjectStatus.lost      => ('失注',   cs.errorContainer,      cs.onErrorContainer),
      ProjectStatus.suspended => ('保留',   cs.surfaceContainerHighest, cs.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
    );
  }
}
