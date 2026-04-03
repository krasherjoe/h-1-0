import 'package:flutter/material.dart';
import '../models/business_profile_model.dart';
import '../models/custom_field_model.dart';

/// テンプレートプレビュー画面
class TemplatePreviewScreen extends StatelessWidget {
  final BusinessType businessType;
  final List<CustomField> fields;

  const TemplatePreviewScreen({
    super.key,
    required this.businessType,
    required this.fields,
  });

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

  IconData _getFieldTypeIcon(CustomFieldType type) {
    switch (type) {
      case CustomFieldType.text:
        return Icons.text_fields;
      case CustomFieldType.number:
        return Icons.tag;
      case CustomFieldType.date:
        return Icons.calendar_today;
      case CustomFieldType.datetime:
        return Icons.schedule;
      case CustomFieldType.select:
        return Icons.radio_button_checked;
      case CustomFieldType.multiselect:
        return Icons.check_box;
      case CustomFieldType.checkbox:
        return Icons.check_circle_outline;
      case CustomFieldType.textarea:
        return Icons.notes;
      case CustomFieldType.email:
        return Icons.email;
      case CustomFieldType.phone:
        return Icons.phone;
      case CustomFieldType.url:
        return Icons.link;
      case CustomFieldType.currency:
        return Icons.attach_money;
    }
  }

  String _getFieldTypeName(CustomFieldType type) {
    switch (type) {
      case CustomFieldType.text:
        return 'テキスト';
      case CustomFieldType.number:
        return '数値';
      case CustomFieldType.date:
        return '日付';
      case CustomFieldType.datetime:
        return '日時';
      case CustomFieldType.select:
        return '選択肢（単一）';
      case CustomFieldType.multiselect:
        return '選択肢（複数）';
      case CustomFieldType.checkbox:
        return 'チェックボックス';
      case CustomFieldType.textarea:
        return '長文テキスト';
      case CustomFieldType.email:
        return 'メールアドレス';
      case CustomFieldType.phone:
        return '電話番号';
      case CustomFieldType.url:
        return 'URL';
      case CustomFieldType.currency:
        return '通貨';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('T2:${_getBusinessTypeName(businessType)}業種プレビュー'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: fields.isEmpty
          ? _buildEmptyState()
          : _buildFieldsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.dashboard_customize,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '${_getBusinessTypeName(businessType)}業種のテンプレートがありません',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'この業種の標準フィールドはまだ定義されていません',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: fields.length,
      itemBuilder: (context, index) {
        final field = fields[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.indigo.shade100,
                      child: Icon(
                        _getFieldTypeIcon(field.fieldType),
                        color: Colors.indigo,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            field.fieldLabel,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            field.fieldName,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getFieldTypeName(field.fieldType),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                if (field.description != null && field.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    field.description!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
                if (field.validation.required) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.star,
                        size: 16,
                        color: Colors.red[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '必須項目',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red[400],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                if (field.validation.options != null && field.validation.options!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '選択肢: ${field.validation.options!.join(', ')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                if (field.defaultValue != null && field.defaultValue!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.settings,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '既定値: ${field.defaultValue}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
                // バリデーション情報
                if (_hasValidationRules(field)) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'バリデーション',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        ..._buildValidationRules(field),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  bool _hasValidationRules(CustomField field) {
    final validation = field.validation;
    return validation.minLength != null ||
           validation.maxLength != null ||
           validation.min != null ||
           validation.max != null ||
           validation.pattern != null;
  }

  List<Widget> _buildValidationRules(CustomField field) {
    final validation = field.validation;
    final rules = <Widget>[];

    if (validation.minLength != null) {
      rules.add(Text(
        '最小文字数: ${validation.minLength}',
        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
      ));
    }

    if (validation.maxLength != null) {
      rules.add(Text(
        '最大文字数: ${validation.maxLength}',
        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
      ));
    }

    if (validation.min != null) {
      rules.add(Text(
        '最小値: ${validation.min}',
        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
      ));
    }

    if (validation.max != null) {
      rules.add(Text(
        '最大値: ${validation.max}',
        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
      ));
    }

    if (validation.pattern != null) {
      rules.add(Text(
        '正規表現: ${validation.pattern}',
        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
      ));
    }

    return rules;
  }
}
