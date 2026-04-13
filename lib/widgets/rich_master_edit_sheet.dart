import 'dart:async';
import 'dart:ui';

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
  // フッター（キャンセル/保存ボタン）の背景色（透明度設定用）
  Color? footerColor,
}) async {
  return showDialog<T>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: false,
    builder: (dialogContext) => _RichMasterEditDialog<T>(
      dialogContext: dialogContext,
      titleNew: titleNew,
      titleEdit: titleEdit,
      existing: existing,
      sections: sections,
      initialValuesBuilder: initialValuesBuilder,
      buildModel: buildModel,
      onValidate: onValidate,
      headerActions: headerActions,
      previewBuilder: previewBuilder,
      footerColor: footerColor,
    ),
  );
}

class _RichMasterEditDialog<T> extends StatefulWidget {
  final BuildContext dialogContext;
  final String titleNew;
  final String titleEdit;
  final T? existing;
  final List<RichMasterSection> sections;
  final InitialValuesBuilder<T> initialValuesBuilder;
  final ModelBuilder<T> buildModel;
  final FutureOr<String?> Function(Map<String, String> values)? onValidate;
  final List<RichAccessoryBuilder> headerActions;
  final PreviewBuilder? previewBuilder;
  final Color? footerColor;

  const _RichMasterEditDialog({
    required this.dialogContext,
    required this.titleNew,
    required this.titleEdit,
    this.existing,
    required this.sections,
    required this.initialValuesBuilder,
    required this.buildModel,
    this.onValidate,
    this.headerActions = const [],
    this.previewBuilder,
    this.footerColor,
  });

  @override
  State<_RichMasterEditDialog<T>> createState() =>
      _RichMasterEditDialogState<T>();
}

class _RichMasterEditDialogState<T>
    extends State<_RichMasterEditDialog<T>> {
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, String> _values;

  @override
  void initState() {
    super.initState();
    _controllers = {};
    _values = {};
    final initialValues = widget.initialValuesBuilder(widget.existing);
    for (final entry in initialValues.entries) {
      _values[entry.key] = entry.value;
    }
    for (final section in widget.sections) {
      for (final field in section.fields) {
        final initialText = _values[field.key] ?? '';
        _controllers[field.key] = TextEditingController(text: initialText);
        _values[field.key] = initialText;
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _buildField(
    MasterFieldConfig field,
    RichMasterEditController controller,
  ) {
    final textController = _controllers[field.key]!;
    Widget? suffix = field.suffixWidget;
    if (suffix == null && field.suffixBuilder != null) {
      suffix = field.suffixBuilder!(
        textController,
        setState,
        (value) {
          controller.updateValue(field.key, value, refresh: false);
          setState(() {});
        },
      );
    }

    final label = field.required ? '${field.label} *' : field.label;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: textController,
        decoration: InputDecoration(
          labelText: label,
          hintText: field.hint,
          suffixIcon: suffix,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade400, width: 2),
          ),
          counterText: field.maxLength != null ? '' : null,
        ),
        keyboardType: field.keyboardType,
        maxLines: field.maxLines,
        maxLength: field.maxLength,
        onChanged: (value) {
          controller.updateValue(field.key, value.trim(), refresh: false);
          setState(() {});
        },
      ),
    );
  }

  Widget _buildSectionCard(
    RichMasterSection section,
    RichMasterEditController controller,
  ) {
    return Card(
      elevation: 8,
      color: Colors.grey.shade200,
      shadowColor: Colors.black.withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 640;
            const gap = 12.0;
            final fullWidth = constraints.maxWidth;
            final halfWidth = isWide ? (fullWidth - gap) / 2 : fullWidth;

            final children = <Widget>[];
            for (final field in section.fields) {
              final spanWidth =
                  (field.flex == 2 || !isWide) ? fullWidth : halfWidth;
              children.add(SizedBox(
                width: spanWidth,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: _buildField(field, controller),
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
                Text(
                  section.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  section.description,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 16),
                Wrap(spacing: gap, runSpacing: gap, children: children),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleSave(RichMasterEditController controller) async {
    for (final field in widget.sections.expand((s) => s.fields)) {
      final value = _controllers[field.key]!.text.trim();
      controller.updateValue(field.key, value, refresh: false);
      if (field.required && value.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${field.label}は必須です')),
          );
        }
        setState(() {});
        return;
      }
      if (field.validator != null) {
        final message = field.validator!(value);
        if (message != null) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
          }
          setState(() {});
          return;
        }
      }
    }

    if (widget.onValidate != null) {
      final messenger = ScaffoldMessenger.of(context);
      final nav = Navigator.of(context);
      final message = await widget.onValidate!(_values);
      if (message != null) {
        if (mounted) {
          messenger.showSnackBar(SnackBar(content: Text(message)));
        }
        return;
      }
      final model = widget.buildModel(_values);
      if (mounted) {
        nav.pop(model);
      }
      return;
    }

    final model = widget.buildModel(_values);
    if (context.mounted) {
      Navigator.pop(context, model);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenWidth = mq.size.width;
    final screenHeight = mq.size.height;
    final maxWidth = screenWidth > 1080 ? 1040.0 : screenWidth - 32;
    final maxHeight = screenHeight * 0.85;
    final keyboardInset = mq.viewInsets.bottom;

    final richController = RichMasterEditController(_controllers, _values, setState);
    final sectionCards = widget.sections
        .map((s) => _buildSectionCard(s, richController))
        .toList();

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: SizedBox(
          width: maxWidth,
          child: Column(
            children: [
              ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    color: Colors.white.withOpacity(0.05),
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.existing == null
                                    ? widget.titleNew
                                    : widget.titleEdit,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              if (widget.existing != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _values['displayName'] ?? '',
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (widget.headerActions.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: widget.headerActions
                                .map((builder) => builder(context, richController))
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 72 + keyboardInset),
                      child: Column(
                        children: [
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: sectionCards
                                .map((card) => SizedBox(
                                      width: maxWidth > 960
                                          ? (maxWidth - 16) / 2
                                          : maxWidth,
                                      child: card,
                                    ))
                                .toList(),
                          ),
                          if (widget.previewBuilder != null) ...[
                            const SizedBox(height: 16),
                            widget.previewBuilder!(context, richController),
                          ],
                        ],
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            color: Colors.white.withOpacity(0.15),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('キャンセル'),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.save),
                                  label: const Text('保存'),
                                  onPressed: () => _handleSave(richController),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
