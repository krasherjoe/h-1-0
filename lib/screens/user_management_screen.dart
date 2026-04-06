import 'package:flutter/material.dart';
import '../models/auth_models.dart';
import '../services/auth_repository.dart';

/// ユーザー管理画面
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final AuthRepository _authRepository = AuthRepository();
  List<User> _users = [];
  List<Role> _roles = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedDepartment = 'すべて';
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
      final users = await _authRepository.getAllUsers();
      final roles = await _authRepository.getAllRoles();

      setState(() {
        _users = users;
        _roles = roles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('データ読み込みに失敗しました: $e')));
      }
    }
  }

  List<User> get _filteredUsers {
    return _users.where((user) {
      final matchesSearch =
          user.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user.username.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user.email.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesDepartment =
          _selectedDepartment == 'すべて' ||
          user.department == _selectedDepartment;
      final matchesStatus =
          _selectedStatus == 'すべて' ||
          (_selectedStatus == '有効' && user.isActive) ||
          (_selectedStatus == '無効' && !user.isActive);

      return matchesSearch && matchesDepartment && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('U1:ユーザー管理'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: '更新',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddUserDialog,
            tooltip: 'ユーザー追加',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFilterSection(),
                Expanded(child: _buildUserList()),
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
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedDepartment,
                  decoration: const InputDecoration(
                    labelText: '部署',
                    border: OutlineInputBorder(),
                  ),
                  items: ['すべて', '営業部', '経理部', '倉庫部', 'システム部', '総務部'].map((
                    department,
                  ) {
                    return DropdownMenuItem(
                      value: department,
                      child: Text(department),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedDepartment = value!;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'ステータス',
                    border: OutlineInputBorder(),
                  ),
                  items: const ['すべて', '有効', '無効'].map((status) {
                    return DropdownMenuItem(value: status, child: Text(status));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value!;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    if (_filteredUsers.isEmpty) {
      return const Center(
        child: Text(
          'ユーザーが見つかりません',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        return _buildUserCard(user);
      },
    );
  }

  Widget _buildUserCard(User user) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: user.isActive ? Colors.green : Colors.grey,
          child: Text(
            user.fullName.isNotEmpty ? user.fullName[0] : 'U',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          user.fullName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('@${user.username}'),
            Text(user.email),
            Text('${user.department}・${user.position}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showEditUserDialog(user),
              tooltip: '編集',
            ),
            IconButton(
              icon: Icon(
                user.isActive ? Icons.toggle_on : Icons.toggle_off,
                color: user.isActive ? Colors.green : Colors.grey,
              ),
              onPressed: () => _toggleUserStatus(user),
              tooltip: user.isActive ? '無効化' : '有効化',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteUser(user),
              tooltip: '削除',
            ),
          ],
        ),
      ),
    );
  }

  void _showAddUserDialog() {
    showDialog(
      context: context,
      builder: (context) => UserDialog(
        roles: _roles,
        onSave: (user) async {
          try {
            await _authRepository.createUser(user);
            await _loadData();
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('ユーザーを作成しました')));
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('作成に失敗しました: $e')));
            }
          }
        },
      ),
    );
  }

  void _showEditUserDialog(User user) {
    showDialog(
      context: context,
      builder: (context) => UserDialog(
        user: user,
        roles: _roles,
        onSave: (updatedUser) async {
          try {
            await _authRepository.updateUser(updatedUser);
            await _loadData();
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('ユーザーを更新しました')));
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('更新に失敗しました: $e')));
            }
          }
        },
      ),
    );
  }

  Future<void> _toggleUserStatus(User user) async {
    try {
      await _authRepository.toggleUserStatus(user.id);
      await _loadData();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${user.fullName}を${user.isActive ? '無効化' : '有効化'}しました',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ステータス変更に失敗しました: $e')));
      }
    }
  }

  Future<void> _deleteUser(User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認'),
        content: Text('${user.fullName}を削除してもよろしいですか？'),
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
        await _authRepository.deleteUser(user.id);
        await _loadData();

        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('${user.fullName}を削除しました')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('削除に失敗しました: $e')));
        }
      }
    }
  }
}

/// ユーザー編集ダイアログ
class UserDialog extends StatefulWidget {
  final User? user;
  final List<Role> roles;
  final Function(User) onSave;

  const UserDialog({
    super.key,
    this.user,
    required this.roles,
    required this.onSave,
  });

  @override
  State<UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<UserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _departmentController = TextEditingController();
  final _positionController = TextEditingController();

  String _selectedDepartment = '営業部';
  String _selectedPosition = '一般';
  bool _isActive = true;
  List<String> _selectedRoleIds = [];

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _usernameController.text = widget.user!.username;
      _emailController.text = widget.user!.email;
      _fullNameController.text = widget.user!.fullName;
      _phoneNumberController.text = widget.user!.phoneNumber ?? '';
      _selectedDepartment = widget.user!.department;
      _selectedPosition = widget.user!.position;
      _isActive = widget.user!.isActive;
      _selectedRoleIds = widget.user!.roleIds;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _fullNameController.dispose();
    _phoneNumberController.dispose();
    _departmentController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.user != null;

    return AlertDialog(
      title: Text(isEditing ? 'ユーザー編集' : 'ユーザー追加'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'ユーザー名',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'ユーザー名を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'メールアドレス',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'メールアドレスを入力してください';
                  }
                  if (!value.contains('@')) {
                    return '有効なメールアドレスを入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: '氏名',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '氏名を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneNumberController,
                decoration: const InputDecoration(
                  labelText: '電話番号',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedDepartment,
                decoration: const InputDecoration(
                  labelText: '部署',
                  border: OutlineInputBorder(),
                ),
                items: const ['営業部', '経理部', '倉庫部', 'システム部', '総務部'].map((
                  department,
                ) {
                  return DropdownMenuItem(
                    value: department,
                    child: Text(department),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDepartment = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedPosition,
                decoration: const InputDecoration(
                  labelText: '役職',
                  border: OutlineInputBorder(),
                ),
                items: const ['一般', '担当', '主任', 'マネージャー', '部長', '社長'].map((
                  position,
                ) {
                  return DropdownMenuItem(
                    value: position,
                    child: Text(position),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPosition = value!;
                  });
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
              const Text('ロール', style: TextStyle(fontWeight: FontWeight.bold)),
              ...widget.roles.map((role) {
                return CheckboxListTile(
                  title: Text(role.name),
                  subtitle: Text(role.description),
                  value: _selectedRoleIds.contains(role.id),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedRoleIds.add(role.id);
                      } else {
                        _selectedRoleIds.remove(role.id);
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
          onPressed: _saveUser,
          child: Text(isEditing ? '更新' : '作成'),
        ),
      ],
    );
  }

  void _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    final user = User(
      id: widget.user?.id ?? '',
      username: _usernameController.text,
      email: _emailController.text,
      fullName: _fullNameController.text,
      phoneNumber: _phoneNumberController.text.isEmpty
          ? null
          : _phoneNumberController.text,
      department: _selectedDepartment,
      position: _selectedPosition,
      isActive: _isActive,
      createdAt: widget.user?.createdAt ?? DateTime.now(),
      roleIds: _selectedRoleIds,
    );

    widget.onSave(user);
  }
}
