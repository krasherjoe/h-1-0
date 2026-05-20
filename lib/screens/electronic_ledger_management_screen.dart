import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import '../models/electronic_ledger_model.dart';
import '../services/electronic_ledger_repository.dart';
import '../services/database_helper.dart';
import '../services/activity_log_repository.dart';

/// 電子帳簿管理画面
class ElectronicLedgerManagementScreen extends StatefulWidget {
  const ElectronicLedgerManagementScreen({super.key});

  @override
  State<ElectronicLedgerManagementScreen> createState() => _ElectronicLedgerManagementScreenState();
}

class _ElectronicLedgerManagementScreenState extends State<ElectronicLedgerManagementScreen> {
  final ElectronicLedgerRepository _ledgerRepo = ElectronicLedgerRepository();
  final LocalBackupService _backupService = LocalBackupService();
  final ActivityLogRepository _activityLog = ActivityLogRepository();

  List<Map<String, dynamic>> _ledgers = [];
  bool _isLoading = true;
  String _selectedDocumentType = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  Map<String, dynamic>? _statistics;
  List<BackupFile> _quarantinedBackups = [];
  bool _isLoadingQuarantine = false;

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
          SnackBar(
            content: Text('データ整合性チェック完了：問題はありません'),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
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
                    leading: Icon(Icons.warning, color: Theme.of(context).colorScheme.error),
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
        SnackBar(
          content: Text('古いデータをアーカイブしました'),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
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

  /// 隔離されたバックアップ一覧を読み込み
  Future<void> _loadQuarantine() async {
    setState(() => _isLoadingQuarantine = true);
    try {
      final list = await _backupService.getQuarantineList();
      if (!mounted) return;
      setState(() {
        _quarantinedBackups = list;
        _isLoadingQuarantine = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingQuarantine = false);
      }
    }
  }

  /// 隔離バックアップを手動削除（確認ダイアログ必須）
  Future<void> _deleteQuarantinedBackup(BackupFile backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('バックアップ削除確認'),
        content: Text(
          '以下のバックアップを削除しますか？\n'
          '作成日時: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(backup.createdTime)}\n'
          'サイズ: ${backup.formattedSize}\n\n'
          '※ 削除後は復元できません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text('削除', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoadingQuarantine = true);
    try {
      await _backupService.deleteQuarantinedBackup(backup.path);
      // P5: 削除操作をaudit_logsに記録（誰が・いつ・何を削除したか追跡）
      await _activityLog.logAction(
        action: 'DELETE_QUARANTINE_BACKUP',
        targetType: 'BACKUP',
        targetId: backup.path.split('/').last,
        details: 'バックアップ削除: 作成日時=${DateFormat('yyyy-MM-dd HH:mm:ss').format(backup.createdTime)}, '
            'サイズ=${backup.formattedSize}, パス=${backup.path}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('バックアップを削除しました'),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        ),
      );
      await _loadQuarantine();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingQuarantine = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e')),
        );
      }
    }
  }

  /// 隔離バックアップ管理ダイアログ（ユーザー手動削除UI）
  Future<void> _showQuarantineDialog() async {
    await _loadQuarantine();
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '隔離バックアップ管理',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: _isLoadingQuarantine
                  ? const Center(child: CircularProgressIndicator())
                  : _quarantinedBackups.isEmpty
                      ? const Center(
                          child: Text(
                            '隔離されたバックアップはありません\n'
                            '（保存期間超過データが自動隔離されます）',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          itemCount: _quarantinedBackups.length,
                          itemBuilder: (context, index) {
                            final backup = _quarantinedBackups[index];
                            return Card(
                              child: ListTile(
                                leading: Icon(
                                  Icons.folder_zip,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                title: Text(
                                  DateFormat('yyyy-MM-dd HH:mm:ss')
                                      .format(backup.createdTime),
                                ),
                                subtitle: Text(
                                  'サイズ: ${backup.formattedSize}\n'
                                  '${backup.path.split('/').last}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                isThreeLine: true,
                                trailing: IconButton(
                                  icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                                  tooltip: '削除',
                                  onPressed: () async {
                                    await _deleteQuarantinedBackup(backup);
                                    // _loadQuarantineで再読み込み済み、ダイアログ再描画
                                    setDialogState(() {});
                                  },
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
              if (_quarantinedBackups.isNotEmpty)
                TextButton(
                  onPressed: () async {
                    // 一括削除（個別確認あり）
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('一括削除確認'),
                        content: Text(
                          '${_quarantinedBackups.length}件のバックアップを削除します。\n'
                          '本当によろしいですか？',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('キャンセル'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.error,
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(
                              'すべて削除',
                              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      final targets = List<BackupFile>.from(_quarantinedBackups);
                      for (final backup in targets) {
                        await _backupService.deleteQuarantinedBackup(
                          backup.path,
                        );
                        // P5: 一括削除もaudit_logsに記録
                        await _activityLog.logAction(
                          action: 'DELETE_QUARANTINE_BACKUP_BULK',
                          targetType: 'BACKUP',
                          targetId: backup.path.split('/').last,
                          details: 'バックアップ一括削除: 作成日時=${DateFormat('yyyy-MM-dd HH:mm:ss').format(backup.createdTime)}, '
                              'サイズ=${backup.formattedSize}, パス=${backup.path}',
                        );
                      }
                      await _loadQuarantine();
                      setDialogState(() {});
                    }
                  },
                  child: Text('すべて削除', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('E1:電子帳簿管理'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _showQuarantineDialog,
            tooltip: '隔離バックアップ管理',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportLedgers,
            tooltip: 'CSVエクスポート',
          ),
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
            backgroundColor: Theme.of(context).colorScheme.error,
            heroTag: 'integrity',
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            onPressed: _archiveOldData,
            icon: const Icon(Icons.archive),
            label: const Text('アーカイブ'),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
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
        Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                          color: (_startDate != null && _endDate != null) ? null : Theme.of(context).colorScheme.onSurfaceVariant,
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
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              '電子帳簿データがありません',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '検索条件を変更して再試行してください',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  /// CSVエクスポート（現在表示中の帳簿データを出力）
  Future<void> _exportLedgers() async {
    if (_ledgers.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('エクスポート対象のデータがありません')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final buffer = StringBuffer();
      // UTF-8 BOM for Excel
      buffer.writeCharCode(0xFEFF);

      buffer.writeln(
        'ドキュメントID,ドキュメント種別,バージョン,作成日時,更新日時,データサイズ,ハッシュ値',
      );

      for (final ledger in _ledgers) {
        final metadata = ledger['metadata'] as Map<String, dynamic>;
        buffer.writeln(
          [
            _csvEscape(ledger['documentId'] as String),
            _csvEscape(_getDocumentTypeDisplayName(ledger['documentType'] as String)),
            '${ledger['version']}',
            _csvEscape(DateFormat('yyyy-MM-dd HH:mm:ss').format(ledger['createdAt'] as DateTime)),
            _csvEscape(DateFormat('yyyy-MM-dd HH:mm:ss').format(ledger['updatedAt'] as DateTime)),
            '${metadata['dataSize'] ?? 0}',
            _csvEscape(metadata['documentHash'] as String? ?? ''),
          ].join(','),
        );
      }

      final fileName =
          'electronic_ledger_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(p.join(tempDir.path, fileName));
      await tempFile.writeAsString(buffer.toString(), encoding: utf8);

      // Downloadsフォルダにもコピー
      String? downloadPath;
      if (Platform.isAndroid) {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          final downloadFile = File(p.join(downloadDir.path, fileName));
          await tempFile.copy(downloadFile.path);
          downloadPath = downloadFile.path;
        }
      }

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path, mimeType: 'text/csv')],
          subject: '電子帳簿エクスポート ($fileName)',
          text: '電子帳簿 CSV エクスポート',
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              downloadPath != null
                  ? 'CSVをエクスポートしました\n$downloadPath'
                  : 'CSVをエクスポートしました',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エクスポートに失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _csvEscape(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
