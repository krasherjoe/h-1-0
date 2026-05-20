import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/project_model.dart';
import '../services/database_helper.dart';
import '../services/project_repository.dart';
import 'customer_picker_modal.dart';

class ProjectDetailScreen extends StatefulWidget {
  final Project project;
  const ProjectDetailScreen({super.key, required this.project});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final _repo = ProjectRepository();
  final _db = DatabaseHelper();
  late Project _project;

  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _quotations = [];
  bool _salesTableExists = false;
  bool _quotationsTableExists = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _loadDocs();
  }

  Future<void> _loadDocs() async {
    setState(() => _loading = true);
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
      _loading = false;
    });
  }

  Future<void> _showEditDialog() async {
    final nameCtrl = TextEditingController(text: _project.name);
    final notesCtrl = TextEditingController(text: _project.notes ?? '');
    String? customerId = _project.customerId;
    String? customerName = _project.customerName;
    ProjectStatus status = _project.status;
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
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '案件名 *'),
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 14),
                        label: Text(startDate != null
                            ? DateFormat('MM/dd').format(startDate!)
                            : '開始日'),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: startDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (d != null) setSt(() => startDate = d);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.event, size: 14),
                        label: Text(endDate != null
                            ? DateFormat('MM/dd').format(endDate!)
                            : '終了日'),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: endDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (d != null) setSt(() => endDate = d);
                        },
                      ),
                    ),
                  ],
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
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await _repo.updateProject(_project.copyWith(
                  name: nameCtrl.text.trim(),
                  customerId: customerId,
                  customerName: customerName,
                  status: status,
                  startDate: startDate,
                  endDate: endDate,
                  notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                ));
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    _loadDocs();
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

    final rows = await db.query(
      table,
      columns: ['id', 'date', if (table == 'invoices') 'subject', if (table == 'invoices') 'total_amount',
                if (table == 'sales') 'document_number', if (table == 'sales') 'total',
                if (table == 'quotations') 'subject', if (table == 'quotations') 'total_amount'],
      where: 'project_id IS NULL',
      orderBy: 'date DESC',
      limit: 50,
    );

    if (!mounted) return;
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('紐づけ可能な$tableLabelがありません')),
      );
      return;
    }

    final fmt = NumberFormat('#,###');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (ctx, scroll) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('$tableLabelを案件に紐づける',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                controller: scroll,
                itemCount: rows.length,
                itemBuilder: (_, i) {
                  final r = rows[i];
                  final id = r['id'] as String;
                  final date = r['date'] as String? ?? '';
                  final label = table == 'sales'
                      ? (r['document_number'] as String? ?? id.substring(0, 8))
                      : (r['subject'] as String? ?? id.substring(0, 8));
                  final amount = table == 'sales'
                      ? (r['total'] as int? ?? 0)
                      : (r['total_amount'] as int? ?? 0);
                  return ListTile(
                    title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(date.length >= 10 ? date.substring(0, 10) : date),
                    trailing: Text('¥${fmt.format(amount)}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(ctx).colorScheme.primary)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _repo.linkDocument(
                          projectId: _project.id, table: table, documentId: id);
                      _loadDocs();
                    },
                  );
                },
              ),
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
                PopupMenuItem(value: 'delete', child: Text('案件を削除', style: TextStyle(color: Theme.of(ctx).colorScheme.error))),
              ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDocs,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildInfoCard(),
                  const SizedBox(height: 12),
                  _buildDocSection(
                    label: '請求書',
                    icon: Icons.receipt_long,
                    table: 'invoices',
                    docs: _invoices,
                    amountKey: 'total_amount',
                    labelKey: 'subject',
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
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard() {
    final fmt = NumberFormat('#,###');
    final dateFmt = DateFormat('yyyy/MM/dd');
    final statusColor = _statusColorOf(_project.status, Theme.of(context).colorScheme);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(_project.name,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
                _StatusBadge(status: _project.status, color: statusColor),
              ],
            ),
            if (_project.customerName != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.business, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(_project.customerName!, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ]),
            ],
            if (_project.startDate != null || _project.endDate != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.calendar_month, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  [
                    if (_project.startDate != null) dateFmt.format(_project.startDate!),
                    if (_project.endDate != null) '〜 ${dateFmt.format(_project.endDate!)}',
                  ].join(' '),
style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ]),
              ],
              if (_project.notes != null && _project.notes!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(_project.notes!,
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant), maxLines: 2),
            ],
            if (_project.totalAmount > 0) ...[
              const Divider(height: 16),
              Row(children: [
                const Text('案件合計', style: TextStyle(fontSize: 12)),
                const Spacer(),
                Text('¥${fmt.format(_project.totalAmount)}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
              ]),
            ],
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
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
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
            final statusInfo = _docStatusInfo(table, doc, Theme.of(context).colorScheme);
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              title: Row(
                children: [
                  Expanded(
                    child: Text(lbl, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusInfo.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusInfo.color.withOpacity(0.5)),
                    ),
                    child: Text(statusInfo.label,
                        style: TextStyle(fontSize: 11, color: statusInfo.color, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              subtitle: Text('発行日: $date', style: const TextStyle(fontSize: 12)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('¥${fmt.format(amount)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  IconButton(
                    icon: Icon(Icons.link_off, size: 18, color: Theme.of(context).colorScheme.error),
                    tooltip: '紐づけ解除',
                    onPressed: () async {
                      await _repo.unlinkDocument(table: table, documentId: id);
                      _loadDocs();
                    },
                  ),
                ],
              ),
            );
          }),
          ListTile(
            leading: Icon(Icons.add_link, color: Theme.of(context).colorScheme.primary),
            title: Text('$labelを紐づける'),
            onTap: () => _showLinkDialog(table, label),
          ),
        ],
      ),
    );
  }

  ({String label, Color color}) _docStatusInfo(String table, Map<String, dynamic> doc, ColorScheme cs) {
    if (table == 'invoices' || table == 'quotations') {
      final isDraft = doc['is_draft'] == 1 || doc['is_draft'] == true;
      if (isDraft) {
        return (label: '下書き', color: cs.onSurfaceVariant);
      }
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

class _StatusBadge extends StatelessWidget {
  final ProjectStatus status;
  final Color color;
  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(status.displayName,
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
    );
  }
}
