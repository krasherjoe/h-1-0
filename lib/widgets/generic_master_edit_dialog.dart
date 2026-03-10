import 'package:flutter/material.dart';
import 'master_field_config.dart';

/// 汎用マスタ編集ダイアログ
Future<T?> showMasterEditDialog<T>({
  required BuildContext context,
  required String titleNew,        // "顧客を新規登録"
  required String titleEdit,       // "顧客を編集"
  required List<MasterFieldConfig> fields,
  List<MasterFieldGroup>? groups,  // 特殊UIグループ
  T? existing,                     // 編集対象（null=新規）
  required Map<String, dynamic> Function(T?) initialValues,
  required T Function(Map<String, dynamic> values) buildModel,
  List<Widget> Function(BuildContext, StateSetter)? extraWidgets,
  Future<String?> Function(Map<String, dynamic>)? onValidate, // 重複チェック等
}) async {
  final isEdit = existing != null;
  final values = initialValues(existing);
  final controllers = <String, TextEditingController>{};
  
  // コントローラー初期化
  for (final field in fields) {
    controllers[field.key] = TextEditingController(text: values[field.key]?.toString() ?? '');
  }
  
  // グループの初期値
  for (final group in groups ?? []) {
    values[group.key] = values[group.key] ?? group.options.first;
  }
  
  final result = await showDialog<T>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        final inset = MediaQuery.of(context).viewInsets.bottom;
        return MediaQuery.removeViewInsets(
          removeBottom: true,
          context: context,
          child: AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: Text(isEdit ? titleEdit : titleNew),
            content: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(bottom: inset + 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 通常フィールド
                  ...fields.map((field) {
                    final controller = controllers[field.key]!;
                    Widget? suffixWidget = field.suffixWidget;
                    if (suffixWidget == null && field.suffixBuilder != null) {
                      suffixWidget = field.suffixBuilder!(
                        controller,
                        setDialogState,
                        (value) {
                          setDialogState(() {
                            controller.text = value;
                            values[field.key] = value.trim();
                          });
                        },
                      );
                    }

                    Widget textField = TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: field.label,
                        hintText: field.hint,
                        border: const OutlineInputBorder(),
                        counterText: field.maxLength != null ? '' : null,
                      ),
                      keyboardType: field.keyboardType,
                      maxLines: field.maxLines,
                      maxLength: field.maxLength,
                      onChanged: (value) => values[field.key] = value.trim(),
                    );

                    if (suffixWidget != null) {
                      textField = Row(
                        children: [
                          Expanded(child: textField),
                          const SizedBox(width: 8),
                          suffixWidget,
                        ],
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: textField,
                    );
                  }),
                  
                  // グループフィールド
                  ...(groups ?? []).map((group) {
                    switch (group.type) {
                      case MasterFieldType.segment:
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(group.label, style: const TextStyle(fontSize: 16)),
                              const SizedBox(height: 4),
                              SegmentedButton<String>(
                                segments: group.options.map((option) => 
                                  ButtonSegment(value: option, label: Text(option))
                                ).toList(),
                                selected: {values[group.key] as String},
                                onSelectionChanged: (selections) {
                                  if (selections.isNotEmpty) {
                                    setDialogState(() => values[group.key] = selections.first);
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      case MasterFieldType.dropdown:
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: DropdownButtonFormField<String>(
                            initialValue: values[group.key] as String,
                            decoration: InputDecoration(
                              labelText: group.label,
                              border: const OutlineInputBorder(),
                            ),
                            items: group.options.map((option) => 
                              DropdownMenuItem(value: option, child: Text(option))
                            ).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() => values[group.key] = value);
                              }
                            },
                          ),
                        );
                      case MasterFieldType.row:
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(group.label, style: const TextStyle(fontSize: 16)),
                              const SizedBox(height: 4),
                              Row(
                                children: group.children?.map((child) => 
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: TextField(
                                        controller: controllers[child.key]!,
                                        decoration: InputDecoration(
                                          labelText: child.label,
                                          hintText: child.hint,
                                          counterText: child.maxLength != null ? '' : null,
                                        ),
                                        maxLength: child.maxLength,
                                        onChanged: (value) => values[child.key] = value.trim(),
                                      ),
                                    ),
                                  )
                                ).toList() ?? [],
                              ),
                            ],
                          ),
                        );
                    }
                  }),
                  
                  // 追加ウィジェット
                  ...(extraWidgets?.call(context, setDialogState) ?? []),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // 必須フィールドチェック
                  for (final field in fields) {
                    if (field.required && (values[field.key]?.toString().trim().isEmpty ?? true)) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${field.label}は必須です')),
                        );
                      }
                      return;
                    }
                  }
                  
                  // カスタムバリデーション
                  for (final field in fields) {
                    if (field.validator != null) {
                      final error = field.validator!(values[field.key]?.toString() ?? '');
                      if (error != null) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error)),
                          );
                        }
                        return;
                      }
                    }
                  }
                  
                  // 追加バリデーション
                  if (onValidate != null) {
                    final error = await onValidate(values);
                    if (error != null) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error)),
                        );
                      }
                      return;
                    }
                  }
                  
                  // モデル構築
                  final model = buildModel(values);
                  if (context.mounted) {
                    Navigator.pop(context, model);
                  }
                },
                child: const Text('保存'),
              ),
            ],
          ),
        );
      },
    ),
  );
  
  // コントローラー破棄
  for (final controller in controllers.values) {
    controller.dispose();
  }
  
  return result;
}
