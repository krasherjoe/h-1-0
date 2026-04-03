import 'dart:async';

import 'package:flutter/material.dart';

import 'master_field_config.dart';

class RichMasterSection {
  final String title;
  final String description;
  final List<MasterFieldConfig> fields;
  final List<RichAccessoryBuilder> accessories;

  const RichMasterSection({
    required this.title,
    required this.description,
    required this.fields,
    this.accessories = const [],
  });
}

typedef RichAccessoryBuilder = Widget Function(
  BuildContext context,
  RichMasterEditController controller,
);

typedef PreviewBuilder = Widget Function(
  BuildContext context,
  RichMasterEditController controller,
);

typedef InitialValuesBuilder<T> = Map<String, String> Function(T? existing);

typedef ModelBuilder<T> = T Function(Map<String, String> values);

class RichMasterEditController {
  RichMasterEditController(this.controllers, this.values, this.setDialogState);

  final Map<String, TextEditingController> controllers;
  final Map<String, String> values;
  final StateSetter setDialogState;

  TextEditingController? controllerOf(String key) => controllers[key];

  String valueOf(String key) => values[key] ?? '';

  void updateValue(String key, String value, {bool refresh = true}) {
    values[key] = value;
    if (controllers.containsKey(key) && controllers[key]!.text != value) {
      controllers[key]!
        ..text = value
        ..selection = TextSelection.collapsed(offset: value.length);
    }
    if (refresh) {
      setDialogState(() {});
    }
  }

  void refresh() => setDialogState(() {});
}

Future<T?> showRichMasterEditSheet<T>({
  required BuildContext context,
  required String titleNew,
  required String titleEdit,
  T? existing,
  required List<RichMasterSection> sections,
  required InitialValuesBuilder<T> initialValuesBuilder,
  required ModelBuilder<T> buildModel,
  FutureOr<String?> Function(Map<String, String> values)? onValidate,
  List<RichAccessoryBuilder> headerActions = const [],
  PreviewBuilder? previewBuilder,
}) async {
  final controllers = <String, TextEditingController>{};
  final values = <String, String>{};
  final initialValues = initialValuesBuilder(existing);

  for (final entry in initialValues.entries) {
    values[entry.key] = entry.value;
  }

  for (final section in sections) {
    for (final field in section.fields) {
      final initialText = values[field.key] ?? '';
      controllers[field.key] = TextEditingController(text: initialText);
      values[field.key] = initialText;
    }
  }

  T? result;

  try {
    result = await showDialog<T>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: false,
      builder: (dialogContext) {
        final viewInsets = MediaQuery.of(dialogContext).viewInsets;
        return MediaQuery.removeViewInsets(
          context: dialogContext,
          removeBottom: true,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              final width = MediaQuery.of(context).size.width;
              final maxWidth = width > 1080 ? 1040.0 : width - 32;
              final keyboardInset = viewInsets.bottom;
              final controller = RichMasterEditController(controllers, values, setDialogState);

              Widget buildField(MasterFieldConfig field) {
                final textController = controllers[field.key]!;
                Widget? suffix = field.suffixWidget;
                if (suffix == null && field.suffixBuilder != null) {
                  suffix = field.suffixBuilder!(
                    textController,
                    setDialogState,
                    (value) {
                      controller.updateValue(field.key, value, refresh: false);
                      setDialogState(() {});
                    },
                  );
                }

                final label = field.required ? '${field.label} *' : field.label;

                return TextField(
                  controller: textController,
                  decoration: InputDecoration(
                    labelText: label,
                    hintText: field.hint,
                    suffixIcon: suffix,
                    border: const OutlineInputBorder(),
                    counterText: field.maxLength != null ? '' : null,
                  ),
                  keyboardType: field.keyboardType,
                  maxLines: field.maxLines,
                  maxLength: field.maxLength,
                  onChanged: (value) {
                    controller.updateValue(field.key, value.trim(), refresh: false);
                    setDialogState(() {});
                  },
                );
              }

              Widget buildSectionCard(RichMasterSection section) {
                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 640;
                        final gap = 12.0;
                        final fullWidth = constraints.maxWidth;
                        final halfWidth = isWide ? (fullWidth - gap) / 2 : fullWidth;

                        final children = <Widget>[];
                        for (final field in section.fields) {
                          final spanWidth = (field.flex == 2 || !isWide) ? fullWidth : halfWidth;
                          children.add(SizedBox(
                            width: spanWidth,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: buildField(field),
                            ),
                          ));
                        }

                        for (final accessory in section.accessories) {
                          children.add(SizedBox(
                            width: fullWidth,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: accessory(context, controller),
                            ),
                          ));
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(section.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(section.description, style: const TextStyle(color: Colors.black54)),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: gap,
                              runSpacing: gap,
                              children: children,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                );
              }

              Future<void> handleSave() async {
                for (final field in sections.expand((s) => s.fields)) {
                  final value = controllers[field.key]!.text.trim();
                  controller.updateValue(field.key, value, refresh: false);
                  if (field.required && value.isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('${field.label}は必須です')),
                    );
                    setDialogState(() {});
                    return;
                  }
                  if (field.validator != null) {
                    final message = field.validator!(value);
                    if (message != null) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text(message)),
                      );
                      setDialogState(() {});
                      return;
                    }
                  }
                }

                if (onValidate != null) {
                  final message = await onValidate(values);
                  if (message != null) {
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text(message)),
                      );
                    }
                    return;
                  }
                }

                final model = buildModel(values);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, model);
                }
              }

              final sectionCards = sections.map(buildSectionCard).toList();

              return Dialog(
                insetPadding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: SizedBox(
                    width: maxWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      existing == null ? titleNew : titleEdit,
                                      style: Theme.of(context).textTheme.titleLarge,
                                    ),
                                    if (existing != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        values['displayName'] ?? '',
                                        style: const TextStyle(color: Colors.black54),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (headerActions.isNotEmpty)
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: headerActions
                                      .map((builder) => builder(context, controller))
                                      .toList(),
                                ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + keyboardInset),
                            child: Column(
                              children: [
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 16,
                                  children: sectionCards
                                      .map((card) => SizedBox(
                                            width: maxWidth > 960 ? (maxWidth - 16) / 2 : maxWidth,
                                            child: card,
                                          ))
                                      .toList(),
                                ),
                                if (previewBuilder != null) ...[
                                  const SizedBox(height: 16),
                                  previewBuilder(context, controller),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('キャンセル'),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.save),
                                label: const Text('保存'),
                                onPressed: handleSave,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  } finally {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    });
  }

  return result;
}
