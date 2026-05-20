import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/project_model.dart';
import '../services/customer_repository.dart';
import '../services/project_repository.dart';
import 'customer_picker_modal.dart';
import 'screen_pj2_project_detail.dart';

class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({super.key});

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  final _repo = ProjectRepository();
  List<Project> _all = [];
  List<Project> _filtered = [];
  ProjectStatus? _filterStatus; // null = 全て
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _repo.getAllProjects();
    if (!mounted) return;
    setState(() {
      _all = list;
      _applyFilter();
      _loading = false;
    });
  }

  void _applyFilter() {
    _filtered = _filterStatus == null
        ? List.of(_all)
        : _all.where((p) => p.status == _filterStatus).toList();
  }

  Color _statusColor(ProjectStatus s, BuildContext ctx) {
    switch (s) {
      case ProjectStatus.active:    return Theme.of(ctx).colorScheme.primary;
      case ProjectStatus.won:       return Theme.of(ctx).colorScheme.primary;
      case ProjectStatus.lost:      return Theme.of(ctx).colorScheme.error;
      case ProjectStatus.suspended: return Theme.of(ctx).colorScheme.secondary;
    }
  }

  Future<void> _showCreateDialog() async {
    final nameCtrl = TextEditingController();
    String? customerId;
    String? customerName;
    ProjectStatus status = ProjectStatus.active;
    DateTime? startDate;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('新規案件'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '案件名 *'),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.person_search),
                  label: Text(customerName ?? '得意先を選択（任意）'),
                  onPressed: () async {
                    showModalBottomSheet<void>(
                      context: ctx,
                      isScrollControlled: true,
                      builder: (_) => CustomerPickerModal(
                        onCustomerSelected: (c) {
                          Navigator.pop(ctx);
                          setSt(() {
                            customerId = c.id;
                            customerName = c.displayName;
                          });
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ProjectStatus>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'ステータス'),
                  items: ProjectStatus.values
                      .map((s) => DropdownMenuItem(value: s, child: Text(s.displayName)))
                      .toList(),
                  onChanged: (v) => setSt(() => status = v ?? status),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(startDate != null
                      ? '開始: ${DateFormat('yyyy/MM/dd').format(startDate!)}'
                      : '開始日を選択（任意）'),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setSt(() => startDate = d);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await _repo.createProject(
                  name: nameCtrl.text.trim(),
                  customerId: customerId,
                  customerName: customerName,
                  status: status,
                  startDate: startDate,
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              },
              child: const Text('作成'),
            ),
          ],
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('PJ1:案件管理'),
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('新規案件'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Column(
        children: [
          _buildFilterBar(context),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? _buildEmpty(context)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _ProjectCard(
                            project: _filtered[i],
                            statusColor: _statusColor(_filtered[i].status, context),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProjectDetailScreen(project: _filtered[i]),
                                ),
                              );
                              _load();
                            },
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext ctx) {
    final statuses = [null, ...ProjectStatus.values];
    return Container(
      color: Theme.of(ctx).colorScheme.primaryContainer.withValues(alpha: 0.2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: statuses.map((s) {
            final label = s == null ? '全て' : s.displayName;
            final selected = _filterStatus == s;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(label),
                selected: selected,
                selectedColor: s == null ? Theme.of(ctx).colorScheme.primaryContainer.withValues(alpha: 0.5) : _statusColor(s, ctx).withValues(alpha: 0.3),
                checkmarkColor: Theme.of(ctx).colorScheme.primary,
                onSelected: (_) {
                  setState(() {
                    _filterStatus = s;
                    _applyFilter();
                  });
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext ctx) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open, size: 64, color: Theme.of(ctx).colorScheme.outlineVariant),
          const SizedBox(height: 12),
          Text(
            _filterStatus == null ? '案件がまだありません' : '${_filterStatus!.displayName}の案件はありません',
            style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final Color statusColor;
  final VoidCallback onTap;

  const _ProjectCard({
    required this.project,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final dateFmt = DateFormat('yyyy/MM/dd');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      project.name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      project.status.displayName,
                      style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              if (project.customerName != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.business, size: 13, color: Theme.of(context).colorScheme.outlineVariant),
                    const SizedBox(width: 4),
                    Text(
                      project.customerName!,
                      style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  if (project.startDate != null) ...[
                    Icon(Icons.calendar_month, size: 13, color: Theme.of(context).colorScheme.outlineVariant),
                    const SizedBox(width: 4),
                    Text(
                      dateFmt.format(project.startDate!),
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    if (project.endDate != null) ...[
                      Text(' 〜 ', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outlineVariant)),
                      Text(
                        dateFmt.format(project.endDate!),
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                    const Spacer(),
                  ] else
                    const Spacer(),
                  if (project.totalAmount > 0)
                    Text(
                      '¥${fmt.format(project.totalAmount)}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
