import 'package:flutter/material.dart';
import '../models/electronic_ledger_model.dart';
import '../services/electronic_ledger_repository.dart';
import '../services/business_profile_repository.dart';

/// 電子帳簿設定画面
class ElectronicLedgerSettingsScreen extends StatefulWidget {
  const ElectronicLedgerSettingsScreen({super.key});

  @override
  State<ElectronicLedgerSettingsScreen> createState() => _ElectronicLedgerSettingsScreenState();
}

class _ElectronicLedgerSettingsScreenState extends State<ElectronicLedgerSettingsScreen> {
  final ElectronicLedgerRepository _ledgerRepo = ElectronicLedgerRepository();
  final BusinessProfileRepository _businessProfileRepo = BusinessProfileRepository();
  
  ElectronicLedgerSettings? _settings;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final profile = await _businessProfileRepo.getCurrentProfile();
      
      // 現在はデフォルト設定を読み込む（実際にはDBから読み込む）
      final settings = ElectronicLedgerSettings.defaultSettings(
        businessProfileId: profile.id,
      );

      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('設定の読み込みに失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_settings == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // 実際の保存処理を実装
      await _saveSettingsToDatabase(_settings!);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('設定を保存しました'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('設定の保存に失敗しました: $e')),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _saveSettingsToDatabase(ElectronicLedgerSettings settings) async {
    // 実際の保存処理
    // ここではシミュレーションとして成功を返す
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _resetToDefault() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('設定のリセット'),
        content: const Text('すべての設定をデフォルト値にリセットします。よろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('リセット'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final profile = await _businessProfileRepo.getCurrentProfile();
      
      setState(() {
        _settings = ElectronicLedgerSettings.defaultSettings(
          businessProfileId: profile.id,
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('設定をデフォルト値にリセットしました'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('リセットに失敗しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_settings == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('E3:電子帳簿設定'),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('設定を読み込めませんでした'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('E3:電子帳簿設定'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSettings,
            tooltip: '再読み込み',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('保存期間設定'),
            _buildRetentionPeriodSection(),
            
            const SizedBox(height: 24),
            
            _buildSectionTitle('データ管理設定'),
            _buildDataManagementSection(),
            
            const SizedBox(height: 24),
            
            _buildSectionTitle('セキュリティ設定'),
            _buildSecuritySection(),
            
            const SizedBox(height: 24),
            
            _buildSectionTitle('詳細設定'),
            _buildAdvancedSection(),
            
            const SizedBox(height: 32),
            
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.indigo,
        ),
      ),
    );
  }

  Widget _buildRetentionPeriodSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '保存期間',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              '電子帳簿データの保存期間を設定します。',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ElectronicLedgerRetentionPeriod>(
              initialValue: _settings!.retentionPeriod,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: '保存期間',
              ),
              items: ElectronicLedgerRetentionPeriod.values.map((period) {
                return DropdownMenuItem(
                  value: period,
                  child: Text(period.displayName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _settings = _settings!.copyWith(retentionPeriod: value);
                  });
                }
              },
            ),
            const SizedBox(height: 8),
            Text(
              _getRetentionPeriodDescription(_settings!.retentionPeriod),
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataManagementSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'データ管理',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('データ圧縮'),
              subtitle: const Text('古いデータを自動的に圧縮して保存容量を節約'),
              value: _settings!.enableCompression,
              onChanged: (value) {
                setState(() {
                  _settings = _settings!.copyWith(enableCompression: value);
                });
              },
            ),
            SwitchListTile(
              title: const Text('バージョン管理'),
              subtitle: const Text('ドキュメントの変更履歴を保持'),
              value: _settings!.enableVersioning,
              onChanged: (value) {
                setState(() {
                  _settings = _settings!.copyWith(enableVersioning: value);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecuritySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'セキュリティ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('データ暗号化'),
              subtitle: const Text('保存データを暗号化してセキュリティを強化'),
              value: _settings!.enableEncryption,
              onChanged: (value) {
                setState(() {
                  _settings = _settings!.copyWith(enableEncryption: value);
                });
              },
            ),
            const SizedBox(height: 8),
            Text(
              '注: 暗号化を有効にするとパフォーマンスが低下する可能性があります。',
              style: TextStyle(fontSize: 12, color: Colors.orange[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '詳細設定',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('バージョン情報'),
              subtitle: Text('現在のバージョン: ${_settings!.customSettings['version'] ?? '1.0'}'),
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('最終更新'),
              subtitle: Text(_formatDateTime(_settings!.updatedAt)),
            ),
            ListTile(
              leading: const Icon(Icons.storage),
              title: const Text('データベース統計'),
              subtitle: const Text('データベース使用状況を確認'),
              onTap: _showDatabaseStatistics,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isSaving
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('保存中...'),
                    ],
                  )
                : const Text('設定を保存'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _resetToDefault,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              'デフォルトにリセット',
              style: TextStyle(color: Colors.red[700]),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showDatabaseStatistics() async {
    try {
      final statistics = await _ledgerRepo.getDatabaseStatistics();
      
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('データベース統計'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatRow('総ドキュメント数', '${statistics['totalDocuments']}'),
                _buildStatRow('総データサイズ', _formatDataSize(statistics['totalDataSize'])),
                _buildStatRow('平均データサイズ', _formatDataSize(statistics['averageDataSize'])),
                _buildStatRow('最終更新', _formatDateTime(statistics['lastUpdated'])),
                const SizedBox(height: 16),
                const Text(
                  'ドキュメントタイプ別',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...(statistics['documentsByType'] as List).map<Widget>((stat) {
                  return _buildStatRow(stat['type'], '${stat['count']}件');
                }),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('統計情報の取得に失敗しました: $e')),
        );
      }
    }
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const Text(': '),
          Text(value),
        ],
      ),
    );
  }

  String _getRetentionPeriodDescription(ElectronicLedgerRetentionPeriod period) {
    switch (period) {
      case ElectronicLedgerRetentionPeriod.sevenYears:
        return '電子帳簿保存法で定められた標準保存期間（7年間）';
      case ElectronicLedgerRetentionPeriod.tenYears:
        return 'より長い期間の保存が必要な場合（10年間）';
      case ElectronicLedgerRetentionPeriod.permanent:
        return '永久保存（推奨されません）';
    }
  }

  String _formatDataSize(dynamic size) {
    if (size == null) return '0 B';
    final bytes = size is int ? size : int.tryParse(size.toString()) ?? 0;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
