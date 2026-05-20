import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/staff_model.dart';
import '../services/staff_repository.dart';
import '../widgets/master_field_config.dart';
import '../widgets/rich_master_edit_sheet.dart';

class StaffMasterScreen extends StatefulWidget {
  final bool selectionMode;
  final bool showHidden;

  const StaffMasterScreen({
    super.key,
    this.selectionMode = false,
    this.showHidden = false,
  });

  @override
  State<StaffMasterScreen> createState() => _StaffMasterScreenState();
}

class StaffPreviewCard extends StatelessWidget {
  const StaffPreviewCard({
    super.key,
    required this.name,
    required this.department,
    required this.position,
    required this.tel,
    required this.email,
    required this.notes,
  });

  final String name;
  final String department;
  final String position;
  final String tel;
  final String email;
  final String notes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = [
      if (department.isNotEmpty) department,
      if (position.isNotEmpty) position,
    ].join(' / ');
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  child: Icon(Icons.person, color: Theme.of(context).colorScheme.primary, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? '担当者名未入力' : name,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        info.isEmpty ? '部署/役職: 未入力' : info,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _InfoRow(icon: Icons.phone, label: tel.isEmpty ? '電話未設定' : tel),
                _InfoRow(icon: Icons.mail, label: email.isEmpty ? 'メール未設定' : email),
              ],
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('社内メモ', style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(notes, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _StaffMasterScreenState extends State<StaffMasterScreen> {
  final StaffRepository _repo = StaffRepository();
  final TextEditingController _searchController = TextEditingController();

  List<Staff> _staffList = [];
  List<Staff> _filtered = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _repo.fetchStaff(includeHidden: widget.showHidden);
    if (!mounted) return;
    setState(() {
      _staffList = data;
      _isLoading = false;
      _applyFilter();
    });
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _staffList.where((s) {
        return s.name.toLowerCase().contains(query) ||
            (s.department?.toLowerCase().contains(query) ?? false) ||
            (s.position?.toLowerCase().contains(query) ?? false);
      }).toList();
      if (!widget.showHidden) {
        _filtered = _filtered.where((s) => !s.isHidden).toList();
      }
    });
  }

  Future<void> _showEditDialog({Staff? staff}) async {
    final result = await showRichMasterEditSheet<Staff>(
      context: context,
      titleNew: '担当者を新規登録',
      titleEdit: '担当者を編集',
      existing: staff,
      sections: [
        RichMasterSection(
          title: '基本情報',
          description: '氏名・部署・役職を設定します',
          fields: const [
            MasterFieldConfig(
              key: 'name',
              label: '担当者名',
              hint: '例: 山田 太郎',
              required: true,
              flex: 2,
            ),
            MasterFieldConfig(
              key: 'department',
              label: '部署',
              hint: '例: 営業部',
            ),
            MasterFieldConfig(
              key: 'position',
              label: '役職',
              hint: '例: 課長',
            ),
          ],
        ),
        RichMasterSection(
          title: '連絡手段',
          description: '内線/携帯・メールを登録します',
          fields: const [
            MasterFieldConfig(
              key: 'tel',
              label: '電話番号',
              hint: '例: 03-1234-5678',
              keyboardType: TextInputType.phone,
            ),
            MasterFieldConfig(
              key: 'email',
              label: 'メールアドレス',
              hint: '例: staff@example.jp',
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        RichMasterSection(
          title: '社内メモ',
          description: '得意分野や注意事項を共有できます',
          fields: const [
            MasterFieldConfig(
              key: 'notes',
              label: '備考',
              maxLines: 4,
              flex: 2,
            ),
          ],
        ),
      ],
      initialValuesBuilder: (s) => {
        'name': s?.name ?? '',
        'department': s?.department ?? '',
        'position': s?.position ?? '',
        'tel': s?.tel ?? '',
        'email': s?.email ?? '',
        'notes': s?.notes ?? '',
      },
      previewBuilder: (ctx, controller) => StaffPreviewCard(
        name: controller.valueOf('name'),
        department: controller.valueOf('department'),
        position: controller.valueOf('position'),
        tel: controller.valueOf('tel'),
        email: controller.valueOf('email'),
        notes: controller.valueOf('notes'),
      ),
      buildModel: (values) => Staff(
        id: staff?.id ?? const Uuid().v4(),
        name: values['name']?.trim() ?? '',
        email: values['email']?.trim().isEmpty ?? true ? null : values['email']!.trim(),
        tel: values['tel']?.trim().isEmpty ?? true ? null : values['tel']!.trim(),
        department:
            values['department']?.trim().isEmpty ?? true ? null : values['department']!.trim(),
        position: values['position']?.trim().isEmpty ?? true ? null : values['position']!.trim(),
        notes: values['notes']?.trim().isEmpty ?? true ? null : values['notes']!.trim(),
        updatedAt: DateTime.now(),
      ),
    );

    if (result != null && mounted) {
      await _repo.saveStaff(result);
      if (widget.selectionMode && mounted) {
        Navigator.pop(context, result);
      } else {
        _loadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('ST:担当者マスター'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '担当者名・部署・役職で検索',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: theme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (_) => _applyFilter(),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _filtered.isEmpty
                ? const Center(child: Text('担当者が見つかりません'))
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 80, top: 8),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final s = _filtered[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Icon(Icons.person, color: theme.colorScheme.primary),
                        ),
                        title: Text(
                          s.name + (s.isHidden ? ' (非表示)' : ''),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: s.isHidden ? theme.hintColor : theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                        subtitle: Text(
                          [
                            if (s.department != null) s.department!,
                            if (s.position != null) s.position!,
                          ].join(' / '),
                        ),
                        onTap: () {
                          if (widget.selectionMode) {
                            if (s.isHidden) return;
                            Navigator.pop(context, s);
                          } else {
                            _showEditDialog(staff: s);
                          }
                        },
                        trailing: widget.selectionMode
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _showEditDialog(staff: s),
                              ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: theme.cardColor,
        child: const Icon(Icons.add),
      ),
    );
  }
}
