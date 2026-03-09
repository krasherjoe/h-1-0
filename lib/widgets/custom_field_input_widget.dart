import 'package:flutter/material.dart';
import '../models/custom_field_model.dart';
import '../services/custom_field_repository.dart';

/// カスタムフィールド入力ウィジェット
class CustomFieldInputWidget extends StatefulWidget {
  final String entityId;
  final String entityType;
  final List<CustomField> fields;
  final Map<String, dynamic>? initialValues;
  final Function(Map<String, dynamic>)? onChanged;
  final bool enabled;

  const CustomFieldInputWidget({
    super.key,
    required this.entityId,
    required this.entityType,
    required this.fields,
    this.initialValues,
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<CustomFieldInputWidget> createState() => _CustomFieldInputWidgetState();
}

class _CustomFieldInputWidgetState extends State<CustomFieldInputWidget> {
  final CustomFieldRepository _repository = CustomFieldRepository();
  final Map<String, dynamic> _values = {};
  final Map<String, TextEditingController> _controllers = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeValues();
    _loadSavedValues();
  }

  void _initializeValues() {
    // 初期値を設定
    for (final field in widget.fields) {
      final initialValue = widget.initialValues?[field.fieldName] ?? field.defaultValue;
      _values[field.fieldName] = initialValue;
      
      // コントローラを初期化
      if (_needsController(field.fieldType)) {
        _controllers[field.fieldName] = TextEditingController(
          text: initialValue?.toString() ?? '',
        );
      }
    }
  }

  bool _needsController(CustomFieldType type) {
    return [
      CustomFieldType.text,
      CustomFieldType.number,
      CustomFieldType.email,
      CustomFieldType.phone,
      CustomFieldType.url,
      CustomFieldType.textarea,
      CustomFieldType.currency,
    ].contains(type);
  }

  Future<void> _loadSavedValues() async {
    if (widget.entityId.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final savedValues = await _repository.getEntityFieldValues(
        widget.entityId,
        widget.entityType,
      );

      for (final field in widget.fields) {
        final value = savedValues[field.fieldName];
        if (value != null) {
          _values[field.fieldName] = value;
          
          // コントローラを更新
          final controller = _controllers[field.fieldName];
          if (controller != null) {
            controller.text = value.toString();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('カスタムフィールド値の読み込みに失敗しました: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveValues() async {
    if (widget.entityId.isEmpty) return;

    try {
      for (final field in widget.fields) {
        final value = _values[field.fieldName];
        await _repository.setFieldValue(
          customFieldId: field.id,
          entityId: widget.entityId,
          entityType: widget.entityType,
          value: value,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('カスタムフィールドを保存しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    }
  }

  void _updateValue(String fieldName, dynamic value) {
    setState(() {
      _values[fieldName] = value;
    });

    widget.onChanged?.call(_values);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.fields.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Text(
          'カスタムフィールドがありません',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final field in widget.fields) ...[
          _buildFieldInput(field),
          const SizedBox(height: 16),
        ],
        if (widget.enabled) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () {
                  _initializeValues();
                  _loadSavedValues();
                },
                child: const Text('リセット'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _saveValues,
                child: const Text('保存'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildFieldInput(CustomField field) {
    final label = field.fieldLabel;
    final required = field.validation.required;

    switch (field.fieldType) {
      case CustomFieldType.text:
        return TextFormField(
          controller: _controllers[field.fieldName],
          decoration: InputDecoration(
            labelText: required ? '$label *' : label,
            border: const OutlineInputBorder(),
          ),
          enabled: widget.enabled,
          validator: required
              ? (val) => val?.isEmpty == true ? 'この項目は必須です' : null
              : null,
          onChanged: (val) => _updateValue(field.fieldName, val),
        );

      case CustomFieldType.textarea:
        return TextFormField(
          controller: _controllers[field.fieldName],
          decoration: InputDecoration(
            labelText: required ? '$label *' : label,
            border: const OutlineInputBorder(),
          ),
          maxLines: 3,
          enabled: widget.enabled,
          validator: required
              ? (val) => val?.isEmpty == true ? 'この項目は必須です' : null
              : null,
          onChanged: (val) => _updateValue(field.fieldName, val),
        );

      case CustomFieldType.number:
        return TextFormField(
          controller: _controllers[field.fieldName],
          decoration: InputDecoration(
            labelText: required ? '$label *' : label,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          enabled: widget.enabled,
          validator: (val) {
            if (required && (val?.isEmpty == true)) {
              return 'この項目は必須です';
            }
            if (val != null && val.isNotEmpty) {
              final num = double.tryParse(val);
              if (num == null) {
                return '有効な数値を入力してください';
              }
              if (field.validation.min != null && num < field.validation.min!) {
                return '${field.validation.min}以上の値を入力してください';
              }
              if (field.validation.max != null && num > field.validation.max!) {
                return '${field.validation.max}以下の値を入力してください';
              }
            }
            return null;
          },
          onChanged: (val) {
            final num = val.isEmpty ? null : double.tryParse(val);
            _updateValue(field.fieldName, num);
          },
        );

      case CustomFieldType.currency:
        return TextFormField(
          controller: _controllers[field.fieldName],
          decoration: InputDecoration(
            labelText: required ? '$label *' : label,
            border: const OutlineInputBorder(),
            prefixText: '¥',
          ),
          keyboardType: TextInputType.number,
          enabled: widget.enabled,
          validator: (val) {
            if (required && (val?.isEmpty == true)) {
              return 'この項目は必須です';
            }
            if (val != null && val.isNotEmpty) {
              final num = double.tryParse(val);
              if (num == null) {
                return '有効な金額を入力してください';
              }
              if (field.validation.min != null && num < field.validation.min!) {
                return '${field.validation.min}以上の値を入力してください';
              }
              if (field.validation.max != null && num > field.validation.max!) {
                return '${field.validation.max}以下の値を入力してください';
              }
            }
            return null;
          },
          onChanged: (val) {
            final num = val.isEmpty ? null : double.tryParse(val);
            _updateValue(field.fieldName, num);
          },
        );

      case CustomFieldType.date:
        return InkWell(
          onTap: widget.enabled ? () => _selectDate(field) : null,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: required ? '$label *' : label,
              border: const OutlineInputBorder(),
              suffixIcon: const Icon(Icons.calendar_today),
            ),
            child: Text(
              _values[field.fieldName] != null ? _formatDate(_values[field.fieldName]) : '日付を選択',
              style: TextStyle(
                color: _values[field.fieldName] != null ? null : Colors.grey,
              ),
            ),
          ),
        );

      case CustomFieldType.datetime:
        return InkWell(
          onTap: widget.enabled ? () => _selectDateTime(field) : null,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: required ? '$label *' : label,
              border: const OutlineInputBorder(),
              suffixIcon: const Icon(Icons.schedule),
            ),
            child: Text(
              _values[field.fieldName] != null ? _formatDateTime(_values[field.fieldName]) : '日時を選択',
              style: TextStyle(
                color: _values[field.fieldName] != null ? null : Colors.grey,
              ),
            ),
          ),
        );

      case CustomFieldType.select:
        return DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: required ? '$label *' : label,
            border: const OutlineInputBorder(),
          ),
          initialValue: _values[field.fieldName]?.toString(),
          items: field.validation.options?.map((option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Text(option),
            );
          }).toList(),
          validator: required
              ? (val) => val == null ? 'この項目は必須です' : null
              : null,
          onChanged: widget.enabled
              ? (val) => _updateValue(field.fieldName, val)
              : null,
        );

      case CustomFieldType.multiselect:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              required ? '$label *' : label,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: field.validation.options?.map((option) {
                final isSelected = (_values[field.fieldName] as List<dynamic>?)?.contains(option) ?? false;
                return FilterChip(
                  label: Text(option),
                  selected: isSelected,
                  onSelected: widget.enabled
                      ? (selected) {
                          final currentList = List<dynamic>.from(_values[field.fieldName] ?? []);
                          if (selected) {
                            currentList.add(option);
                          } else {
                            currentList.remove(option);
                          }
                          _updateValue(field.fieldName, currentList);
                        }
                      : null,
                );
              }).toList() ?? [],
            ),
          ],
        );

      case CustomFieldType.checkbox:
        return CheckboxListTile(
          title: Text(label),
          value: _values[field.fieldName] == true,
          onChanged: widget.enabled
              ? (val) => _updateValue(field.fieldName, val)
              : null,
        );

      case CustomFieldType.email:
        return TextFormField(
          controller: _controllers[field.fieldName],
          decoration: InputDecoration(
            labelText: required ? '$label *' : label,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.email),
          ),
          keyboardType: TextInputType.emailAddress,
          enabled: widget.enabled,
          validator: (val) {
            if (required && (val?.isEmpty == true)) {
              return 'この項目は必須です';
            }
            if (val != null && val.isNotEmpty) {
              final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
              if (!emailRegex.hasMatch(val)) {
                return '有効なメールアドレスを入力してください';
              }
            }
            return null;
          },
          onChanged: (val) => _updateValue(field.fieldName, val),
        );

      case CustomFieldType.phone:
        return TextFormField(
          controller: _controllers[field.fieldName],
          decoration: InputDecoration(
            labelText: required ? '$label *' : label,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.phone),
          ),
          keyboardType: TextInputType.phone,
          enabled: widget.enabled,
          validator: required
              ? (val) => val?.isEmpty == true ? 'この項目は必須です' : null
              : null,
          onChanged: (val) => _updateValue(field.fieldName, val),
        );

      case CustomFieldType.url:
        return TextFormField(
          controller: _controllers[field.fieldName],
          decoration: InputDecoration(
            labelText: required ? '$label *' : label,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.link),
          ),
          keyboardType: TextInputType.url,
          enabled: widget.enabled,
          validator: required
              ? (val) => val?.isEmpty == true ? 'この項目は必須です' : null
              : null,
          onChanged: (val) => _updateValue(field.fieldName, val),
        );
    }
  }

  Future<void> _selectDate(CustomField field) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _values[field.fieldName] is DateTime ? _values[field.fieldName] : DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      _updateValue(field.fieldName, picked);
    }
  }

  Future<void> _selectDateTime(CustomField field) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _values[field.fieldName] is DateTime ? _values[field.fieldName] : DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_values[field.fieldName] is DateTime ? _values[field.fieldName] : DateTime.now()),
      );

      if (pickedTime != null) {
        final dateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        _updateValue(field.fieldName, dateTime);
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${_formatDate(dateTime)} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
