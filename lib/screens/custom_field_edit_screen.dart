import 'package:flutter/material.dart';
import '../models/custom_field_model.dart';
import '../services/custom_field_repository.dart';
import '../widgets/zoomable_app_bar.dart';

/// カスタムフィールド編集画面
class CustomFieldEditScreen extends StatefulWidget {
  final String businessProfileId;
  final CustomField? existingField;

  const CustomFieldEditScreen({
    super.key,
    required this.businessProfileId,
    this.existingField,
  });

  @override
  State<CustomFieldEditScreen> createState() => _CustomFieldEditScreenState();
}

class _CustomFieldEditScreenState extends State<CustomFieldEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final CustomFieldRepository _repository = CustomFieldRepository();
  
  final _fieldNameController = TextEditingController();
  final _fieldLabelController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _defaultValueController = TextEditingController();
  
  CustomFieldType _selectedType = CustomFieldType.text;
  CustomFieldValidation _validation = const CustomFieldValidation();
  bool _isRequired = false;
  int? _minLength;
  int? _maxLength;
  double? _minValue;
  double? _maxValue;
  String? _pattern;
  List<String> _options = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingField != null) {
      _initializeFromExistingField();
    }
  }

  void _initializeFromExistingField() {
    final field = widget.existingField!;
    _fieldNameController.text = field.fieldName;
    _fieldLabelController.text = field.fieldLabel;
    _descriptionController.text = field.description ?? '';
    _defaultValueController.text = field.defaultValue ?? '';
    _selectedType = field.fieldType;
    _validation = field.validation;
    _isRequired = _validation.required;
    _minLength = _validation.minLength;
    _maxLength = _validation.maxLength;
    _minValue = _validation.min;
    _maxValue = _validation.max;
    _pattern = _validation.pattern;
    _options = _validation.options ?? [];
  }

  Future<void> _saveField() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // フィールド名の重複チェック
    final nameExists = await _repository.fieldNameExists(
      widget.businessProfileId,
      _fieldNameController.text,
      excludeId: widget.existingField?.id,
    );

    if (nameExists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('このフィールド名は既に使用されています')),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final validation = CustomFieldValidation(
        required: _isRequired,
        minLength: _minLength,
        maxLength: _maxLength,
        min: _minValue,
        max: _maxValue,
        pattern: _pattern,
        options: _options.isNotEmpty ? _options : null,
      );

      final field = widget.existingField != null
          ? widget.existingField!.copyWith(
              fieldName: _fieldNameController.text,
              fieldLabel: _fieldLabelController.text,
              fieldType: _selectedType,
              validation: validation,
              description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
              defaultValue: _defaultValueController.text.isEmpty ? null : _defaultValueController.text,
              updatedAt: DateTime.now(),
            )
          : CustomField.create(
              businessProfileId: widget.businessProfileId,
              fieldName: _fieldNameController.text,
              fieldLabel: _fieldLabelController.text,
              fieldType: _selectedType,
              validation: validation,
              description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
              defaultValue: _defaultValueController.text.isEmpty ? null : _defaultValueController.text,
            );

      if (mounted) {
        Navigator.pop(context, field);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addOption() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('選択肢を追加'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '選択肢',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty && !_options.contains(value)) {
              setState(() {
                _options.add(value);
              });
            }
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );
  }

  void _removeOption(String option) {
    setState(() {
      _options.remove(option);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ZoomableAppBar(
      appBar: AppBar(
        title: Text(widget.existingField != null ? 'C2:フィールド編集' : 'C2:フィールド追加'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveField,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '基本情報',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _fieldNameController,
                      decoration: const InputDecoration(
                        labelText: 'フィールド名 *',
                        hintText: '半角英数字とアンダースコア',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'フィールド名を入力してください';
                        }
                        if (!RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(value)) {
                          return '半角英数字とアンダースコアで入力してください';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _fieldLabelController,
                      decoration: const InputDecoration(
                        labelText: '表示ラベル *',
                        hintText: '画面に表示する名前',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '表示ラベルを入力してください';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<CustomFieldType>(
                      initialValue: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'フィールドタイプ *',
                        border: OutlineInputBorder(),
                      ),
                      items: CustomFieldType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedType = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: '説明',
                        hintText: 'フィールドの説明',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'バリデーション',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('必須項目'),
                      subtitle: const Text('このフィールドを必須にする'),
                      value: _isRequired,
                      onChanged: (value) {
                        setState(() {
                          _isRequired = value;
                        });
                      },
                    ),
                    if (_selectedType == CustomFieldType.text || 
                        _selectedType == CustomFieldType.textarea) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: '最小文字数',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        initialValue: _minLength?.toString(),
                        onChanged: (value) {
                          _minLength = int.tryParse(value);
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: '最大文字数',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        initialValue: _maxLength?.toString(),
                        onChanged: (value) {
                          _maxLength = int.tryParse(value);
                        },
                      ),
                    ],
                    if (_selectedType == CustomFieldType.number || 
                        _selectedType == CustomFieldType.currency) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: '最小値',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        initialValue: _minValue?.toString(),
                        onChanged: (value) {
                          _minValue = double.tryParse(value);
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: '最大値',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        initialValue: _maxValue?.toString(),
                        onChanged: (value) {
                          _maxValue = double.tryParse(value);
                        },
                      ),
                    ],
                    if (_selectedType == CustomFieldType.email) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: '正規表現パターン',
                          hintText: '例: ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}\$',
                          border: OutlineInputBorder(),
                        ),
                        initialValue: _pattern,
                        onChanged: (value) {
                          _pattern = value.isEmpty ? null : value;
                        },
                      ),
                    ],
                    if (_selectedType == CustomFieldType.select ||
                        _selectedType == CustomFieldType.multiselect) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '選択肢',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _addOption,
                            icon: const Icon(Icons.add),
                            label: const Text('追加'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_options.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '選択肢を追加してください',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      else
                        ..._options.map((option) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(option),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () => _removeOption(option),
                                icon: const Icon(Icons.remove_circle, color: Colors.red),
                              ),
                            ],
                          ),
                        )),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '既定値',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _defaultValueController,
                      decoration: const InputDecoration(
                        labelText: '既定値',
                        hintText: '初期値として設定する値',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
