import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/pipeline_stages.dart';
import '../models/project_model.dart';
import '../services/project_repository.dart';
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
  List<Project> _all = [];
  bool _loading = true;
  late TabController _typeTab;

  static const _types = [ProjectType.sales, ProjectType.development, ProjectType.other];
  static const _typeLabels = ['販売', '開発', 'その他'];

  @override
  void initState() {
    super.initState();
    _typeTab = TabController(length: 3, vsync: this);
    _typeTab.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _typeTab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await _repo.getAllProjects();
    if (!mounted) return;
    setState(() {
      _all = list;
      _loading = false;
    });
  }

  ProjectType get _currentType => _types[_typeTab.index];

  List<Project> _projectsForStage(String stage) => _all
      .where((p) => p.type == _currentType && p.pipelineStage == stage)
      .toList();

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
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('PJ1:案件管理'),
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新規案件',
            onPressed: _showCreateDialog,
          ),
        ],
        bottom: TabBar(
          controller: _typeTab,
          labelColor: Theme.of(context).colorScheme.onPrimary,
          unselectedLabelColor: Theme.of(context).colorScheme.onPrimary.withOpacity(0.6),
          indicatorColor: Theme.of(context).colorScheme.onPrimary,
          tabs: _typeLabels
              .map((l) => Tab(text: l))
              .toList(),
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
    final stages = stagesFor(_currentType);

    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      children: stages.map((stage) => _buildColumn(stage)).toList(),
    );
  }

  Widget _buildColumn(String stage) {
    final projects = _projectsForStage(stage);
    final isTerminal = isTerminalStage(stage);

    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // カラムヘッダー
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isTerminal
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    stage,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isTerminal
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (projects.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${projects.length}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // カード一覧
          Expanded(
            child: projects.isEmpty
                ? _buildEmptyColumn()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    itemCount: projects.length,
                    itemBuilder: (_, i) => _KanbanCard(
                      project: projects[i],
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ProjectDetailScreen(project: projects[i]),
                          ),
                        );
                        _load();
                      },
                      onStageChange: (newStage) async {
                        final updated =
                            projects[i].copyWith(pipelineStage: newStage);
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

  Widget _buildEmptyColumn() {
    return Center(
      child: Text(
        'なし',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
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

    return GestureDetector(
      onLongPress: () => _showStageSheet(context),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 案件名
                Text(
                  project.name,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
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
                // 金額
                if (project.totalAmount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '¥${fmt.format(project.totalAmount)}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: cs.primary),
                  ),
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
