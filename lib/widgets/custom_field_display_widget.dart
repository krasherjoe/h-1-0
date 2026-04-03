import 'package:flutter/material.dart';
import '../models/custom_field_model.dart';
import '../services/custom_field_repository.dart';

/// カスタムフィールド表示ウィジェット
class CustomFieldDisplayWidget extends StatelessWidget {
  final String entityId;
  final String entityType;
  final List<CustomField> fields;

  const CustomFieldDisplayWidget({
    super.key,
    required this.entityId,
    required this.entityType,
    required this.fields,
  });

  @override
  Widget build(BuildContext context) {
    if (fields.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _getFieldValues(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Text(
            'カスタムフィールドの読み込みに失敗しました',
            style: TextStyle(
              color: Colors.red[400],
              fontSize: 12,
            ),
          );
        }

        final values = snapshot.data ?? {};
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final field in fields) ...[
              _buildFieldValue(field, values[field.fieldName]),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }

  Widget _buildFieldValue(CustomField field, dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            field.fieldLabel,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _formatValue(field.fieldType, value),
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  String _formatValue(CustomFieldType type, dynamic value) {
    switch (type) {
      case CustomFieldType.date:
        if (value is DateTime) {
          return '${value.year}/${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}';
        }
        return value.toString();
        
      case CustomFieldType.datetime:
        if (value is DateTime) {
          return '${value.year}/${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
        }
        return value.toString();
        
      case CustomFieldType.currency:
        if (value is num) {
          return '¥${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(?<=\d)(?=(\d{3})+(?!\d))'), (match) => ',')}';
        }
        return value.toString();
        
      case CustomFieldType.checkbox:
        return value == true ? 'はい' : 'いいえ';
        
      case CustomFieldType.multiselect:
        if (value is List) {
          return value.join(', ');
        }
        return value.toString();
        
      default:
        return value.toString();
    }
  }

  Future<Map<String, dynamic>> _getFieldValues() async {
    final repository = CustomFieldRepository();
    return await repository.getEntityFieldValues(entityId, entityType);
  }
}
