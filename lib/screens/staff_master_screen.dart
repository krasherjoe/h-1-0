import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/staff_model.dart';
import '../services/staff_repository.dart';
import '../widgets/generic_master_edit_dialog.dart';
import '../widgets/master_field_config.dart';

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
    final result = await showMasterEditDialog<Staff>(
      context: context,
      titleNew: '担当者を新規登録',
      titleEdit: '担当者を編集',
      existing: staff,
      fields: [
        MasterFieldConfig(
          key: 'name',
          label: '担当者名',
          hint: '例: 山田 太郎',
          required: true,
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
        MasterFieldConfig(
          key: 'tel',
          label: '電話番号',
          keyboardType: TextInputType.phone,
        ),
        MasterFieldConfig(
          key: 'email',
          label: 'メールアドレス',
          keyboardType: TextInputType.emailAddress,
        ),
        MasterFieldConfig(
          key: 'notes',
          label: '備考',
          maxLines: 3,
        ),
      ],
      initialValues: (s) => {
        'name': s?.name ?? '',
        'department': s?.department ?? '',
        'position': s?.position ?? '',
        'tel': s?.tel ?? '',
        'email': s?.email ?? '',
        'notes': s?.notes ?? '',
      },
      buildModel: (values) => Staff(
        id: staff?.id ?? const Uuid().v4(),
        name: values['name'],
        email: values['email']?.isEmpty ? null : values['email'],
        tel: values['tel']?.isEmpty ? null : values['tel'],
        department: values['department']?.isEmpty ? null : values['department'],
        position: values['position']?.isEmpty ? null : values['position'],
        notes: values['notes']?.isEmpty ? null : values['notes'],
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
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('ST:担当者マスター'),
        backgroundColor: Colors.teal,
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
                fillColor: Colors.white,
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
                          backgroundColor: Colors.teal.shade100,
                          child: const Icon(Icons.person, color: Colors.teal),
                        ),
                        title: Text(
                          s.name + (s.isHidden ? ' (非表示)' : ''),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: s.isHidden ? Colors.grey : Colors.black87,
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
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
