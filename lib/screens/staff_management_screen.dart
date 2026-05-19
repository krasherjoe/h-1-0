import 'package:flutter/material.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final List<Map<String, dynamic>> _staffMembers = [];
  String _filterRole = 'all';

  @override
  void initState() {
    super.initState();
    _loadSampleData();
  }

  void _loadSampleData() {
    setState(() {
      _staffMembers.addAll([
        {
          'id': 'STF-001',
          'name': '山田太郎',
          'role': 'admin',
          'department': '営業部',
          'email': 'yamada@example.com',
          'status': 'active',
        },
        {
          'id': 'STF-002',
          'name': '佐藤花子',
          'role': 'staff',
          'department': '営業部',
          'email': 'sato@example.com',
          'status': 'active',
        },
        {
          'id': 'STF-003',
          'name': '鈴木一郎',
          'role': 'manager',
          'department': '管理部',
          'email': 'suzuki@example.com',
          'status': 'inactive',
        },
      ]);
    });
  }

  List<Map<String, dynamic>> get _filteredStaff {
    if (_filterRole == 'all') return _staffMembers;
    return _staffMembers.where((s) => s['role'] == _filterRole).toList();
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'admin':
        return '管理者';
      case 'manager':
        return 'マネージャー';
      case 'staff':
        return 'スタッフ';
      default:
        return role;
    }
  }

  Color _getRoleColor(String role, ColorScheme cs) {
    switch (role) {
      case 'admin':
        return cs.error;
      case 'manager':
        return cs.secondary;
      case 'staff':
        return cs.primary;
      default:
        return cs.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('SM:スタッフ管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('新規スタッフ登録（未実装）')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('全て')),
                ButtonSegment(value: 'admin', label: Text('管理者')),
                ButtonSegment(value: 'manager', label: Text('マネージャー')),
                ButtonSegment(value: 'staff', label: Text('スタッフ')),
              ],
              selected: {_filterRole},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _filterRole = newSelection.first;
                });
              },
            ),
          ),
          Expanded(
            child: _filteredStaff.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.badge, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        SizedBox(height: 16),
                        Text(
                          'スタッフ情報がありません',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredStaff.length,
                    itemBuilder: (context, index) {
                      final staff = _filteredStaff[index];
                      final isActive = staff['status'] == 'active';
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getRoleColor(staff['role'], Theme.of(context).colorScheme),
                            child: Text(
                              staff['name'].substring(0, 1),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                staff['name'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isActive ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (!isActive)
                                Chip(
                                  label: Text('無効'),
                                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  labelStyle: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('部署: ${staff['department']}'),
                              Text('ID: ${staff['id']}'),
                              Text('Email: ${staff['email']}'),
                              const SizedBox(height: 4),
                              Chip(
                                label: Text(_getRoleLabel(staff['role'])),
                                backgroundColor: _getRoleColor(staff['role'], Theme.of(context).colorScheme).withValues(alpha: 0.2),
                                labelStyle: TextStyle(
                                  color: _getRoleColor(staff['role'], Theme.of(context).colorScheme),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (value) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$value: ${staff['name']}（未実装）')),
                              );
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: '編集',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit),
                                    SizedBox(width: 8),
                                    Text('編集'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: '権限設定',
                                child: Row(
                                  children: [
                                    Icon(Icons.security),
                                    SizedBox(width: 8),
                                    Text('権限設定'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: isActive ? '無効化' : '有効化',
                                child: Row(
                                  children: [
                                    Icon(isActive ? Icons.block : Icons.check_circle),
                                    const SizedBox(width: 8),
                                    Text(isActive ? '無効化' : '有効化'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('権限設定画面へ（未実装）')),
          );
        },
        icon: const Icon(Icons.security),
        label: const Text('権限設定'),
      ),
    );
  }
}
