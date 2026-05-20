import 'package:flutter/material.dart';
import '../models/electronic_ledger_model.dart';
import '../services/electronic_ledger_repository.dart';

/// 電子帳簿検索画面
class ElectronicLedgerSearchScreen extends StatefulWidget {
  const ElectronicLedgerSearchScreen({super.key});

  @override
  State<ElectronicLedgerSearchScreen> createState() => _ElectronicLedgerSearchScreenState();
}

class _ElectronicLedgerSearchScreenState extends State<ElectronicLedgerSearchScreen> {
  final ElectronicLedgerRepository _ledgerRepo = ElectronicLedgerRepository();
  
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String _selectedDocumentType = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  int _currentPage = 0;
  final int _pageSize = 20;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    // デフォルトで過去30日間を設定
    final now = DateTime.now();
    _startDate = now.subtract(const Duration(days: 30));
    _endDate = now;
  }

  Future<void> _performSearch() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('期間を指定してください')),
      );
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await _ledgerRepo.searchElectronicLedgers(
        startDate: _startDate!,
        endDate: _endDate!,
        documentType: _selectedDocumentType == 'all' ? null : _selectedDocumentType,
        limit: _pageSize,
        offset: _currentPage * _pageSize,
      );

      setState(() {
        _searchResults = results;
        _totalCount = results.length;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('検索に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _exportResults() async {
    if (_searchResults.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('エクスポートするデータがありません')),
      );
      return;
    }

    // 実際のエクスポート機能は別途実装
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('エクスポート機能は準備中です')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('E2:電子帳簿検索'),
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportResults,
            tooltip: 'エクスポート',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchForm(),
          Expanded(child: _buildSearchResults()),
        ],
      ),
    );
  }

  Widget _buildSearchForm() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '検索条件',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // ドキュメントタイプ選択
            DropdownButtonFormField<String>(
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
            
            const SizedBox(height: 16),
            
            // 期間選択
            Row(
              children: [
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
                          color: (_startDate != null && _endDate != null) ? null : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isSearching ? null : _performSearch,
                  child: _isSearching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('検索'),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // 検索結果数
            if (_searchResults.isNotEmpty)
              Text(
                '検索結果: $_totalCount件',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      final cs = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              '検索結果がありません',
              style: TextStyle(
                fontSize: 18,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '検索条件を変更して再試行してください',
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final ledger = _searchResults[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    child: Icon(
                      _getDocumentTypeIcon(ledger['documentType']),
                      color: Theme.of(context).colorScheme.primary,
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
                  trailing: IconButton(
                    icon: const Icon(Icons.visibility),
                    onPressed: () => _viewLedgerDetails(ledger),
                    tooltip: '詳細を表示',
                  ),
                ),
              );
            },
          ),
        ),
        if (_totalCount >= _pageSize)
          _buildPaginationControls(),
      ],
    );
  }

  Widget _buildPaginationControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _currentPage > 0 ? _previousPage : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            '${_currentPage + 1}ページ',
            style: const TextStyle(fontSize: 16),
          ),
          IconButton(
            onPressed: _searchResults.length == _pageSize ? _nextPage : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
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
        _currentPage = 0; // 期間変更時にリセット
      });
    }
  }

  void _previousPage() {
    setState(() {
      _currentPage--;
    });
    _performSearch();
  }

  void _nextPage() {
    setState(() {
      _currentPage++;
    });
    _performSearch();
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
