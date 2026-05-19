import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../models/customer_model.dart';

/// 電話帳から顧客を選択するための検索機能付き画面
class PhonebookSelectionScreen extends StatefulWidget {
  const PhonebookSelectionScreen({super.key});

  @override
  State<PhonebookSelectionScreen> createState() =>
      _PhonebookSelectionScreenState();
}

class _PhonebookSelectionScreenState extends State<PhonebookSelectionScreen> {
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

  Future<void> _showContactDetail(Contact contact) async {
    // コントローラ・状態はダイアログWidget側で管理し、Flutterのライフサイクルに任せることで
    // dispose後の使用エラーを防ぐ
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ContactDetailDialog(contact: contact),
    );
    if (result != null && mounted) {
      // ダイアログを閉じた後、この画面自体も閉じて Map を返す
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: const Text('C4:電話帳から選択'),
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
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text('一致する連絡先が見つかりません'),
                        if (_searchController.text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '検索条件を変更して再度お試しください',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                            child: Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
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
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    // メールアドレス
    if (contact.emails.isNotEmpty) {
      if (parts.isNotEmpty) parts.add(const SizedBox(width: 8));
      parts.add(
        Text(
          contact.emails.first.address,
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    return Row(children: parts);
  }
}

/// 電話帳の生データから末尾の敬称を除去（様・御中・殿・先生・スペース区切り対応）
String _stripHonorific(String name) {
  return name.replaceAll(RegExp(r'[\s\u3000]*(様|御中|殿|先生)$'), '').trim();
}

/// 連絡先詳細ダイアログ
///
/// コントローラは State で管理し、dismiss アニメーション中の dispose 競合を避けるため
/// 明示的な dispose は行わない（短命ダイアログのため GC 任せで問題なし）。
class _ContactDetailDialog extends StatefulWidget {
  const _ContactDetailDialog({required this.contact});
  final Contact contact;

  @override
  State<_ContactDetailDialog> createState() => _ContactDetailDialogState();
}

class _ContactDetailDialogState extends State<_ContactDetailDialog> {
  late final String _orgCompany;
  late final String _person;
  late final List<String> _addresses;
  late final List<String> _emails;
  late final String? _tel;
  late final TextEditingController _displayNameController;
  late final TextEditingController _formalNameController;

  String _selectedNameSource = 'person';
  String? _selectedEmail;

  @override
  void initState() {
    super.initState();
    final contact = widget.contact;
    _orgCompany = contact.organizations.isNotEmpty
        ? contact.organizations.first.company
        : '';
    final personParts = [
      contact.name.last,
      contact.name.first,
    ].where((v) => v.isNotEmpty).toList();
    _person = personParts.isNotEmpty
        ? personParts.join(' ').trim()
        : contact.displayName;
    _addresses = contact.addresses
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
    _emails = contact.emails
        .map((e) => e.address)
        .where((e) => e.trim().isNotEmpty)
        .toList();
    _tel = contact.phones.isNotEmpty ? contact.phones.first.number : null;
    _selectedEmail = _emails.isNotEmpty ? _emails.first : null;
    _displayNameController =
        TextEditingController(text: _computeDisplay(_selectedNameSource));
    _formalNameController =
        TextEditingController(text: _computeFormal(_selectedNameSource));
  }

  String _computeDisplay(String source) =>
      source == 'company' && _orgCompany.isNotEmpty ? _orgCompany : _person;

  String _computeFormal(String source) =>
      source == 'company' && _orgCompany.isNotEmpty
          ? _orgCompany
          : '${_stripHonorific(_person)} 様';

  void _onSelected() {
    final customer = Customer(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      displayName: _displayNameController.text.trim(),
      formalName: _formalNameController.text.trim(),
      title: _selectedNameSource == 'company'
          ? HonorificCode.onchu
          : HonorificCode.san,
      department: null,
      address: _addresses.firstOrNull,
      tel: _tel,
      email: _selectedEmail,
      contactVersionId: null,
      odooId: null,
      isSynced: false,
      updatedAt: DateTime.now(),
      isLocked: false,
      isHidden: false,
    );
    Navigator.pop(context, {
      'customer': customer,
      'company': _orgCompany,
      'person': _person,
      'addresses': _addresses,
      'emails': _emails,
      'tel': _tel,
      'selectedNameSource': _selectedNameSource,
    });
  }

  @override
  Widget build(BuildContext context) {
    final tel = _tel;
    return AlertDialog(
      title: const Text('連絡先詳細'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顧客名の取り込み元選択
            const Text('顧客名の取り込み元'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'company', label: Text('会社名')),
                ButtonSegment(value: 'person', label: Text('氏名')),
              ],
              selected: {_selectedNameSource},
              onSelectionChanged: (values) {
                if (values.isEmpty) return;
                setState(() {
                  _selectedNameSource = values.first;
                  _displayNameController.text =
                      _computeDisplay(_selectedNameSource);
                  _formalNameController.text =
                      _computeFormal(_selectedNameSource);
                });
              },
            ),
            const SizedBox(height: 16),

            // 表示名（編集可）
            TextField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: '表示名',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),

            // 正式名称（編集可）
            TextField(
              controller: _formalNameController,
              decoration: const InputDecoration(
                labelText: '正式名称',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 8),

            // 電話番号
            if (tel != null && tel.isNotEmpty) ...[
              const Text('電話番号'),
              Text(tel),
              const SizedBox(height: 8),
            ],

            // メールアドレス（複数ある場合は選択）
            if (_emails.isNotEmpty) ...[
              const Text('メールアドレス'),
              if (_emails.length == 1)
                Text(_emails.first)
              else
                DropdownButtonFormField<String>(
                  initialValue: _selectedEmail,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _emails
                      .map(
                        (email) => DropdownMenuItem(
                          value: email,
                          child:
                              Text(email, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedEmail = value);
                    }
                  },
                ),
              const SizedBox(height: 8),
            ],

            // 住所
            if (_addresses.isNotEmpty) ...[
              const Text('住所'),
              ..._addresses.map((a) => Text(a)),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton.icon(
          onPressed: _onSelected,
          icon: const Icon(Icons.check),
          label: const Text('選択'),
        ),
      ],
    );
  }
}
