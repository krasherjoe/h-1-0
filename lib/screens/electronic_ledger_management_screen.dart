import 'package:flutter/material.dart';
import '../models/electronic_ledger_model.dart';
import '../services/electronic_ledger_repository.dart';

/// 電子帳簿管理画面
class ElectronicLedgerManagementScreen extends StatefulWidget {
  const ElectronicLedgerManagementScreen({super.key});

  @override
  State<ElectronicLedgerManagementScreen> createState() => _ElectronicLedgerManagementScreenState();
}

class _ElectronicLedgerManagementScreenState extends State<ElectronicLedgerManagementScreen> {
  final ElectronicLedgerRepository _ledgerRepo = ElectronicLedgerRepository();
  
  List<Map<String, dynamic>> _ledgers = [];
  bool _isLoading = true;
  String _selectedDocumentType = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  Map<String, dynamic>? _statistics;

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
      // デフォルトで過去30日間のデータを読み込み
      final now = DateTime.now();
      final startDate = _startDate ?? now.subtract(const Duration(days: 30));
      final endDate = _endDate ?? now;

      final ledgers = await _ledgerRepo.searchElectronicLedgers(
        startDate: startDate,
        endDate: endDate,
        documentType: _selectedDocumentType == 'all' ? null : _selectedDocumentType,
      );

      final statistics = await _ledgerRepo.getDatabaseStatistics();

