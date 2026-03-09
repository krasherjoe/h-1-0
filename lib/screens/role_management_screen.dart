import 'package:flutter/material.dart';
import '../models/auth_models.dart';
import '../services/auth_repository.dart';

/// ロール管理画面
class RoleManagementScreen extends StatefulWidget {
  const RoleManagementScreen({super.key});

  @override
  State<RoleManagementScreen> createState() => _RoleManagementScreenState();
}

class _RoleManagementScreenState extends State<RoleManagementScreen> {
  final AuthRepository _authRepository = AuthRepository();
  List<Role> _roles = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedStatus = 'すべて';
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final roles = await _authRepository.getAllRoles();
      
      setState(() {
        _roles = roles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('データ読み込みに失敗しました: $e')),
        );
      }
    }
  }
  
  List<Role> get _filteredRoles {
    return _roles.where((role) {
      final matchesSearch = role.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                          role.description.toLowerCase().contains(_searchQuery.toLowerCase());
      
      final matchesStatus = _selectedStatus == 'すべて' ||
                          (_selectedStatus == '有効' && role.isActive) ||
                          (_selectedStatus == '無効' && !role.isActive);
      
      return matchesSearch && matchesStatus;
    }).toList();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('R1:ロール管理'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: '更新',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddRoleDialog,
            tooltip: 'ロール追加',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFilterSection(),
                Expanded(
                  child: _buildRoleList(),
                ),
              ],
            ),
    );
  }
  
  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade100,
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: '検索',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedStatus,
            decoration: const InputDecoration(
              labelText: 'ステータス',
              border: OutlineInputBorder(),
            ),
            items: const [
              'すべて',
              '有効',
              '無効',
            ].map((status) {
              return DropdownMenuItem(
                value: status,
                child: Text(status),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedStatus = value!;
              });
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildRoleList() {
    if (_filteredRoles.isEmpty) {
      return const Center(
        child: Text(
          'ロールが見つかりません',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _filteredRoles.length,
      itemBuilder: (context, index) {
        final role = _filteredRoles[index];
        return _buildRoleCard(role);
      },
    );
  }
  
  Widget _buildRoleCard(Role role) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: role.isActive ? Colors.purple : Colors.grey,
          child: Text(
            role.name.isNotEmpty ? role.name[0] : 'R',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          role.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(role.description),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                role.isActive ? Icons.toggle_on : Icons.toggle_off,
                color: role.isActive ? Colors.purple : Colors.grey,
              ),
              onPressed: () => _toggleRoleStatus(role),
              tooltip: role.isActive ? '無効化' : '有効化',
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showEditRoleDialog(role),
              tooltip: '編集',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteRole(role),
              tooltip: '削除',
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '権限一覧',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: role.permissions
                      .map((permission) => Chip(
                            label: Text(permission.displayName),
                            backgroundColor: Colors.blue.shade100,
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _showAddRoleDialog() {
    showDialog(
      context: context,
      builder: (context) => RoleDialog(
        onSave: (role) async {
          try {
            await _authRepository.createRole(role);
            await _loadData();
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ロールを作成しました')),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('作成に失敗しました: $e')),
              );
            }
          }
        },
      ),
    );
  }
  
  void _showEditRoleDialog(Role role) {
    showDialog(
      context: context,
      builder: (context) => RoleDialog(
        role: role,
        onSave: (updatedRole) async {
          try {
            await _authRepository.updateRole(updatedRole);
            await _loadData();
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ロールを更新しました')),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('更新に失敗しました: $e')),
              );
            }
          }
        },
      ),
    );
  }
  
  Future<void> _toggleRoleStatus(Role role) async {
    try {
      await _authRepository.toggleRoleStatus(role.id);
      await _loadData();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${role.name}を${role.isActive ? '無効化' : '有効化'}しました')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ステータス変更に失敗しました: $e')),
        );
      }
    }
  }
  
  Future<void> _deleteRole(Role role) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認'),
        content: Text('${role.name}を削除してもよろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await _authRepository.deleteRole(role.id);
        await _loadData();
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${role.name}を削除しました')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('削除に失敗しました: $e')),
          );
        }
      }
    }
  }
}

/// ロール編集ダイアログ
class RoleDialog extends StatefulWidget {
  final Role? role;
  final Function(Role) onSave;
  
  const RoleDialog({
    super.key,
    this.role,
    required this.onSave,
  });
  
  @override
  State<RoleDialog> createState() => _RoleDialogState();
}

class _RoleDialogState extends State<RoleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  bool _isActive = true;
  List<Permission> _selectedPermissions = [];
  
  @override
  void initState() {
    super.initState();
    if (widget.role != null) {
      _nameController.text = widget.role!.name;
      _descriptionController.text = widget.role!.description;
      _isActive = widget.role!.isActive;
      _selectedPermissions = widget.role!.permissions;
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final isEditing = widget.role != null;
    
    return AlertDialog(
      title: Text(isEditing ? 'ロール編集' : 'ロール追加'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'ロール名',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'ロール名を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '説明',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '説明を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('有効'),
                value: _isActive,
                onChanged: (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              const Text('権限', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...Permission.values.map((permission) {
                return CheckboxListTile(
                  title: Text(permission.displayName),
                  subtitle: Text(permission.description),
                  value: _selectedPermissions.contains(permission),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedPermissions.add(permission);
                      } else {
                        _selectedPermissions.remove(permission);
                      }
                    });
                  },
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: _saveRole,
          child: Text(isEditing ? '更新' : '作成'),
        ),
      ],
    );
  }
  
  void _saveRole() async {
    if (!_formKey.currentState!.validate()) return;
    
    final role = Role(
      id: widget.role?.id ?? '',
      name: _nameController.text,
      description: _descriptionController.text,
      permissions: _selectedPermissions,
      isActive: _isActive,
      createdAt: widget.role?.createdAt ?? DateTime.now(),
    );
    
    widget.onSave(role);
  }
}
