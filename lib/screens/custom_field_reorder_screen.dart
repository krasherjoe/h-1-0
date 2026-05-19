import 'package:flutter/material.dart';
import '../models/custom_field_model.dart';

/// カスタムフィールド順序変更画面
class CustomFieldReorderScreen extends StatefulWidget {
  final List<CustomField> fields;

  const CustomFieldReorderScreen({
    super.key,
    required this.fields,
  });

  @override
  State<CustomFieldReorderScreen> createState() => _CustomFieldReorderScreenState();
}

class _CustomFieldReorderScreenState extends State<CustomFieldReorderScreen> {
  late List<CustomField> _reorderedFields;

  @override
  void initState() {
    super.initState();
    _reorderedFields = List.from(widget.fields);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('C3:表示順序の変更'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _reorderedFields),
            child: const Text('完了'),
          ),
        ],
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reorderedFields.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) {
              newIndex -= 1;
            }
            final item = _reorderedFields.removeAt(oldIndex);
            _reorderedFields.insert(newIndex, item);
          });
        },
        itemBuilder: (context, index) {
          final field = _reorderedFields[index];
          return Card(
            key: ValueKey(field.id),
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                child: Text('${index + 1}'),
              ),
              title: Text(field.fieldLabel),
              subtitle: Text(field.fieldName),
              trailing: const Icon(Icons.drag_handle),
              tileColor: Theme.of(context).colorScheme.surface,
            ),
          );
        },
      ),
    );
  }
}
