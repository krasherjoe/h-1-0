import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../models/supplier_model.dart';

/// 電話帳から仕入先を選択するための検索機能付き画面
class SupplierPhonebookSelectionScreen extends StatefulWidget {
  const SupplierPhonebookSelectionScreen({super.key});

  @override
  State<SupplierPhonebookSelectionScreen> createState() =>
      _SupplierPhonebookSelectionScreenState();
}

class _SupplierPhonebookSelectionScreenState
    extends State<SupplierPhonebookSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Contact> _allContacts = [];
  List<Contact> _filteredContacts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final hasPermission = await FlutterContacts.requestPermission(
        readonly: true,
      );
      if (!mounted) return;

      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('連絡先の権限がありません')));
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 必要なフィールドのみ取得（高速化）
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withAccounts: false,
        withPhoto: false,
        withThumbnail: false,
        withGroups: false,
      );

      if (!mounted) return;

      setState(() {
        _allContacts = contacts;
        _filteredContacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('連絡先の読み込みに失敗しました：$e')));
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterContacts(String query) {
    // 非同期で検索を実行（UI ブロック防止）
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted) return;

      final lowerQuery = query.toLowerCase();
      final filtered = _allContacts.where((contact) {
        // 名前、電話番号、メールで検索
        final nameMatch = contact.displayName.toLowerCase().contains(
          lowerQuery,
        );
        final phoneMatch = contact.phones.any(
          (p) => p.number.toLowerCase().contains(lowerQuery),
        );
        final emailMatch = contact.emails.any(
          (e) => e.address.toLowerCase().contains(lowerQuery),
        );

        return nameMatch || phoneMatch || emailMatch;
      }).toList();

      if (mounted) {
        setState(() {
          _filteredContacts = filtered;
        });
      }
    });
  }

  Future<Map<String, dynamic>?> _showContactDetail(Contact contact) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          String selectedNameSource = 'person';

          // 会社名、氏名の取得
          final orgCompany = contact.organizations.isNotEmpty
              ? contact.organizations.first.company
              : '';
          final personParts = [
            contact.name.last,
            contact.name.first,
          ].where((v) => v.isNotEmpty).toList();
          final person = personParts.isNotEmpty
              ? personParts.join(' ').trim()
              : contact.displayName;

          // 住所、メールの取得
          final addresses = contact.addresses
              .map(
                (a) => [
                  a.postalCode,
                  a.state,
                  a.city,
                  a.street,
                  a.country,
                ].where((v) => v.isNotEmpty).join(' '),
              )
              .where((s) => s.trim().isNotEmpty)
              .toList();

          final emails = contact.emails
              .map((e) => e.address)
              .where((e) => e.trim().isNotEmpty)
              .toList();

          final tel = contact.phones.isNotEmpty
              ? contact.phones.first.number
              : null;

          return AlertDialog(
            title: const Text('連絡先詳細'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 仕入先名の取り込み元選択
                  const Text('仕入先名の取り込み元'),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'company', label: Text('会社名')),
                      ButtonSegment(value: 'person', label: Text('氏名')),
                    ],
                    selected: {selectedNameSource},
                    onSelectionChanged: (values) {
                      if (values.isEmpty) return;
                      setDialogState(() {
                        selectedNameSource = values.first;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // 表示名
                  TextField(
                    decoration: const InputDecoration(
                      labelText: '表示名',
                      border: OutlineInputBorder(),
                    ),
                    readOnly: true,
                    controller: TextEditingController(
                      text:
                          selectedNameSource == 'company' &&
                              orgCompany.isNotEmpty
                          ? orgCompany
                          : person,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 正式名称（自動生成）
                  TextField(
                    decoration: const InputDecoration(
                      labelText: '正式名称',
                      border: OutlineInputBorder(),
                    ),
                    readOnly: true,
                    controller: TextEditingController(
                      text:
                          selectedNameSource == 'company' &&
                              orgCompany.isNotEmpty
                          ? orgCompany
                          : '${_stripHonorific(person)} 様',
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 電話番号
                  if (tel != null && tel.isNotEmpty) ...[
                    const Text('電話番号'),
                    Text(tel),
                    const SizedBox(height: 8),
                  ],

                  // メールアドレス
                  if (emails.isNotEmpty) ...[
                    const Text('メールアドレス'),
                    ...emails.map((e) => Text(e)),
                    const SizedBox(height: 8),
                  ],

                  // 住所
                  if (addresses.isNotEmpty) ...[
                    const Text('住所'),
                    ...addresses.map((a) => Text(a)),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('キャンセル'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext, {
                    'displayName':
                        selectedNameSource == 'company' && orgCompany.isNotEmpty
                            ? orgCompany
                            : person,
                    'formalName':
                        selectedNameSource == 'company' && orgCompany.isNotEmpty
                            ? orgCompany
                            : '${_stripHonorific(person)} 様',
                    'contactPerson': person,
                    'tel': tel,
                    'email': emails.firstOrNull,
                    'address': addresses.firstOrNull,
                    'company': orgCompany,
                  });
                },
                icon: const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                label: const Text('選択'),
              ),
            ],
          );
        },
      ),
    );

    return result;
  }

  /// 電話帳の生データから末尾の敬称を除去（様・御中・殿・先生・スペース区切り対応）
  static String _stripHonorific(String name) {
    return name.replaceAll(RegExp(r'[\s\u3000]*(様|御中|殿|先生)$'), '').trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('電話帳から選択'),
        actions: [
          if (_filteredContacts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_filteredContacts.length}件中',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 検索バー
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '名前、電話番号、メールで検索',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterContacts('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _filterContacts,
            ),
          ),

          // 結果リスト
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredContacts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text('一致する連絡先が見つかりません'),
                        if (_searchController.text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '検索条件を変更して再度お試しください',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredContacts.length,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (context, index) {
                      final contact = _filteredContacts[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange.shade100,
                            child: Icon(Icons.business, color: Colors.orange),
                          ),
                          title: Text(
                            contact.displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: _getContactSubtitle(contact),
                          trailing: IconButton(
                            icon: const Icon(Icons.arrow_forward_ios, size: 16),
                            onPressed: () => _showContactDetail(contact),
                          ),
                          onTap: () => _showContactDetail(contact),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _getContactSubtitle(Contact contact) {
    final parts = <Widget>[];

    // 電話番号
    if (contact.phones.isNotEmpty) {
      parts.add(
        Text(
          contact.phones.first.number,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    // メールアドレス
    if (contact.emails.isNotEmpty) {
      if (parts.isNotEmpty) parts.add(const SizedBox(width: 8));
      parts.add(
        Text(
          contact.emails.first.address,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    return Row(children: parts);
  }
}
