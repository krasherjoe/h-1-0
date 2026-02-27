import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../widgets/keyboard_inset_wrapper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/customer_model.dart';
import '../services/customer_repository.dart';

class CustomerMasterScreen extends StatefulWidget {
  final bool selectionMode;

  const CustomerMasterScreen({super.key, this.selectionMode = false});

  @override
  State<CustomerMasterScreen> createState() => _CustomerMasterScreenState();
}

class _CustomerMasterScreenState extends State<CustomerMasterScreen> {
  final CustomerRepository _customerRepo = CustomerRepository();
  final TextEditingController _searchController = TextEditingController();
  List<Customer> _customers = [];
  List<Customer> _filtered = [];
  bool _isLoading = true;
  String _sortKey = 'name_asc';
  bool _ignoreCorpPrefix = true;
  Map<String, String> _userKanaMap = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _customerRepo.ensureCustomerColumns();
    await _loadUserKanaMap();
    if (!context.mounted) return;
    _ensureKanaMapsUsed();
    await _loadCustomers();
  }

  Map<String, String> _buildDefaultKanaMap() {
    return {
      // あ行
      '安': 'あ', '阿': 'あ', '浅': 'あ', '麻': 'あ', '新': 'あ', '青': 'あ', '赤': 'あ', '秋': 'あ', '明': 'あ', '有': 'あ', '伊': 'あ',
      // か行
      '加': 'か', '鎌': 'か', '上': 'か', '川': 'か', '河': 'か', '北': 'か', '木': 'か', '菊': 'か', '岸': 'か',
      '工': 'か', '古': 'か', '後': 'か', '郡': 'か', '熊': 'か', '桑': 'か', '黒': 'か', '香': 'か', '金': 'か', '兼': 'か', '小': 'か',
      // さ行
      '佐': 'さ', '齋': 'さ', '齊': 'さ', '斎': 'さ', '斉': 'さ', '崎': 'さ', '柴': 'さ', '沢': 'さ', '澤': 'さ', '桜': 'さ', '櫻': 'さ',
      '酒': 'さ', '坂': 'さ', '榊': 'さ', '札': 'さ', '庄': 'し', '城': 'し', '島': 'さ', '嶋': 'さ', '鈴': 'す',
      // た行
      '田': 'た', '高': 'た', '竹': 'た', '滝': 'た', '瀧': 'た', '立': 'た', '達': 'た', '谷': 'た', '多': 'た', '千': 'た', '太': 'た',
      // な行
      '中': 'な', '永': 'な', '長': 'な', '南': 'な', '難': 'な',
      // は行
      '橋': 'は', '林': 'は', '原': 'は', '浜': 'は', '服': 'は', '福': 'は', '藤': 'は', '富': 'は', '保': 'は', '畠': 'は', '畑': 'は',
      // ま行
      '松': 'ま', '前': 'ま', '真': 'ま', '町': 'ま', '間': 'ま', '馬': 'ま',
      // や行
      '山': 'や', '矢': 'や', '柳': 'や',
      // ら行
      '良': 'ら', '涼': 'ら', '竜': 'ら',
      // わ行
      '渡': 'わ', '和': 'わ',
      // その他
      '石': 'い', '井': 'い', '飯': 'い', '五': 'い', '吉': 'よ', '与': 'よ', '森': 'も', '守': 'も',
      '岡': 'お', '奥': 'お', '尾': 'お', '白': 'し', '志': 'し', '広': 'ひ', '弘': 'ひ', '平': 'ひ', '日': 'ひ',
      '布': 'ぬ', '内': 'う', '宇': 'う', '浦': 'う', '野': 'の', '能': 'の',
      '宮': 'み', '三': 'み', '水': 'み', '溝': 'み',
    };
  }

  Future<void> _loadUserKanaMap() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('customKanaMap');
    if (json != null && json.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(json);
        _userKanaMap = decoded.map((k, v) => MapEntry(k, v.toString()));
        if (mounted) setState(_applyFilter);
      } catch (_) {
        // ignore decode errors
      }
    }
  }

  Future<void> _showContactUpdateDialog(Customer customer) async {
    final emailController = TextEditingController(text: customer.email ?? "");
    final telController = TextEditingController(text: customer.tel ?? "");
    final addressController = TextEditingController(text: customer.address ?? "");

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('連絡先を更新'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'メール')),
            TextField(controller: telController, decoration: const InputDecoration(labelText: '電話番号'), keyboardType: TextInputType.phone),
            TextField(controller: addressController, decoration: const InputDecoration(labelText: '住所')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () async {
              await _customerRepo.updateContact(
                customerId: customer.id,
                email: emailController.text.isEmpty ? null : emailController.text,
                tel: telController.text.isEmpty ? null : telController.text,
                address: addressController.text.isEmpty ? null : addressController.text,
              );
              if (!context.mounted) return;
              Navigator.pop(context, true);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (updated == true) {
      _loadCustomers();
    }
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    try {
      final customers = await _customerRepo.getAllCustomers();
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('顧客の読み込みに失敗しました: $e')));
    }
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase();
    List<Customer> list = _customers.where((c) {
      return c.displayName.toLowerCase().contains(query) || c.formalName.toLowerCase().contains(query);
    }).toList();
    // Kana filtering disabled temporarily for stability
    switch (_sortKey) {
      case 'name_desc':
        list.sort((a, b) => _normalizedName(b.displayName).compareTo(_normalizedName(a.displayName)));
        break;
      default:
        list.sort((a, b) => _normalizedName(a.displayName).compareTo(_normalizedName(b.displayName)));
    }
    _filtered = list;
  }

  String _normalizedName(String name) {
    var n = name.replaceAll(RegExp(r"\s+"), "");
    if (_ignoreCorpPrefix) {
      for (final token in ["株式会社", "（株）", "(株)", "有限会社", "（有）", "(有)", "合同会社", "（同）", "(同)"]) {
        n = n.replaceAll(token, "");
      }
    }
    return n.toLowerCase();
  }

  String _headKana(String name) {
    var n = name.replaceAll(RegExp(r"\s+|\u3000"), "");
    for (final token in ["株式会社", "（株）", "(株)", "有限会社", "（有）", "(有)", "合同会社", "（同）", "(同)"]) {
      if (n.startsWith(token)) n = n.substring(token.length);
    }
    if (n.isEmpty) return '他';
    String ch = n.substring(0, 1);
    final code = ch.codeUnitAt(0);
    if (code >= 0x30A1 && code <= 0x30F6) {
      ch = String.fromCharCode(code - 0x60); // katakana -> hiragana
    }
    if (_userKanaMap.containsKey(ch)) return _userKanaMap[ch]!;
    if (_defaultKanaMap.containsKey(ch)) return _defaultKanaMap[ch]!;
    for (final entry in _kanaBuckets.entries) {
      if (entry.value.contains(ch)) return entry.key;
    }
    return '他';
  }

  final Map<String, List<String>> _kanaBuckets = const {
    'あ': ['あ', 'い', 'う', 'え', 'お'],
    'か': ['か', 'き', 'く', 'け', 'こ', 'が', 'ぎ', 'ぐ', 'げ', 'ご'],
    'さ': ['さ', 'し', 'す', 'せ', 'そ', 'ざ', 'じ', 'ず', 'ぜ', 'ぞ'],
    'た': ['た', 'ち', 'つ', 'て', 'と', 'だ', 'ぢ', 'づ', 'で', 'ど'],
    'な': ['な', 'に', 'ぬ', 'ね', 'の'],
    'は': ['は', 'ひ', 'ふ', 'へ', 'ほ', 'ば', 'び', 'ぶ', 'べ', 'ぼ', 'ぱ', 'ぴ', 'ぷ', 'ぺ', 'ぽ'],
    'ま': ['ま', 'み', 'む', 'め', 'も'],
    'や': ['や', 'ゆ', 'よ'],
    'ら': ['ら', 'り', 'る', 'れ', 'ろ'],
    'わ': ['わ', 'を', 'ん'],
    '他': ['他'],
  };

  late final Map<String, String> _defaultKanaMap = _buildDefaultKanaMap();

  String _normalizeIndexChar(String input) {
    var s = input.replaceAll(RegExp(r"\s+|\u3000"), "");
    if (s.isEmpty) return '';
    String ch = s.characters.first;
    final code = ch.codeUnitAt(0);
    if (code >= 0x30A1 && code <= 0x30F6) {
      ch = String.fromCharCode(code - 0x60); // katakana -> hiragana
    }
    return ch;
  }

  Future<void> _addOrEditCustomer({Customer? customer}) async {
    final isEdit = customer != null;
    final displayNameController = TextEditingController(text: customer?.displayName ?? "");
    final formalNameController = TextEditingController(text: customer?.formalName ?? "");
    final departmentController = TextEditingController(text: customer?.department ?? "");
    final addressController = TextEditingController(text: customer?.address ?? "");
    final telController = TextEditingController(text: customer?.tel ?? "");
    final emailController = TextEditingController(text: customer?.email ?? "");
    String selectedTitle = customer?.title ?? "様";
    bool isCompany = selectedTitle == '御中';
    final head1Controller = TextEditingController(text: customer?.headChar1 ?? _headKana(displayNameController.text));
    final head2Controller = TextEditingController(text: customer?.headChar2 ?? "");

    Future<void> prefillFromPhonebook() async {
      if (!await FlutterContacts.requestPermission(readonly: true)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('連絡先の権限がありません')));
        return;
      }
      final contacts = await FlutterContacts.getContacts(withProperties: true, withAccounts: true, withPhoto: false);
      if (!mounted) return;
      if (contacts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('連絡先が見つかりません')));
        return;
      }
      final Contact? picked = await showModalBottomSheet<Contact>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.6,
            child: ListView.builder(
              itemCount: contacts.length,
              itemBuilder: (_, i) {
                final c = contacts[i];
                final orgCompany = c.organizations.isNotEmpty ? c.organizations.first.company : '';
                final personParts = [c.name.last, c.name.first].where((v) => v.isNotEmpty).toList();
                final person = personParts.isNotEmpty ? personParts.join(' ').trim() : c.displayName;
                final label = orgCompany.isNotEmpty ? orgCompany : person;
                return ListTile(
                  title: Text(label),
                  subtitle: person.isNotEmpty ? Text(person) : null,
                  onTap: () => Navigator.pop(ctx, c),
                );
              },
            ),
          ),
        ),
      );
      if (!mounted) return;
      if (picked != null) {
        final orgCompany = picked.organizations.isNotEmpty ? picked.organizations.first.company : '';
        final personParts = [picked.name.last, picked.name.first].where((v) => v.isNotEmpty).toList();
        final person = personParts.isNotEmpty ? personParts.join(' ').trim() : picked.displayName;
        final chosen = orgCompany.isNotEmpty ? orgCompany : person;
        displayNameController.text = chosen;
        formalNameController.text = orgCompany.isNotEmpty ? orgCompany : person;
        final addr = picked.addresses.isNotEmpty ? picked.addresses.first : null;
        if (addr != null) {
          final joined = [addr.postalCode, addr.state, addr.city, addr.street, addr.country]
              .where((v) => v.isNotEmpty)
              .join(' ');
          addressController.text = joined;
        }
        if (picked.phones.isNotEmpty) {
          telController.text = picked.phones.first.number;
        }
        if (picked.emails.isNotEmpty) {
          emailController.text = picked.emails.first.address;
        }
        isCompany = orgCompany.isNotEmpty;
        selectedTitle = isCompany ? '御中' : '様';
        if (head1Controller.text.isEmpty) {
          head1Controller.text = _headKana(chosen);
        }
        setState(() {});
      }
    }

    final result = await showDialog<Customer>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            title: Text(isEdit ? "顧客を編集" : "顧客を新規登録"),
            content: KeyboardInsetWrapper(
              basePadding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
              extraBottom: 32,
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: displayNameController,
                      decoration: const InputDecoration(labelText: "表示名（略称）", hintText: "例: 佐々木製作所"),
                      onChanged: (v) {
                        if (head1Controller.text.isEmpty) {
                          head1Controller.text = _headKana(v);
                        }
                      },
                    ),
                    TextField(
                      controller: formalNameController,
                      decoration: const InputDecoration(labelText: "正式名称", hintText: "例: 株式会社 佐々木製作所"),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.contact_phone),
                        label: const Text('電話帳から引用'),
                        onPressed: prefillFromPhonebook,
                      ),
                    ),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('会社')),
                        ButtonSegment(value: false, label: Text('個人')),
                      ],
                      selected: {isCompany},
                      onSelectionChanged: (values) {
                        if (values.isEmpty) return;
                        setDialogState(() {
                          isCompany = values.first;
                          selectedTitle = isCompany ? '御中' : '様';
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedTitle,
                      decoration: const InputDecoration(labelText: "敬称"),
                      items: ["様", "御中", "殿", "貴社"].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) => setDialogState(() {
                        selectedTitle = val ?? "様";
                        isCompany = selectedTitle == '御中' || selectedTitle == '貴社';
                      }),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: head1Controller,
                            maxLength: 1,
                            decoration: const InputDecoration(labelText: "インデックス1 (1文字)", counterText: ""),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: head2Controller,
                            maxLength: 1,
                            decoration: const InputDecoration(labelText: "インデックス2 (任意)", counterText: ""),
                          ),
                        ),
                      ],
                    ),
                    TextField(
                      controller: departmentController,
                      decoration: const InputDecoration(labelText: "部署名", hintText: "例: 営業部"),
                    ),
                    TextField(
                      controller: addressController,
                      decoration: const InputDecoration(labelText: "住所"),
                    ),
                    TextField(
                      controller: telController,
                      decoration: const InputDecoration(labelText: "電話番号"),
                      keyboardType: TextInputType.phone,
                    ),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: "メールアドレス"),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("キャンセル")),
              TextButton(
                onPressed: () {
                  if (displayNameController.text.isEmpty || formalNameController.text.isEmpty) {
                    return;
                  }
                  final head1 = _normalizeIndexChar(head1Controller.text);
                  final head2 = _normalizeIndexChar(head2Controller.text);
                  final newCustomer = Customer(
                    id: customer?.id ?? const Uuid().v4(),
                    displayName: displayNameController.text,
                    formalName: formalNameController.text,
                    title: selectedTitle,
                    department: departmentController.text.isEmpty ? null : departmentController.text,
                    address: addressController.text.isEmpty ? null : addressController.text,
                    tel: telController.text.isEmpty ? null : telController.text,
                    headChar1: head1.isEmpty ? _headKana(displayNameController.text) : head1,
                    headChar2: head2.isEmpty ? null : head2,
                    isLocked: customer?.isLocked ?? false,
                  );
                  Navigator.pop(context, newCustomer);
                },
                child: const Text("保存"),
              ),
            ],
          );
        },
      ),
    );

    if (!mounted) return;

    if (result != null) {
      await _customerRepo.saveCustomer(result);
      if (widget.selectionMode) {
        if (!mounted) return;
        Navigator.pop(context, result);
      } else {
        _loadCustomers();
      }
    }
  }

  // Force usage so analyzer doesn't flag as unused when kana filter is disabled
  void _ensureKanaMapsUsed() {
    // ignore: unused_local_variable
    final _ = [_kanaBuckets.length, _defaultKanaMap.length, _userKanaMap.length];
  }

  Future<void> _showPhonebookImport() async {
    // 端末連絡先を取得
    if (!await FlutterContacts.requestPermission(readonly: true)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('連絡先の権限がありません')));
      return;
    }

    final contacts = await FlutterContacts.getContacts(withProperties: true, withAccounts: true, withPhoto: false);
    // 一部端末では一覧取得で organization が空になることがあるため、詳細を再取得
    final detailedContacts = <Contact>[];
    for (final c in contacts) {
      final full = await FlutterContacts.getContact(c.id, withProperties: true, withAccounts: true, withPhoto: false);
      if (full != null) detailedContacts.add(full);
    }
    final sourceContacts = detailedContacts.isNotEmpty ? detailedContacts : contacts;
    if (sourceContacts.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('連絡先が見つかりません')));
      return;
    }

    final phonebook = sourceContacts.map((c) {
      final orgCompany = c.organizations.isNotEmpty ? c.organizations.first.company : '';
      final personParts = [c.name.last, c.name.first].where((v) => v.isNotEmpty).toList();
      final person = personParts.isNotEmpty ? personParts.join(' ').trim() : c.displayName;
      final addresses = c.addresses
          .map((a) => [a.postalCode, a.state, a.city, a.street, a.country]
              .where((v) => v.isNotEmpty)
              .join(' '))
          .where((s) => s.trim().isNotEmpty)
          .toList();
      final emails = c.emails.map((e) => e.address).where((e) => e.trim().isNotEmpty).toList();
      final tel = c.phones.isNotEmpty ? c.phones.first.number : null;
      final chosenCompany = orgCompany; // 空なら空のまま
      final chosenPerson = person.isNotEmpty ? person : c.displayName;
      return {
        'company': chosenCompany,
        'person': chosenPerson,
        'addresses': addresses.isNotEmpty ? addresses : [''],
        'tel': tel,
        'emails': emails.isNotEmpty ? emails : [''],
      };
    }).toList();

    String selectedEntryId = '0';
    String selectedNameSource = (phonebook.isNotEmpty && (phonebook.first['company'] as String).isNotEmpty)
        ? 'company'
        : ((phonebook.isNotEmpty && (phonebook.first['person'] as String).isNotEmpty) ? 'person' : 'person');
    int selectedAddressIndex = 0;
    int selectedEmailIndex = 0;

    final displayController = TextEditingController();
    final formalController = TextEditingController();
    final addressController = TextEditingController();
    final emailController = TextEditingController();

    void applySelectionState() {
      final entry = phonebook[int.parse(selectedEntryId)];
      if ((entry['company'] as String).isNotEmpty) {
        selectedNameSource = 'company';
      } else if ((entry['person'] as String).isNotEmpty) {
        selectedNameSource = 'person';
      }
      final addresses = (entry['addresses'] as List<String>);
      final emails = (entry['emails'] as List<String>);
      final displayName = selectedNameSource == 'company' ? entry['company'] as String : entry['person'] as String;
      final formalName = selectedNameSource == 'company'
          ? '株式会社 ${entry['company']}'
          : '${entry['person']} 様';
      displayController.text = displayName;
      formalController.text = formalName;
      addressController.text = addresses[selectedAddressIndex];
      emailController.text = emails.isNotEmpty ? emails[selectedEmailIndex] : '';
    }

    applySelectionState();

    if (!mounted) return;
    final imported = await showDialog<Customer>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final entry = phonebook[int.parse(selectedEntryId)];
          final addresses = (entry['addresses'] as List<String>);
          final emails = (entry['emails'] as List<String>);

          return AlertDialog(
            title: const Text('電話帳から取り込む'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedEntryId,
                  decoration: const InputDecoration(labelText: '電話帳エントリ'),
                  items: phonebook
                      .asMap()
                      .entries
                      .map((e) {
                        final comp = e.value['company'] as String;
                        final person = e.value['person'] as String;
                        final title = comp.isNotEmpty ? comp : (person.isNotEmpty ? person : '不明');
                        return DropdownMenuItem(value: e.key.toString(), child: Text(title));
                      })
                      .toList(),
                  onChanged: (v) {
                    setDialogState(() {
                      selectedEntryId = v ?? '0';
                      selectedAddressIndex = 0;
                      selectedEmailIndex = 0;
                      final entry = phonebook[int.parse(selectedEntryId)];
                      selectedNameSource = (entry['company'] as String).isNotEmpty
                          ? 'company'
                          : ((entry['person'] as String).isNotEmpty ? 'person' : 'person');
                      applySelectionState();
                    });
                  },
                ),
                const SizedBox(height: 8),
                const Text('顧客名の取り込み元'),
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
                      applySelectionState();
                    });
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: selectedAddressIndex,
                  decoration: const InputDecoration(labelText: '住所を選択'),
                  items: addresses
                      .asMap()
                      .entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setDialogState(() {
                    selectedAddressIndex = v ?? 0;
                    applySelectionState();
                  }),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: selectedEmailIndex,
                  decoration: const InputDecoration(labelText: 'メールを選択'),
                  items: emails
                      .asMap()
                      .entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setDialogState(() {
                    selectedEmailIndex = v ?? 0;
                    applySelectionState();
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: displayController,
                  decoration: const InputDecoration(labelText: '表示名（編集可）'),
                ),
                TextField(
                  controller: formalController,
                  decoration: const InputDecoration(labelText: '正式名称（編集可）'),
                ),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: '住所（編集可）'),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'メール（編集可）'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
              ElevatedButton(
                onPressed: () {
                  final newCustomer = Customer(
                    id: const Uuid().v4(),
                    displayName: displayController.text,
                    formalName: formalController.text,
                    title: selectedNameSource == 'company' ? '御中' : '様',
                    address: addressController.text,
                    tel: entry['tel'] as String?,
                    email: emailController.text.isEmpty ? null : emailController.text,
                    isSynced: false,
                  );
                  Navigator.pop(context, newCustomer);
                },
                child: const Text('取り込む'),
              ),
            ],
          );
        },
      ),
    );
    if (!context.mounted) return;

    if (imported != null) {
      await _customerRepo.saveCustomer(imported);
      _loadCustomers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(widget.selectionMode ? "C2:顧客選択" : "C1:顧客一覧"),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: "ソート",
            onPressed: () {
              showMenu<String>(
                context: context,
                position: const RelativeRect.fromLTRB(100, 80, 0, 0),
                items: const [
                  PopupMenuItem(value: 'name_asc', child: Text('名前昇順')),
                  PopupMenuItem(value: 'name_desc', child: Text('名前降順')),
                ],
              ).then((val) {
                if (val != null) {
                  setState(() {
                    _sortKey = val;
                    _applyFilter();
                  });
                }
              });
            },
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _sortKey,
              icon: const Icon(Icons.sort, color: Colors.white),
              dropdownColor: Colors.white,
              items: const [
                DropdownMenuItem(value: 'name_asc', child: Text('名前昇順')),
                DropdownMenuItem(value: 'name_desc', child: Text('名前降順')),
              ],
              onChanged: (v) {
                setState(() {
                  _sortKey = v ?? 'name_asc';
                  _applyFilter();
                });
              },
            ),
          ),
          if (!widget.selectionMode)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadCustomers,
            ),
        ],
      ),
      body: KeyboardInsetWrapper(
        basePadding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
        extraBottom: 40,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: widget.selectionMode ? "名前で検索して選択" : "名前で検索 (電話帳参照ボタンは詳細で)",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                onChanged: (_) => setState(_applyFilter),
              ),
            ),
            if (!widget.selectionMode)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SwitchListTile(
                  title: const Text('株式会社/有限会社などの接頭辞を無視してソート'),
                  value: _ignoreCorpPrefix,
                  onChanged: (v) => setState(() {
                    _ignoreCorpPrefix = v;
                    _applyFilter();
                  }),
                ),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                      ? const Center(child: Text("顧客が登録されていません"))
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 120, top: 4),
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final c = _filtered[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: c.isLocked ? Colors.grey.shade300 : Colors.indigo.shade100,
                                child: Stack(
                                  children: [
                                    const Align(alignment: Alignment.center, child: Icon(Icons.person, color: Colors.indigo)),
                                    if (c.isLocked)
                                      const Align(alignment: Alignment.bottomRight, child: Icon(Icons.lock, size: 14, color: Colors.redAccent)),
                                  ],
                                ),
                              ),
                              title: Text(c.displayName, style: TextStyle(fontWeight: FontWeight.bold, color: c.isLocked ? Colors.grey : Colors.black87)),
                              subtitle: Text("${c.formalName} ${c.title}"),
                              onTap: widget.selectionMode ? () => Navigator.pop(context, c) : () => _showDetailPane(c),
                              trailing: widget.selectionMode
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: c.isLocked ? null : () => _addOrEditCustomer(customer: c),
                                      tooltip: c.isLocked ? "ロック中" : "編集",
                                    ),
                              onLongPress: () => _showContextActions(c),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMenu,
        icon: const Icon(Icons.add),
        label: Text(widget.selectionMode ? "選択" : "追加"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('手入力で新規作成'),
              onTap: () {
                Navigator.pop(context);
                _addOrEditCustomer();
              },
            ),
            ListTile(
              leading: const Icon(Icons.contact_phone),
              title: const Text('電話帳から取り込む'),
              onTap: () {
                Navigator.pop(context);
                _showPhonebookImport();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showContextActions(Customer c) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('詳細を表示'),
              onTap: () {
                Navigator.pop(context);
                _showDetailPane(c);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('編集'),
              enabled: !c.isLocked,
              onTap: c.isLocked
                  ? null
                  : () {
                      Navigator.pop(context);
                      _addOrEditCustomer(customer: c);
                    },
            ),
            ListTile(
              leading: const Icon(Icons.contact_mail),
              title: const Text('連絡先を更新'),
              onTap: () {
                Navigator.pop(context);
                _showContactUpdateDialog(c);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: const Text('削除', style: TextStyle(color: Colors.redAccent)),
              enabled: !c.isLocked,
              onTap: c.isLocked
                  ? null
                  : () async {
                      Navigator.pop(context);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('削除確認'),
                          content: Text('「${c.displayName}」を削除しますか？'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await _customerRepo.deleteCustomer(c.id);
                        if (!mounted) return;
                        _loadCustomers();
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailPane(Customer c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                children: [
                  Icon(c.isLocked ? Icons.lock : Icons.person, color: c.isLocked ? Colors.redAccent : Colors.indigo),
                  const SizedBox(width: 8),
                  Expanded(child: Text(c.formalName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                  IconButton(
                    icon: const Icon(Icons.call),
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("電話帳参照は端末連絡先連携が必要です")));
                    },
                    tooltip: "電話帳参照",
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (c.address != null) Text("住所: ${c.address}") else const SizedBox.shrink(),
              if (c.tel != null) Text("TEL: ${c.tel}") else const SizedBox.shrink(),
              if (c.email != null) Text("メール: ${c.email}") else const SizedBox.shrink(),
              Text("敬称: ${c.title}"),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: c.isLocked
                        ? null
                        : () {
                            Navigator.pop(context);
                            _addOrEditCustomer(customer: c);
                          },
                    icon: const Icon(Icons.edit),
                    label: const Text("編集"),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showContactUpdateSheet(c);
                    },
                    icon: const Icon(Icons.contact_mail),
                    label: const Text("連絡先を更新"),
                  ),
                  const SizedBox(width: 8),
                  if (!c.isLocked)
                    OutlinedButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("削除確認"),
                            content: Text("「${c.displayName}」を削除しますか？"),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("キャンセル")),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("削除", style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (!context.mounted) return;
                        if (confirm == true) {
                          await _customerRepo.deleteCustomer(c.id);
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          _loadCustomers();
                        }
                      },
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      label: const Text("削除", style: TextStyle(color: Colors.redAccent)),
                    ),
                  if (c.isLocked)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Chip(label: const Text("ロック中"), avatar: const Icon(Icons.lock, size: 16)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContactUpdateSheet(Customer c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => KeyboardInsetWrapper(
        basePadding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
        extraBottom: 16,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.contact_mail),
                title: const Text('連絡先を更新'),
                onTap: () {
                  Navigator.pop(context);
                  _showContactUpdateDialog(c);
                },
              ),
              ListTile(
                leading: const Icon(Icons.contact_phone),
                title: const Text('電話帳から取り込む'),
                onTap: () {
                  Navigator.pop(context);
                  _showPhonebookImport();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
