import 'package:flutter/material.dart';
import '../models/business_profile_model.dart';
import '../services/business_profile_repository.dart';
import '../services/custom_field_repository.dart';
import '../models/custom_field_model.dart';
import 'template_preview_screen.dart';

/// 業種テンプレート選択画面
class IndustryTemplateScreen extends StatefulWidget {
  final String businessProfileId;

  const IndustryTemplateScreen({
    super.key,
    required this.businessProfileId,
  });

  @override
  State<IndustryTemplateScreen> createState() => _IndustryTemplateScreenState();
}

class _IndustryTemplateScreenState extends State<IndustryTemplateScreen> {
  final BusinessProfileRepository _businessProfileRepo = BusinessProfileRepository();
  final CustomFieldRepository _customFieldRepo = CustomFieldRepository();
  
  BusinessProfile? _currentProfile;
  List<CustomField> _currentFields = [];
  bool _isLoading = true;
  Set<BusinessType> _selectedTypes = {};

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
      final profile = await _businessProfileRepo.getProfile(widget.businessProfileId);
      final fields = await _customFieldRepo.getActiveFieldsByBusinessProfile(widget.businessProfileId);
      
      setState(() {
        _currentProfile = profile;
        _currentFields = fields;
        _selectedTypes = {profile?.businessType ?? BusinessType.retail};
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

  Future<void> _applyTemplate(BusinessType businessType) async {
    if (_currentProfile == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('テンプレート適用'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_getBusinessTypeName(businessType)}業種のテンプレートを適用します。'),
            const SizedBox(height: 8),
          Text('既存のカスタムフィールドはすべて削除され、テンプレートのフィールドに置き換えられます。',
               style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
             ),
            const SizedBox(height: 16),
            const Text('よろしいですか？'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
         style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
            child: const Text('適用'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 既存フィールドをすべて削除
      for (final field in _currentFields) {
        await _customFieldRepo.deleteFieldAndValues(field.id);
      }

      // テンプレートフィールドを取得して適用
      final templateFields = await _customFieldRepo.getIndustryTemplateFields(businessType);
      
      for (final templateField in templateFields) {
        final newField = CustomField.create(
          businessProfileId: widget.businessProfileId,
          fieldName: templateField.fieldName,
          fieldLabel: templateField.fieldLabel,
          fieldType: templateField.fieldType,
          validation: templateField.validation,
          description: templateField.description,
          defaultValue: templateField.defaultValue,
        );
        await _customFieldRepo.saveField(newField);
      }

      // ビジネスプロファイルを更新
      final updatedProfile = _currentProfile!.copyWith(
        businessType: businessType,
        updatedAt: DateTime.now(),
      );
      await _businessProfileRepo.saveProfile(updatedProfile);

      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_getBusinessTypeName(businessType)}業種テンプレートを適用しました')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('テンプレート適用に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _previewTemplate(BusinessType businessType) async {
    final templateFields = await _customFieldRepo.getIndustryTemplateFields(businessType);
    
    if (!mounted) return;
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TemplatePreviewScreen(
          businessType: businessType,
          fields: templateFields,
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

  String _getBusinessTypeDescription(BusinessType type) {
    switch (type) {
      case BusinessType.retail:
        return '店舗販売、商品管理、顧客対応';
      case BusinessType.service:
        return 'サービス提供、時間管理、顧客対応';
      case BusinessType.manufacturing:
        return '製品製造、原材料管理、品質管理';
      case BusinessType.wholesale:
        return '卸売販売、在庫管理、取引先管理';
      case BusinessType.restaurant:
        return '飲食提供、食材管理、店舗運営';
      case BusinessType.construction:
        return '建設工事、現場管理、工程管理';
      case BusinessType.other:
        return 'その他業種、カスタマイズ対応';
    }
  }

  IconData _getBusinessTypeIcon(BusinessType type) {
    switch (type) {
      case BusinessType.retail:
        return Icons.store;
      case BusinessType.service:
        return Icons.support_agent;
      case BusinessType.manufacturing:
        return Icons.precision_manufacturing;
      case BusinessType.wholesale:
        return Icons.inventory_2;
      case BusinessType.restaurant:
        return Icons.restaurant;
      case BusinessType.construction:
        return Icons.construction;
      case BusinessType.other:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('T1:業種テンプレート選択'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildCurrentStatus(),
                Expanded(child: _buildTemplateGrid()),
              ],
            ),
    );
  }

  Widget _buildCurrentStatus() {
    if (_currentProfile == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.primaryContainer),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getBusinessTypeIcon(_currentProfile!.businessType),
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                '現在の業種: ${_getBusinessTypeName(_currentProfile!.businessType)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'カスタムフィールド数: ${_currentFields.length}',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateGrid() {
    final businessTypes = BusinessType.values;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: businessTypes.length,
        itemBuilder: (context, index) {
          final businessType = businessTypes[index];
          final isSelected = _selectedTypes.contains(businessType);
          final isCurrent = _currentProfile?.businessType == businessType;
          
          return Card(
            elevation: isSelected ? 8 : 2,
            color: isSelected ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2) : null,
            child: InkWell(
              onTap: () => _previewTemplate(businessType),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Icon(
                            _getBusinessTypeIcon(businessType),
                            color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                        ),
                        if (isCurrent)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '現在',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _getBusinessTypeName(businessType),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Theme.of(context).colorScheme.primary : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getBusinessTypeDescription(businessType),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => _previewTemplate(businessType),
                          child: const Text('プレビュー'),
                        ),
                        const SizedBox(width: 8),
                  ElevatedButton(
                           onPressed: () => _applyTemplate(businessType),
                           style: ElevatedButton.styleFrom(
                             backgroundColor: isSelected ? Theme.of(context).colorScheme.primary : null,
                             foregroundColor: isSelected ? Theme.of(context).colorScheme.onPrimary : null,
                           ),
                          child: const Text('適用'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
