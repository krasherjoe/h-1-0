import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/staff_model.dart';
import '../services/staff_repository.dart';

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
    final isEdit = staff != null;
    final nameController = TextEditingController(text: staff?.name ?? '');
    final emailController = TextEditingController(text: staff?.email ?? '');
    final telController = TextEditingController(text: staff?.tel ?? '');
    final departmentController = TextEditingController(text: staff?.department ?? '');
    final positionController = TextEditingController(text: staff?.position ?? '');
    final notesController = TextEditingController(text: staff?.notes ?? '');

    final result = await showDialog<Staff>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final inset = MediaQuery.of(context).viewInsets.bottom;
          return MediaQuery.removeViewInsets(
            removeBottom: true,
            context: context,
            child: AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              title: Text(isEdit ? '担当者を編集' : '担当者を新規登録'),
              content: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(bottom: inset + 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: '担当者名',
                        hintText: '例: 山田 太郎',
                      ),
                    ),
                    TextField(
                      controller: departmentController,
                      decoration: const InputDecoration(
                        labelText: '部署',
                        hintText: '例: 営業部',
                      ),
                    ),
                    TextField(
                      controller: positionController,
                      decoration: const InputDecoration(
                        labelText: '役職',
                        hintText: '例: 課長',
                      ),
                    ),
                    TextField(
                      controller: telController,
                      decoration: const InputDecoration(labelText: '電話番号'),
                      keyboardType: TextInputType.phone,
                    ),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'メールアドレス'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: '備考'),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                TextButton(
                  onPressed: () {
                    if (nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('担当者名は必須です')),
                      );
                      return;
                    }
                    final newStaff = Staff(
                      id: staff?.id ?? const Uuid().v4(),
                      name: nameController.text.trim(),
                      email: emailController.text.trim().isEmpty
                          ? null
                          : emailController.text.trim(),
                      tel: telController.text.trim().isEmpty
                          ? null
                          : telController.text.trim(),
                      department: departmentController.text.trim().isEmpty
                          ? null
                          : departmentController.text.trim(),
                      position: positionController.text.trim().isEmpty
                          ? null
                          : positionController.text.trim(),
                      notes: notesController.text.trim().isEmpty
                          ? null
                          : notesController.text.trim(),
                      updatedAt: DateTime.now(),
                    );
                    Navigator.pop(context, newStaff);
                  },
                  child: const Text('保存'),
                ),
              ],
            ),
          );
        },
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
