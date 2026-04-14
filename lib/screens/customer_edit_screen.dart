import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../models/customer_model.dart';
import '../widgets/contact_picker_sheet.dart';
import '../models/customer_model.dart' show HonorificCode;

/// C2: 顧客 新規登録 / 編集 フルスクリーンフォーム
class CustomerEditScreen extends StatefulWidget {
  final Customer? customer;

  const CustomerEditScreen({super.key, this.customer});

  @override
  State<CustomerEditScreen> createState() => _CustomerEditScreenState();
}

class _CustomerEditScreenState extends State<CustomerEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _displayNameCtl;
  late final TextEditingController _formalNameCtl;
  late final TextEditingController _departmentCtl;
  late final TextEditingController _addressCtl;
  late final TextEditingController _telCtl;
  late final TextEditingController _emailCtl;
  late final TextEditingController _head1Ctl;
  late final TextEditingController _head2Ctl;

  late int _selectedTitle;
  late bool _isCompany;
  bool get _isEdit => widget.customer != null;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _displayNameCtl = TextEditingController(text: c?.displayName ?? '');
    _formalNameCtl = TextEditingController(text: c?.formalName ?? '');
    _departmentCtl = TextEditingController(text: c?.department ?? '');
    _addressCtl = TextEditingController(text: c?.address ?? '');
    _telCtl = TextEditingController(text: c?.tel ?? '');
    _emailCtl = TextEditingController(text: c?.email ?? '');
    _selectedTitle = c?.title ?? HonorificCode.san;
    _isCompany =
        _selectedTitle == HonorificCode.onchu ||
        _selectedTitle == HonorificCode.kisha;
    _head1Ctl = TextEditingController(
      text: c?.headChar1 ?? _headKana(_displayNameCtl.text),
    );
    _head2Ctl = TextEditingController(text: c?.headChar2 ?? '');
  }

  @override
  void dispose() {
    _displayNameCtl.dispose();
    _formalNameCtl.dispose();
    _departmentCtl.dispose();
    _addressCtl.dispose();
    _telCtl.dispose();
    _emailCtl.dispose();
    _head1Ctl.dispose();
    _head2Ctl.dispose();
    super.dispose();
  }

  /// 電話帳の生データから末尾の敬称を除去（様・御中・殿・先生・スペース区切り対応）
  String _stripHonorific(String name) {
    return name.replaceAll(RegExp(r'[\s\u3000]*(様|御中|殿|先生)$'), '').trim();
  }

  String _headKana(String name) {
    var n = name.replaceAll(RegExp(r'\s+|\u3000'), '');
    for (final token in [
      '株式会社',
      '（株）',
      '(株)',
      '有限会社',
      '（有）',
      '(有)',
      '合同会社',
      '（同）',
      '(同)',
    ]) {
      if (n.startsWith(token)) n = n.substring(token.length);
    }
    if (n.isEmpty) return '';
    final first = n.characters.first;
    final kanaMap = {
      '安': 'あ',
      '阿': 'あ',
      '浅': 'あ',
      '佐': 'さ',
      '田': 'た',
      '中': 'な',
      '林': 'は',
      '松': 'ま',
      '山': 'や',
      '渡': 'わ',
    };
    return kanaMap[first] ?? first;
  }

  Future<void> _prefillFromPhonebook() async {
    if (!await FlutterContacts.requestPermission(readonly: true)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('連絡先の権限がありません')));
      return;
    }
    final contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withAccounts: true,
      withPhoto: false,
    );
    if (!mounted) return;
    if (contacts.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('連絡先が見つかりません')));
      return;
    }
    final Contact? picked = await showModalBottomSheet<Contact>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ContactPickerSheet(
        contacts: contacts,
        title: _isEdit ? '電話帳から上書き' : '電話帳から新規入力',
      ),
    );
    if (!mounted || picked == null) return;

    final orgCompanyRaw = picked.organizations.isNotEmpty
        ? picked.organizations.first.company
        : '';
    final personParts = [
      picked.name.last,
      picked.name.first,
    ].where((v) => v.isNotEmpty).toList();
    final personRaw = personParts.isNotEmpty
        ? personParts.join(' ').trim()
        : picked.displayName;
    // 電話帳の生データに敬称が含まれる場合があるため除去
    final orgCompany = _stripHonorific(orgCompanyRaw);
    final person = _stripHonorific(personRaw);
    final chosen = orgCompany.isNotEmpty ? orgCompany : person;

    setState(() {
      _displayNameCtl.text = chosen;
      _formalNameCtl.text = orgCompany.isNotEmpty ? orgCompany : person;
      final addr = picked.addresses.isNotEmpty ? picked.addresses.first : null;
      if (addr != null) {
        _addressCtl.text = [
          addr.postalCode,
          addr.state,
          addr.city,
          addr.street,
          addr.country,
        ].where((v) => v.isNotEmpty).join(' ');
      }
      if (picked.phones.isNotEmpty) {
        _telCtl.text = picked.phones.first.number;
      }
      if (picked.emails.isNotEmpty) {
        _emailCtl.text = picked.emails.first.address;
      }
      _isCompany = orgCompany.isNotEmpty;
      _selectedTitle = _isCompany ? HonorificCode.onchu : HonorificCode.san;
      if (_head1Ctl.text.isEmpty) {
        _head1Ctl.text = _headKana(chosen);
      }
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    // ロック中の顧客を編集 → 新 ID でフォーク（元レコードは保持）
    final isLocked = widget.customer?.isLocked ?? false;
    final newId = isLocked ? Uuid().v4() : (widget.customer?.id ?? Uuid().v4());
    final newCustomer = Customer(
      id: newId,
      displayName: _displayNameCtl.text.trim(),
      formalName: _stripHonorific(_formalNameCtl.text.trim()),
      title: _selectedTitle,
      department: _departmentCtl.text.trim().isEmpty
          ? null
          : _departmentCtl.text.trim(),
      address: _addressCtl.text.trim().isEmpty ? null : _addressCtl.text.trim(),
      tel: _telCtl.text.trim().isEmpty ? null : _telCtl.text.trim(),
      email: _emailCtl.text.trim().isEmpty ? null : _emailCtl.text.trim(),
      headChar1: _head1Ctl.text.trim().isEmpty ? null : _head1Ctl.text.trim(),
      headChar2: _head2Ctl.text.trim().isEmpty ? null : _head2Ctl.text.trim(),
      isLocked: false, // ロック解除
    );
    Navigator.pop(context, newCustomer);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(_isEdit ? 'C2:顧客を編集' : 'C2:顧客を新規登録'),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text(
              '保存',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // ── ヘッダーカード ──
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: _isCompany
                          ? Colors.indigo.shade100
                          : Colors.teal.shade100,
                      child: Icon(
                        _isCompany ? Icons.business : Icons.person,
                        size: 36,
                        color: _isCompany ? Colors.indigo : Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isEdit ? '顧客情報を編集' : '新しい顧客を登録',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '必須項目（*）を入力してください',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── 電話帳から引用 ──
            OutlinedButton.icon(
              onPressed: _prefillFromPhonebook,
              icon: const Icon(Icons.contact_phone),
              label: const Text('電話帳から引用'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── 基本情報セクション ──
            _SectionHeader(icon: Icons.badge, title: '基本情報'),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _displayNameCtl,
                      decoration: const InputDecoration(
                        labelText: '表示名（略称）*',
                        hintText: '例: 佐々木製作所',
                        prefixIcon: Icon(Icons.short_text),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '表示名は必須です' : null,
                      onChanged: (v) {
                        if (_head1Ctl.text.isEmpty) {
                          _head1Ctl.text = _headKana(v);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _formalNameCtl,
                      decoration: const InputDecoration(
                        labelText: '正式名称 *',
                        hintText: '例: 株式会社 佐々木製作所',
                        prefixIcon: Icon(Icons.text_fields),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '正式名称は必須です' : null,
                    ),
                    const SizedBox(height: 14),
                    // 会社 / 個人 切替
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: true,
                          icon: Icon(Icons.business),
                          label: Text('会社'),
                        ),
                        ButtonSegment(
                          value: false,
                          icon: Icon(Icons.person),
                          label: Text('個人'),
                        ),
                      ],
                      selected: {_isCompany},
                      onSelectionChanged: (values) {
                        if (values.isEmpty) return;
                        setState(() {
                          _isCompany = values.first;
                          _selectedTitle = _isCompany
                              ? HonorificCode.onchu
                              : HonorificCode.san;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<int>(
                      // ignore: deprecated_member_use
                      value: _selectedTitle,
                      decoration: const InputDecoration(
                        labelText: '敬称',
                        prefixIcon: Icon(Icons.title),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: HonorificCode.san,
                          child: Text('様'),
                        ),
                        DropdownMenuItem(
                          value: HonorificCode.onchu,
                          child: Text('御中'),
                        ),
                        DropdownMenuItem(
                          value: HonorificCode.dono,
                          child: Text('殿'),
                        ),
                        DropdownMenuItem(
                          value: HonorificCode.kisha,
                          child: Text('貴社'),
                        ),
                      ],
                      onChanged: (val) => setState(() {
                        _selectedTitle = val ?? HonorificCode.san;
                        _isCompany =
                            _selectedTitle == HonorificCode.onchu ||
                            _selectedTitle == HonorificCode.kisha;
                      }),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _departmentCtl,
                      decoration: const InputDecoration(
                        labelText: '部署名',
                        hintText: '例: 営業部',
                        prefixIcon: Icon(Icons.corporate_fare),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── 連絡先セクション ──
            _SectionHeader(icon: Icons.contact_mail, title: '連絡先'),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _addressCtl,
                      decoration: const InputDecoration(
                        labelText: '住所',
                        hintText: '例: 東京都千代田区...',
                        prefixIcon: Icon(Icons.location_on),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _telCtl,
                      decoration: const InputDecoration(
                        labelText: '電話番号',
                        hintText: '例: 03-1234-5678',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailCtl,
                      decoration: const InputDecoration(
                        labelText: 'メールアドレス',
                        hintText: '例: info@example.com',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── インデックスセクション ──
            _SectionHeader(icon: Icons.sort_by_alpha, title: 'インデックス（50音順）'),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _head1Ctl,
                        maxLength: 1,
                        decoration: const InputDecoration(
                          labelText: 'インデックス1',
                          hintText: 'あ',
                          prefixIcon: Icon(Icons.looks_one),
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _head2Ctl,
                        maxLength: 1,
                        decoration: const InputDecoration(
                          labelText: 'インデックス2（任意）',
                          hintText: '',
                          prefixIcon: Icon(Icons.looks_two),
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── 保存ボタン ──
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(
                _isEdit ? '変更を保存' : '顧客を登録',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.indigo),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.indigo,
          ),
        ),
      ],
    );
  }
}