      setState(() {
        _ledgers = ledgers;
        _statistics = statistics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('データ読み込みに失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _verifyDataIntegrity() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final issues = await _ledgerRepo.verifyDataIntegrity();
      
      if (!mounted) return;

      if (issues.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('データ整合性チェック完了：問題はありません'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('⚠️ データ整合性問題'),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ListView.builder(
                itemCount: issues.length,
                itemBuilder: (context, index) {
                  final issue = issues[index];
                  return ListTile(
                    title: Text('ドキュメントID: ${issue['documentId']}'),
                    subtitle: Text('問題: ${issue['issue']}'),
                    leading: const Icon(Icons.warning, color: Colors.orange),
                  );
                },
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('整合性チェックに失敗しました: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _archiveOldData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('古いデータのアーカイブ'),
        content: const Text('7年以上前のデータをアーカイブします。よろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('アーカイブ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _ledgerRepo.archiveOldData();
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('古いデータをアーカイブしました'),
          backgroundColor: Colors.green,
        ),
      );
      
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('アーカイブに失敗しました: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('E1:電子帳簿管理'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: '更新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStatisticsCard(),
                _buildFilterSection(),
                Expanded(child: _buildLedgersList()),
              ],
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            onPressed: _verifyDataIntegrity,
            icon: const Icon(Icons.security),
            label: const Text('整合性チェック'),
            backgroundColor: Colors.orange,
            heroTag: 'integrity',
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            onPressed: _archiveOldData,
            icon: const Icon(Icons.archive),
            label: const Text('アーカイブ'),
            backgroundColor: Colors.green,
            heroTag: 'archive',
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard() {
    if (_statistics == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'データベース統計',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '総ドキュメント数',
                    '${_statistics!['totalDocuments']}',
                    Icons.description,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'データサイズ',
                    _formatDataSize(_statistics!['totalDataSize']),
                    Icons.storage,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '平均サイズ',
                    _formatDataSize(_statistics!['averageDataSize']),
                    Icons.data_usage,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '最終更新',
                    _formatDateTime(_statistics!['lastUpdated']),
                    Icons.update,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.indigo),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildFilterSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '検索条件',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedDocumentType,
                    decoration: const InputDecoration(
                      labelText: 'ドキュメントタイプ',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('すべて')),
                      DropdownMenuItem(value: 'invoice', child: Text('請求書')),
                      DropdownMenuItem(value: 'receipt', child: Text('領収書')),
                      DropdownMenuItem(value: 'purchase_order', child: Text('発注書')),
                      DropdownMenuItem(value: 'purchase_return', child: Text('仕入返品書')),
                      DropdownMenuItem(value: 'estimate', child: Text('見積書')),
                      DropdownMenuItem(value: 'sales_order', child: Text('受注書')),
                      DropdownMenuItem(value: 'sales_return', child: Text('売上返品書')),
                      DropdownMenuItem(value: 'delivery_note', child: Text('納品書')),
                      DropdownMenuItem(value: 'payment_record', child: Text('支払記録')),
                      DropdownMenuItem(value: 'bank_transaction', child: Text('銀行取引')),
                      DropdownMenuItem(value: 'expense', child: Text('経費')),
                      DropdownMenuItem(value: 'inventory_adjustment', child: Text('在庫調整')),
                      DropdownMenuItem(value: 'stocktake', child: Text('棚卸')),
                      DropdownMenuItem(value: 'other', child: Text('その他')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedDocumentType = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _selectDateRange,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '期間',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        _formatDateRange(),
                        style: TextStyle(
                          color: (_startDate != null && _endDate != null) ? null : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _loadData,
                  child: const Text('検索'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLedgersList() {
    if (_ledgers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '電子帳簿データがありません',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '検索条件を変更して再試行してください',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _ledgers.length,
      itemBuilder: (context, index) {
        final ledger = _ledgers[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.indigo.shade100,
              child: Icon(
                _getDocumentTypeIcon(ledger['documentType']),
                color: Colors.indigo,
                size: 20,
              ),
            ),
            title: Text(
              _getDocumentTypeDisplayName(ledger['documentType']),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '作成日: ${_formatDateTime(ledger['createdAt'])}',
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'view') {
                  _viewLedgerDetails(ledger);
                } else if (value == 'history') {
                  _viewLedgerHistory(ledger['id']);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'view',
                  child: ListTile(
                    leading: Icon(Icons.visibility),
                    title: Text('詳細を表示'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'history',
                  child: ListTile(
                    leading: Icon(Icons.history),
                    title: Text('履歴を表示'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _viewLedgerDetails(Map<String, dynamic> ledger) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_getDocumentTypeDisplayName(ledger['documentType'])),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('ドキュメントID', ledger['id']),
              _buildDetailRow('作成日時', _formatDateTime(ledger['createdAt'])),
              _buildDetailRow('更新日時', _formatDateTime(ledger['updatedAt'])),
              _buildDetailRow('データハッシュ', ledger['documentHash']),
              const SizedBox(height: 12),
              const Text(
                'メタデータ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _formatJson(ledger['metadata']),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
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

  void _viewLedgerHistory(String ledgerId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final history = await _ledgerRepo.getLedgerHistory(ledgerId);
      
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('変更履歴'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'バージョン: ${item['metadata']['version']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text('作成日: ${_formatDateTime(item['createdAt'])}'),
                        Text('更新日: ${_formatDateTime(item['updatedAt'])}'),
                        Text('ハッシュ: ${item['documentHash']}'),
                      ],
                    ),
                  ),
                );
              },
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('履歴の取得に失敗しました: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getDocumentTypeIcon(String documentType) {
    switch (documentType) {
      case 'invoice':
        return Icons.request_quote;
      case 'receipt':
        return Icons.receipt;
      case 'purchase_order':
        return Icons.shopping_cart;
      case 'purchase_return':
        return Icons.keyboard_return;
      case 'estimate':
      case 'quotation':
        return Icons.description;
      case 'sales_order':
        return Icons.point_of_sale;
      case 'sales_return':
        return Icons.keyboard_return;
      case 'delivery_note':
        return Icons.local_shipping;
      case 'payment_record':
        return Icons.payment;
      case 'bank_transaction':
        return Icons.account_balance;
      case 'expense':
        return Icons.money_off;
      case 'inventory_adjustment':
        return Icons.inventory;
      case 'stocktake':
        return Icons.checklist;
      default:
        return Icons.description;
    }
  }

  String _getDocumentTypeDisplayName(String documentType) {
    for (final type in ElectronicLedgerDocumentType.values) {
      if (type.code == documentType) {
        return type.displayName;
      }
    }
    return documentType;
  }

  String _formatDataSize(dynamic size) {
    if (size == null) return '0 B';
    final bytes = size is int ? size : int.tryParse(size.toString()) ?? 0;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDateTime(String dateTime) {
    final date = DateTime.parse(dateTime);
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateRange() {
    if (_startDate == null || _endDate == null) {
      return '期間を選択';
    }
    return '${_startDate!.month}/${_startDate!.day} - ${_endDate!.month}/${_endDate!.day}';
  }

  String _formatJson(dynamic json) {
    if (json is String) {
      return json;
    }
    return json.toString();
  }
}
