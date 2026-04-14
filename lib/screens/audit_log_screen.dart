import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/auth_models.dart';
import '../services/auth_repository.dart';

/// 監査ログ画面
class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final AuthRepository _authRepository = AuthRepository();
  final ScrollController _scrollController = ScrollController();

  List<AuditLog> _auditLogs = [];
  List<User> _users = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _currentPage = 0;
  final int _pageSize = 50;

  String _selectedUser = 'すべて';
  String _selectedResourceType = 'すべて';
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadData();
    _loadUsers();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        !_isLoadingMore &&
        _auditLogs.length >= _pageSize) {
      _loadMoreLogs();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _currentPage = 0;
      _auditLogs.clear();
    });

    try {
      final logs = await _authRepository.getAuditLogs(
        userId: _selectedUser == 'すべて' ? null : _selectedUser,
        resourceType: _selectedResourceType == 'すべて'
            ? null
            : _selectedResourceType,
        startDate: _startDate,
        endDate: _endDate,
        limit: _pageSize,
        offset: 0,
      );

      setState(() {
        _auditLogs = logs;
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

  Future<void> _loadMoreLogs() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final logs = await _authRepository.getAuditLogs(
        userId: _selectedUser == 'すべて' ? null : _selectedUser,
        resourceType: _selectedResourceType == 'すべて'
            ? null
            : _selectedResourceType,
        startDate: _startDate,
        endDate: _endDate,
        limit: _pageSize,
        offset: nextPage * _pageSize,
      );

      setState(() {
        _auditLogs.addAll(logs);
        _currentPage = nextPage;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('追加データ読み込みに失敗しました: $e')));
      }
    }
  }

  Future<void> _loadUsers() async {
    try {
      final users = await _authRepository.getAllUsers();
      setState(() {
        _users = users;
      });
    } catch (e) {
      // ユーザーデータの読み込み失敗は無視
    }
  }

  List<AuditLog> get _filteredLogs {
    return _auditLogs.where((log) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          log.action.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          log.resourceType.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AL:監査ログ'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: '更新',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportLogs,
            tooltip: 'エクスポート',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildLogList(),
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
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedUser,
                  decoration: const InputDecoration(
                    labelText: 'ユーザー',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'すべて', child: Text('すべて')),
                    ..._users.map(
                      (user) => DropdownMenuItem(
                        value: user.id,
                        child: Text(user.fullName),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedUser = value!;
                    });
                    _loadData();
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedResourceType,
                  decoration: const InputDecoration(
                    labelText: 'リソースタイプ',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'すべて', child: Text('すべて')),
                    DropdownMenuItem(value: 'ユーザー', child: Text('ユーザー')),
                    DropdownMenuItem(value: 'ロール', child: Text('ロール')),
                    DropdownMenuItem(value: '見積', child: Text('見積')),
                    DropdownMenuItem(value: '受注', child: Text('受注')),
                    DropdownMenuItem(value: '売上', child: Text('売上')),
                    DropdownMenuItem(value: '仕入', child: Text('仕入')),
                    DropdownMenuItem(value: '在庫', child: Text('在庫')),
                    DropdownMenuItem(value: '配送', child: Text('配送')),
                    DropdownMenuItem(value: '請求', child: Text('請求')),
                    DropdownMenuItem(value: '支払', child: Text('支払')),
                    DropdownMenuItem(value: '設定', child: Text('設定')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedResourceType = value!;
                    });
                    _loadData();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _selectStartDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: '開始日',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      _startDate != null
                          ? DateFormat('yyyy-MM-dd').format(_startDate!)
                          : '選択してください',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: _selectEndDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: '終了日',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      _endDate != null
                          ? DateFormat('yyyy-MM-dd').format(_endDate!)
                          : '選択してください',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _clearFilters,
                child: const Text('クリア'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogList() {
    final filteredLogs = _filteredLogs;

    if (filteredLogs.isEmpty) {
      return const Center(
        child: Text(
          '監査ログが見つかりません',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(8),
        itemCount: filteredLogs.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == filteredLogs.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final log = filteredLogs[index];
          return _buildLogCard(log);
        },
      ),
    );
  }

  Widget _buildLogCard(AuditLog log) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getActionColor(log.action),
          child: Icon(
            _getActionIcon(log.action),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          log.action,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${log.username} - ${log.resourceType}'),
            if (log.resourceId != null) Text('ID: ${log.resourceId}'),
            Text(
              DateFormat('yyyy-MM-dd HH:mm:ss').format(log.createdAt),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(value: 'details', child: const Text('詳細')),
          ],
          onSelected: (value) {
            if (value == 'details') {
              _showLogDetails(log);
            }
          },
        ),
      ),
    );
  }

  Color _getActionColor(String action) {
    if (action.contains('作成') || action.contains('追加')) {
      return Colors.green;
    } else if (action.contains('更新') || action.contains('編集')) {
      return Colors.blue;
    } else if (action.contains('削除')) {
      return Colors.red;
    } else if (action.contains('ログイン')) {
      return Colors.purple;
    } else {
      return Colors.grey;
    }
  }

  IconData _getActionIcon(String action) {
    if (action.contains('作成') || action.contains('追加')) {
      return Icons.add;
    } else if (action.contains('更新') || action.contains('編集')) {
      return Icons.edit;
    } else if (action.contains('削除')) {
      return Icons.delete;
    } else if (action.contains('ログイン')) {
      return Icons.login;
    } else if (action.contains('ログアウト')) {
      return Icons.logout;
    } else {
      return Icons.info;
    }
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      setState(() {
        _startDate = date;
      });
      _loadData();
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      setState(() {
        _endDate = date;
      });
      _loadData();
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedUser = 'すべて';
      _selectedResourceType = 'すべて';
      _startDate = null;
      _endDate = null;
      _searchQuery = '';
    });
    _loadData();
  }

  void _showLogDetails(AuditLog log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('操作詳細'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('ユーザー', log.username),
              _buildDetailRow('操作', log.action),
              _buildDetailRow('リソースタイプ', log.resourceType),
              if (log.resourceId != null)
                _buildDetailRow('リソースID', log.resourceId!),
              _buildDetailRow(
                '日時',
                DateFormat('yyyy-MM-dd HH:mm:ss').format(log.createdAt),
              ),
              if (log.ipAddress != null)
                _buildDetailRow('IPアドレス', log.ipAddress!),
              if (log.userAgent != null)
                _buildDetailRow('ユーザーエージェント', log.userAgent!),
              if (log.oldValue != null) _buildDetailRow('変更前', log.oldValue!),
              if (log.newValue != null) _buildDetailRow('変更後', log.newValue!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey.shade700)),
          ),
        ],
      ),
    );
  }

  Future<void> _exportLogs() async {
    // 実際のエクスポート処理
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('エクスポート機能は今後実装予定です')));
  }
}
