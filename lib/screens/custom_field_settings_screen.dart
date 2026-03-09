import 'package:flutter/material.dart';
import '../models/custom_field_model.dart';
import '../services/custom_field_repository.dart';
import 'custom_field_edit_screen.dart';
import 'custom_field_reorder_screen.dart';

/// カスタムフィールド設定画面
class CustomFieldSettingsScreen extends StatefulWidget {
  final String businessProfileId;

  const CustomFieldSettingsScreen({
    super.key,
    required this.businessProfileId,
  });

  @override
  State<CustomFieldSettingsScreen> createState() => _CustomFieldSettingsScreenState();
}

class _CustomFieldSettingsScreenState extends State<CustomFieldSettingsScreen> {
  final CustomFieldRepository _repository = CustomFieldRepository();
  List<CustomField> _fields = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFields();
  }

  Future<void> _loadFields() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final fields = await _repository.getActiveFieldsByBusinessProfile(widget.businessProfileId);
      setState(() {
        _fields = fields;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('カスタムフィールドの読み込みに失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _addField() async {
    final result = await Navigator.push<CustomField>(
      context,
      MaterialPageRoute(
        builder: (context) => CustomFieldEditScreen(
          businessProfileId: widget.businessProfileId,
        ),
      ),
    );

    if (result != null) {
      await _repository.saveField(result);
      _loadFields();
    }
  }

  Future<void> _editField(CustomField field) async {
    final result = await Navigator.push<CustomField>(
      context,
      MaterialPageRoute(
        builder: (context) => CustomFieldEditScreen(
          businessProfileId: widget.businessProfileId,
          existingField: field,
        ),
      ),
    );

    if (result != null) {
      await _repository.saveField(result);
      _loadFields();
    }
  }

  Future<void> _deleteField(CustomField field) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('フィールド削除'),
        content: Text('「${field.fieldLabel}」を削除してもよろしいですか？\n関連するデータもすべて削除されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repository.deleteFieldAndValues(field.id);
        _loadFields();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('フィールドを削除しました')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('削除に失敗しました: $e')),
          );
        }
      }
    }
  }

  Future<void> _toggleFieldActive(CustomField field) async {
    final updatedField = field.copyWith(
      isActive: !field.isActive,
      updatedAt: DateTime.now(),
    );

    try {
      await _repository.saveField(updatedField);
      _loadFields();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _reorderFields() async {
    final result = await Navigator.push<List<CustomField>>(
      context,
      MaterialPageRoute(
        builder: (context) => CustomFieldReorderScreen(fields: _fields),
      ),
    );

    if (result != null) {
      try {
        for (int i = 0; i < result.length; i++) {
          await _repository.updateDisplayOrder(result[i].id, i);
        }
        _loadFields();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('順序の更新に失敗しました: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('C1:カスタムフィールド設定'),
        actions: [
          IconButton(
            icon: const Icon(Icons.reorder),
            onPressed: _fields.isNotEmpty ? _reorderFields : null,
            tooltip: '表示順序の変更',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _fields.isEmpty
              ? _buildEmptyState()
              : _buildFieldsList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _addField,
        tooltip: 'フィールドを追加',
        child: const Icon(Icons.add),
      ),
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
            'カスタムフィールドがありません',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '業種に合わせた独自フィールドを追加できます',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addField,
            icon: const Icon(Icons.add),
            label: const Text('最初のフィールドを追加'),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _fields.length,
      itemBuilder: (context, index) {
        final field = _fields[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              child: Icon(_getFieldTypeIcon(field.fieldType)),
            ),
            title: Text(field.fieldLabel),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(field.fieldName),
                const SizedBox(height: 4),
                Text(
                  field.fieldTypeName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: field.isActive,
                  onChanged: (_) => _toggleFieldActive(field),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _editField(field);
                        break;
                      case 'delete':
                        _deleteField(field);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit),
                        title: Text('編集'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete, color: Colors.red),
                        title: Text('削除', style: TextStyle(color: Colors.red)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
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
}
