import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class ContactPickerSheet extends StatefulWidget {
  const ContactPickerSheet({super.key, required this.contacts, this.title = '電話帳から選択'});

  final List<Contact> contacts;
  final String title;

  @override
  State<ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<ContactPickerSheet> {
  late List<Contact> _filtered;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = widget.contacts;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilter(String query) {
    final lower = query.toLowerCase();
    setState(() {
      _filtered = widget.contacts
          .where((contact) {
            final org = contact.organizations.isNotEmpty ? contact.organizations.first.company : '';
            final label = org.isNotEmpty ? org : contact.displayName;
            return label.toLowerCase().contains(lower);
          })
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: true,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (context, controller) {
          return Material(
            color: theme.scaffoldBackgroundColor,
            elevation: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(999)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(widget.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        tooltip: '閉じる',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: '会社名・氏名で検索',
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onChanged: _applyFilter,
                  ),
                ),
                Expanded(
                  child: _filtered.isEmpty
                      ? const Center(child: Text('一致する連絡先が見つかりません'))
                      : ListView.builder(
                          controller: controller,
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final contact = _filtered[index];
                            final org = contact.organizations.isNotEmpty ? contact.organizations.first.company : '';
                            final title = org.isNotEmpty ? org : contact.displayName;
                            final tel = contact.phones.isNotEmpty ? contact.phones.first.number : null;
                            final email = contact.emails.isNotEmpty ? contact.emails.first.address : null;
                            final subtitle = [tel, email].where((v) => v != null && v.trim().isNotEmpty).join(' / ');
                            return ListTile(
                              title: Text(title),
                              subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
                              leading: CircleAvatar(
                                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                                child: Text(title.isNotEmpty ? title.characters.first : '?'),
                              ),
                              onTap: () => Navigator.pop(context, contact),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
