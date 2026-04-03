import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/company_profile_keys.dart';
// NOTE: mail template placeholders may rely on fields edited here.
import '../models/company_model.dart';
import '../services/company_profile_service.dart';
import '../services/company_repository.dart';
import '../services/business_profile_repository.dart';
import '../widgets/contact_picker_sheet.dart';
import '../widgets/keyboard_inset_wrapper.dart';
import '../widgets/seal_camera_screen.dart';
import 'custom_field_settings_screen.dart';

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  final _service = CompanyProfileService();
  final _companyRepo = CompanyRepository();
  final _businessProfileRepo = BusinessProfileRepository();
  final _companyNameCtrl = TextEditingController();
  final _companyZipCtrl = TextEditingController();
  final _companyAddrCtrl = TextEditingController();
  final _companyTelCtrl = TextEditingController();
  final _companyFaxCtrl = TextEditingController();
  final _companyEmailCtrl = TextEditingController();
  final _companyUrlCtrl = TextEditingController();
  final _companyRegCtrl = TextEditingController();
  final _staffNameCtrl = TextEditingController();
  final _staffEmailCtrl = TextEditingController();
  final _staffMobileCtrl = TextEditingController();

  final List<_BankControllers> _bankCtrls = List.generate(
    kCompanyBankSlotCount,
    (_) => _BankControllers(),
  );

  bool _loading = true;
  double _taxRate = 0.10;
  String _taxDisplayMode = 'normal';
  String? _sealPath;
  CompanyInfo? _legacyInfo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await _service.loadProfile();
    final legacyInfo = await _companyRepo.getCompanyInfo();
    if (!mounted) return;
    setState(() {
      _companyNameCtrl.text = profile.companyName.isNotEmpty ? profile.companyName : legacyInfo.name;
      _companyZipCtrl.text = profile.companyZip.isNotEmpty ? profile.companyZip : (legacyInfo.zipCode ?? '');
      _companyAddrCtrl.text = profile.companyAddress.isNotEmpty ? profile.companyAddress : (legacyInfo.address ?? '');
      _companyTelCtrl.text = profile.companyTel.isNotEmpty ? profile.companyTel : (legacyInfo.tel ?? '');
      _companyFaxCtrl.text = profile.companyFax.isNotEmpty ? profile.companyFax : (legacyInfo.fax ?? '');
      _companyEmailCtrl.text = profile.companyEmail.isNotEmpty ? profile.companyEmail : (legacyInfo.email ?? '');
      _companyUrlCtrl.text = profile.companyUrl.isNotEmpty ? profile.companyUrl : (legacyInfo.url ?? '');
      _companyRegCtrl.text = profile.companyReg.isNotEmpty ? profile.companyReg : (legacyInfo.registrationNumber ?? '');
      _staffNameCtrl.text = profile.staffName;
      _staffEmailCtrl.text = profile.staffEmail;
      _staffMobileCtrl.text = profile.staffMobile;
      for (var i = 0; i < _bankCtrls.length; i++) {
        final ctrl = _bankCtrls[i];
        if (i < profile.bankAccounts.length) {
          final acc = profile.bankAccounts[i];
          ctrl.bankName.text = acc.bankName;
          ctrl.branchName.text = acc.branchName;
          ctrl.accountType = acc.accountType;
          ctrl.accountNumber.text = acc.accountNumber;
          ctrl.holderName.text = acc.holderName;
          ctrl.isActive = acc.isActive;
        }
      }
      _taxRate = legacyInfo.defaultTaxRate;
      _taxDisplayMode = legacyInfo.taxDisplayMode;
      _sealPath = legacyInfo.sealPath;
      _legacyInfo = legacyInfo;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final accounts = _bankCtrls
        .map(
          (c) => CompanyBankAccount(
            bankName: c.bankName.text,
            branchName: c.branchName.text,
            accountType: c.accountType,
            accountNumber: c.accountNumber.text,
            holderName: c.holderName.text,
            isActive: c.isActive,
          ),
        )
        .toList();
    final activeCount = accounts.where((a) => a.isActive && a.bankName.trim().isNotEmpty).length;
    if (activeCount > kCompanyBankActiveLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('振込口座は最大$kCompanyBankActiveLimit件まで有効化できます')),
      );
      return;
    }

    final profile = CompanyProfile(
      companyName: _companyNameCtrl.text.trim(),
      companyZip: _companyZipCtrl.text.trim(),
      companyAddress: _companyAddrCtrl.text.trim(),
      companyTel: _companyTelCtrl.text.trim(),
      companyFax: _companyFaxCtrl.text.trim(),
      companyEmail: _companyEmailCtrl.text.trim(),
      companyUrl: _companyUrlCtrl.text.trim(),
      companyReg: _companyRegCtrl.text.trim(),
      staffName: _staffNameCtrl.text.trim(),
      staffEmail: _staffEmailCtrl.text.trim(),
      staffMobile: _staffMobileCtrl.text.trim(),
      bankAccounts: accounts,
    );
    await _service.saveProfile(profile);
    await _companyRepo.saveCompanyInfo(
      (_legacyInfo ?? CompanyInfo(name: _companyNameCtrl.text.trim().isEmpty ? '未設定' : _companyNameCtrl.text.trim())).copyWith(
        name: _companyNameCtrl.text.trim(),
        zipCode: _companyZipCtrl.text.trim(),
        address: _companyAddrCtrl.text.trim(),
        tel: _companyTelCtrl.text.trim(),
        fax: _companyFaxCtrl.text.trim(),
        email: _companyEmailCtrl.text.trim(),
        url: _companyUrlCtrl.text.trim(),
        registrationNumber: _companyRegCtrl.text.trim().isEmpty ? null : _companyRegCtrl.text.trim(),
        defaultTaxRate: _taxRate,
        taxDisplayMode: _taxDisplayMode,
        sealPath: _sealPath,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('自社情報を保存しました')));
  }

  Future<void> _pickSeal(ImageSource source) async {
    if (source == ImageSource.camera) {
      // サイズガイド付きカメラ画面を使用
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (context) => const SealCameraScreen()),
      );
      if (result != null) {
        setState(() {
          _sealPath = result;
        });
      }
      return;
    }
    
    // アルバム選択は従来通り
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, imageQuality: 85);
    if (image == null) return;
    setState(() {
      _sealPath = image.path;
    });
  }

  Future<void> _pickContacts(bool forCompany) async {
    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('連絡先へのアクセス権限が必要です')));
      }
      return;
    }
    final contacts = await FlutterContacts.getContacts(withProperties: true, withAccounts: true);
    if (!mounted) return;
    final selected = await showModalBottomSheet<Contact?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ContactPickerSheet(contacts: contacts, title: forCompany ? '会社情報を電話帳から' : '担当者を電話帳から'),
    );
    if (selected == null) return;
    if (forCompany) {
      if (selected.organizations.isNotEmpty) {
        _companyNameCtrl.text = selected.organizations.first.company;
      } else {
        _companyNameCtrl.text = selected.displayName;
      }
      if (selected.addresses.isNotEmpty) {
        final addr = selected.addresses.first;
        _companyAddrCtrl.text = [addr.postalCode, addr.state, addr.city, addr.street].where((e) => e.trim().isNotEmpty).join(' ');
      }
      if (selected.phones.isNotEmpty) {
        _companyTelCtrl.text = selected.phones.first.number;
      }
      if (selected.emails.isNotEmpty) {
        _companyEmailCtrl.text = selected.emails.first.address;
      }
    } else {
      _staffNameCtrl.text = selected.displayName;
      if (selected.phones.isNotEmpty) {
        _staffMobileCtrl.text = selected.phones.first.number;
      }
      if (selected.emails.isNotEmpty) {
        _staffEmailCtrl.text = selected.emails.first.address;
      }
    }
  }

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _companyZipCtrl.dispose();
    _companyAddrCtrl.dispose();
    _companyTelCtrl.dispose();
    _companyFaxCtrl.dispose();
    _companyEmailCtrl.dispose();
    _companyUrlCtrl.dispose();
    _companyRegCtrl.dispose();
    _staffNameCtrl.dispose();
    _staffEmailCtrl.dispose();
    _staffMobileCtrl.dispose();
    for (final ctrl in _bankCtrls) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('F2:自社情報'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(onPressed: _save, icon: const Icon(Icons.save)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : KeyboardInsetWrapper(
              basePadding: const EdgeInsets.all(16),
              extraBottom: 24,
              child: ListView(
                children: [
                  _section('会社情報', _buildCompanySection()),
                  _section('担当者情報', _buildStaffSection()),
                  _section('消費税設定', _buildTaxSection()),
                  _section('印影（角印）', _buildSealSection()),
                  _section('振込先口座 (最大2件まで有効)', _buildBankSection()),
                  _section('カスタムフィールド設定', _buildCustomFieldSection()),
                ],
              ),
            ),
    );
  }

  Widget _section(String title, Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildCompanySection() {
    return Column(
      children: [
        TextField(controller: _companyNameCtrl, decoration: const InputDecoration(labelText: '自社名')),
        const SizedBox(height: 8),
        TextField(controller: _companyZipCtrl, decoration: const InputDecoration(labelText: '郵便番号')),
        const SizedBox(height: 8),
        TextField(controller: _companyAddrCtrl, decoration: const InputDecoration(labelText: '住所')),
        const SizedBox(height: 8),
        TextField(controller: _companyTelCtrl, decoration: const InputDecoration(labelText: '電話番号')),
        const SizedBox(height: 8),
        TextField(controller: _companyFaxCtrl, decoration: const InputDecoration(labelText: 'FAX番号')),
        const SizedBox(height: 8),
        TextField(controller: _companyEmailCtrl, decoration: const InputDecoration(labelText: '代表メールアドレス')),
        const SizedBox(height: 8),
        TextField(controller: _companyUrlCtrl, decoration: const InputDecoration(labelText: 'URL')),
        const SizedBox(height: 8),
        TextField(controller: _companyRegCtrl, decoration: const InputDecoration(labelText: '登録番号(T番号)')),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: () => _pickContacts(true),
            icon: const Icon(Icons.import_contacts),
            label: const Text('電話帳から取り込む'),
          ),
        ),
      ],
    );
  }

  Widget _buildStaffSection() {
    return Column(
      children: [
        TextField(controller: _staffNameCtrl, decoration: const InputDecoration(labelText: '担当者名')),
        const SizedBox(height: 8),
        TextField(controller: _staffEmailCtrl, decoration: const InputDecoration(labelText: '担当者メール')),
        const SizedBox(height: 8),
        TextField(controller: _staffMobileCtrl, decoration: const InputDecoration(labelText: '担当者携帯番号')),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: () => _pickContacts(false),
            icon: const Icon(Icons.smartphone),
            label: const Text('電話帳から取り込む'),
          ),
        ),
      ],
    );
  }

  Widget _buildBankSection() {
    return Column(
      children: List.generate(_bankCtrls.length, (index) {
        final ctrl = _bankCtrls[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: ctrl.isActive ? Colors.green.shade50 : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('口座 ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Switch(
                      value: ctrl.isActive,
                      onChanged: (v) {
                        setState(() => ctrl.isActive = v);
                      },
                    ),
                  ],
                ),
                TextField(controller: ctrl.bankName, decoration: const InputDecoration(labelText: '銀行名')),
                const SizedBox(height: 8),
                TextField(controller: ctrl.branchName, decoration: const InputDecoration(labelText: '支店名')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: ctrl.accountType,
                  decoration: const InputDecoration(labelText: '種別'),
                  items: kAccountTypeOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => ctrl.accountType = v ?? '普通'),
                ),
                const SizedBox(height: 8),
                TextField(controller: ctrl.accountNumber, decoration: const InputDecoration(labelText: '口座番号')),
                const SizedBox(height: 8),
                TextField(controller: ctrl.holderName, decoration: const InputDecoration(labelText: '名義人')),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTaxSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('デフォルト消費税率', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('10%'),
              selected: _taxRate == 0.10,
              onSelected: (_) => setState(() => _taxRate = 0.10),
            ),
            ChoiceChip(
              label: const Text('8%'),
              selected: _taxRate == 0.08,
              onSelected: (_) => setState(() => _taxRate = 0.08),
            ),
            ChoiceChip(
              label: const Text('0%'),
              selected: _taxRate == 0.0,
              onSelected: (_) => setState(() => _taxRate = 0.0),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('消費税の表示設定 (T番号未取得時など)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('通常表示'),
              selected: _taxDisplayMode == 'normal',
              onSelected: (_) => setState(() => _taxDisplayMode = 'normal'),
            ),
            ChoiceChip(
              label: const Text('表示しない'),
              selected: _taxDisplayMode == 'hidden',
              onSelected: (_) => setState(() => _taxDisplayMode = 'hidden'),
            ),
            ChoiceChip(
              label: const Text('「税別」と表示'),
              selected: _taxDisplayMode == 'text_only',
              onSelected: (_) => setState(() => _taxDisplayMode = 'text_only'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSealSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey.shade50,
          ),
          child: _sealPath == null
              ? const Center(child: Icon(Icons.crop_original, size: 48, color: Colors.grey))
              : ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(File(_sealPath!), fit: BoxFit.contain),
                ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _pickSeal(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('カメラで取り込む'),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickSeal(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('アルバムから選択'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text('白い紙に押した判子を真上から撮影してください', style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildCustomFieldSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '業種に合わせた独自のフィールドを追加できます。\n例：店舗面積、サービス提供エリア、資格情報など',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () async {
            final profile = await _businessProfileRepo.getCurrentProfile();
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CustomFieldSettingsScreen(
                    businessProfileId: profile.id,
                  ),
                ),
              );
            }
          },
          icon: const Icon(Icons.dashboard_customize),
          label: const Text('カスタムフィールドを設定'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _BankControllers {
  final bankName = TextEditingController();
  final branchName = TextEditingController();
  final accountNumber = TextEditingController();
  final holderName = TextEditingController();
  String accountType = '普通';
  bool isActive = false;

  void dispose() {
    bankName.dispose();
    branchName.dispose();
    accountNumber.dispose();
    holderName.dispose();
  }
}

