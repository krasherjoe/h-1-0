import 'package:flutter/material.dart';
import '../models/business_profile_model.dart';
import '../services/business_profile_repository.dart';

/// 業種プロファイル設定画面（B1）
class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  final BusinessProfileRepository _repository = BusinessProfileRepository();
  BusinessProfile? _currentProfile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _repository.getCurrentProfile();
    if (!mounted) return;
    setState(() {
      _currentProfile = profile;
      _loading = false;
    });
  }

  Future<void> _saveProfile() async {
    if (_currentProfile == null) return;

    final updatedProfile = _currentProfile!.copyWith(
      updatedAt: DateTime.now(),
    );

    await _repository.saveProfile(updatedProfile);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('業種設定を保存しました')),
    );
  }

  Future<void> _resetToDefault() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('リセット確認'),
        content: const Text('業種設定をデフォルトに戻しますか？'),
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

    final defaultProfile = BusinessProfile.defaultProfile();
    await _repository.saveProfile(defaultProfile);
    await _loadProfile();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('デフォルト設定に戻しました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('B1:業種設定'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            onPressed: _saveProfile,
            icon: const Icon(Icons.save),
          ),
          IconButton(
            onPressed: _resetToDefault,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _currentProfile == null
              ? const Center(child: Text('プロファイルデータがありません'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBusinessTypeSection(),
                      const SizedBox(height: 16),
                      _buildWorkflowSection(),
                      const SizedBox(height: 16),
                      _buildPricingSection(),
                      const SizedBox(height: 16),
                      _buildFeatureFlagsSection(),
                      const SizedBox(height: 16),
                      _buildUnitsSection(),
                      const SizedBox(height: 16),
                      _buildProfileInfo(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildBusinessTypeSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '業種',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: BusinessType.values.map((type) {
                return ChoiceChip(
                  label: Text(_getBusinessTypeName(type)),
                  selected: _currentProfile!.businessType == type,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _currentProfile = _currentProfile!.copyWith(
                          businessType: type,
                        );
                      });
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkflowSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '業務フロー',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: WorkflowType.values.map((workflow) {
                return ChoiceChip(
                  label: Text(_getWorkflowName(workflow)),
                  selected: _currentProfile!.workflow == workflow,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _currentProfile = _currentProfile!.copyWith(
                          workflow: workflow,
                        );
                      });
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '価格体系',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PricingType.values.map((pricing) {
                return ChoiceChip(
                  label: Text(_getPricingName(pricing)),
                  selected: _currentProfile!.pricing == pricing,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _currentProfile = _currentProfile!.copyWith(
                          pricing: pricing,
                        );
                      });
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureFlagsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '機能設定',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              title: const Text('在庫管理'),
              subtitle: const Text('在庫数の管理を行う'),
              value: _currentProfile!.needsInventory,
              onChanged: (value) {
                setState(() {
                  _currentProfile = _currentProfile!.copyWith(
                    needsInventory: value,
                  );
                });
              },
            ),
            SwitchListTile.adaptive(
              title: const Text('GPS記録'),
              subtitle: const Text('位置情報を記録する'),
              value: _currentProfile!.needsGPS,
              onChanged: (value) {
                setState(() {
                  _currentProfile = _currentProfile!.copyWith(
                    needsGPS: value,
                  );
                });
              },
            ),
            SwitchListTile.adaptive(
              title: const Text('写真記録'),
              subtitle: const Text('写真を記録する'),
              value: _currentProfile!.needsPhotos,
              onChanged: (value) {
                setState(() {
                  _currentProfile = _currentProfile!.copyWith(
                    needsPhotos: value,
                  );
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '使用単位',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '商品で使用する単位をカンマ区切りで入力（例：個,式,セット）',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '個,式',
              ),
              onChanged: (value) {
                final units = value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                setState(() {
                  _currentProfile = _currentProfile!.copyWith(
                    productUnits: units.isEmpty ? ['個'] : units,
                  );
                });
              },
              controller: TextEditingController(
                text: _currentProfile!.productUnits.join(','),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'プロファイル情報',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('業種: ${_currentProfile!.businessTypeName}'),
            Text('業務フロー: ${_currentProfile!.workflowName}'),
            Text('価格体系: ${_currentProfile!.pricingName}'),
            Text('使用単位: ${_currentProfile!.productUnits.join(', ')}'),
            Text('作成日時: ${_currentProfile!.createdAt.toString().substring(0, 19)}'),
            Text('更新日時: ${_currentProfile!.updatedAt.toString().substring(0, 19)}'),
          ],
        ),
      ),
    );
  }

  String _getBusinessTypeName(BusinessType type) {
    switch (type) {
      case BusinessType.retail:
        return '小売';
      case BusinessType.service:
        return 'サービス';
      case BusinessType.manufacturing:
        return '製造';
      case BusinessType.wholesale:
        return '卸売';
      case BusinessType.restaurant:
        return '飲食';
      case BusinessType.construction:
        return '建設';
      case BusinessType.other:
        return 'その他';
    }
  }

  String _getWorkflowName(WorkflowType workflow) {
    switch (workflow) {
      case WorkflowType.sales:
        return '販売中心';
      case WorkflowType.purchase:
        return '仕入中心';
      case WorkflowType.both:
        return '販売・仕入両方';
      case WorkflowType.service:
        return 'サービス提供';
    }
  }

  String _getPricingName(PricingType pricing) {
    switch (pricing) {
      case PricingType.standard:
        return '標準価格';
      case PricingType.tiered:
        return '段階価格';
      case PricingType.custom:
        return 'カスタム価格';
    }
  }
}
