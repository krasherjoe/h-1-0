import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/company_profile_keys.dart';
import '../constants/mail_templates.dart';
import 'app_settings_repository.dart';

class CompanyBankAccount {
  final String bankName;
  final String branchName;
  final String accountType;
  final String accountNumber;
  final String holderName;
  final bool isActive;

  const CompanyBankAccount({
    this.bankName = '',
    this.branchName = '',
    this.accountType = '普通',
    this.accountNumber = '',
    this.holderName = '',
    this.isActive = false,
  });

  CompanyBankAccount copyWith({
    String? bankName,
    String? branchName,
    String? accountType,
    String? accountNumber,
    String? holderName,
    bool? isActive,
  }) {
    return CompanyBankAccount(
      bankName: bankName ?? this.bankName,
      branchName: branchName ?? this.branchName,
      accountType: accountType ?? this.accountType,
      accountNumber: accountNumber ?? this.accountNumber,
      holderName: holderName ?? this.holderName,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() => {
        'bankName': bankName,
        'branchName': branchName,
        'accountType': accountType,
        'accountNumber': accountNumber,
        'holderName': holderName,
        'isActive': isActive,
      };

  factory CompanyBankAccount.fromJson(Map<String, dynamic> json) {
    return CompanyBankAccount(
      bankName: json['bankName'] as String? ?? '',
      branchName: json['branchName'] as String? ?? '',
      accountType: json['accountType'] as String? ?? '普通',
      accountNumber: json['accountNumber'] as String? ?? '',
      holderName: json['holderName'] as String? ?? '',
      isActive: (json['isActive'] as bool?) ?? false,
    );
  }
}

class CompanyProfile {
  final String companyName;
  final String companyZip;
  final String companyAddress;
  final String companyTel;
  final String companyFax;
  final String companyEmail;
  final String companyUrl;
  final String companyReg;
  final String staffName;
  final String staffEmail;
  final String staffMobile;
  final List<CompanyBankAccount> bankAccounts;
  final double taxRate;
  final String taxDisplayMode;
  final String? sealPath;

  const CompanyProfile({
    this.companyName = '',
    this.companyZip = '',
    this.companyAddress = '',
    this.companyTel = '',
    this.companyFax = '',
    this.companyEmail = '',
    this.companyUrl = '',
    this.companyReg = '',
    this.staffName = '',
    this.staffEmail = '',
    this.staffMobile = '',
    List<CompanyBankAccount>? bankAccounts,
    this.taxRate = 0.10,
    this.taxDisplayMode = 'normal',
    this.sealPath,
  }) : bankAccounts = bankAccounts ?? const [
          CompanyBankAccount(),
          CompanyBankAccount(),
          CompanyBankAccount(),
          CompanyBankAccount(),
        ];

  CompanyProfile copyWith({
    String? companyName,
    String? companyZip,
    String? companyAddress,
    String? companyTel,
    String? companyFax,
    String? companyEmail,
    String? companyUrl,
    String? companyReg,
    String? staffName,
    String? staffEmail,
    String? staffMobile,
    List<CompanyBankAccount>? bankAccounts,
    double? taxRate,
    String? taxDisplayMode,
    String? sealPath,
  }) {
    return CompanyProfile(
      companyName: companyName ?? this.companyName,
      companyZip: companyZip ?? this.companyZip,
      companyAddress: companyAddress ?? this.companyAddress,
      companyTel: companyTel ?? this.companyTel,
      companyFax: companyFax ?? this.companyFax,
      companyEmail: companyEmail ?? this.companyEmail,
      companyUrl: companyUrl ?? this.companyUrl,
      companyReg: companyReg ?? this.companyReg,
      staffName: staffName ?? this.staffName,
      staffEmail: staffEmail ?? this.staffEmail,
      staffMobile: staffMobile ?? this.staffMobile,
      bankAccounts: bankAccounts ?? this.bankAccounts,
      taxRate: taxRate ?? this.taxRate,
      taxDisplayMode: taxDisplayMode ?? this.taxDisplayMode,
      sealPath: sealPath ?? this.sealPath,
    );
  }
}

class CompanyProfileService {
  CompanyProfileService({AppSettingsRepository? repo}) : _repo = repo ?? AppSettingsRepository();

  final AppSettingsRepository _repo;

  Future<CompanyProfile> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();

    Future<String> loadString(String key) async {
      final prefValue = prefs.getString(key);
      if (prefValue != null) return prefValue;
      return await _repo.getString(key) ?? '';
    }

    final accountsRaw = prefs.getString(kCompanyBankAccountsKey) ?? await _repo.getString(kCompanyBankAccountsKey);
    final accounts = _decodeAccounts(accountsRaw);
    final taxRateStr = prefs.getString(kCompanyTaxRateKey) ?? await _repo.getString(kCompanyTaxRateKey);
    final taxMode = prefs.getString(kCompanyTaxDisplayModeKey) ?? await _repo.getString(kCompanyTaxDisplayModeKey);
    final sealPath = prefs.getString(kCompanySealPathKey) ?? await _repo.getString(kCompanySealPathKey);

    return CompanyProfile(
      companyName: await loadString(kCompanyNameKey),
      companyZip: await loadString(kCompanyZipKey),
      companyAddress: await loadString(kCompanyAddressKey),
      companyTel: await loadString(kCompanyTelKey),
      companyFax: await loadString(kCompanyFaxKey),
      companyEmail: await loadString(kCompanyEmailKey),
      companyUrl: await loadString(kCompanyUrlKey),
      companyReg: await loadString(kCompanyRegKey),
      staffName: await loadString(kStaffNameKey),
      staffEmail: await loadString(kStaffEmailKey),
      staffMobile: await loadString(kStaffMobileKey),
      bankAccounts: accounts,
      taxRate: double.tryParse(taxRateStr ?? '') ?? 0.10,
      taxDisplayMode: taxMode ?? 'normal',
      sealPath: sealPath?.isNotEmpty == true ? sealPath : null,
    );
  }

  Future<void> saveProfile(CompanyProfile profile) async {
    final prefs = await SharedPreferences.getInstance();

    Future<void> persist(String key, String value) async {
      await prefs.setString(key, value);
      await _repo.setString(key, value);
    }

    await persist(kCompanyNameKey, profile.companyName);
    await persist(kCompanyZipKey, profile.companyZip);
    await persist(kCompanyAddressKey, profile.companyAddress);
    await persist(kCompanyTelKey, profile.companyTel);
    await persist(kCompanyFaxKey, profile.companyFax);
    await persist(kCompanyEmailKey, profile.companyEmail);
    await persist(kCompanyUrlKey, profile.companyUrl);
    await persist(kCompanyRegKey, profile.companyReg);
    await persist(kStaffNameKey, profile.staffName);
    await persist(kStaffEmailKey, profile.staffEmail);
    await persist(kStaffMobileKey, profile.staffMobile);

    final accountsJson = jsonEncode(profile.bankAccounts.map((e) => e.toJson()).toList());
    await persist(kCompanyBankAccountsKey, accountsJson);
    await persist(kCompanyTaxRateKey, profile.taxRate.toString());
    await persist(kCompanyTaxDisplayModeKey, profile.taxDisplayMode);
    await persist(kCompanySealPathKey, profile.sealPath ?? '');
  }

  Future<Map<String, String>> buildMailPlaceholderMap({
    required String filename,
    required String hash,
  }) async {
    final profile = await loadProfile();
    final activeAccounts = profile.bankAccounts.where((e) => e.isActive && e.bankName.trim().isNotEmpty).toList();
    final bankText = _composeBankText(activeAccounts);

    return {
      kMailPlaceholderFilename: filename,
      kMailPlaceholderHash: hash,
      kMailPlaceholderCompanyName: profile.companyName.isNotEmpty ? profile.companyName : '弊社',
      kMailPlaceholderCompanyEmail: profile.companyEmail.isNotEmpty ? profile.companyEmail : profile.staffEmail,
      kMailPlaceholderCompanyTel: profile.companyTel,
      kMailPlaceholderCompanyAddress: profile.companyAddress,
      kMailPlaceholderCompanyReg: profile.companyReg,
      kMailPlaceholderStaffName: profile.staffName.isNotEmpty ? profile.staffName : '担当者',
      kMailPlaceholderStaffEmail: profile.staffEmail,
      kMailPlaceholderStaffMobile: profile.staffMobile.isNotEmpty ? profile.staffMobile : '---',
      kMailPlaceholderBankAccounts: bankText,
    };
  }

  List<CompanyBankAccount> _decodeAccounts(String? raw) {
    if (raw == null || raw.isEmpty) {
      return List.generate(kCompanyBankSlotCount, (_) => const CompanyBankAccount());
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final list = decoded
            .map((e) => CompanyBankAccount.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        while (list.length < kCompanyBankSlotCount) {
          list.add(const CompanyBankAccount());
        }
        return list.take(kCompanyBankSlotCount).toList();
      }
    } catch (_) {
      // ignore malformed data
    }
    return List.generate(kCompanyBankSlotCount, (_) => const CompanyBankAccount());
  }

  String _composeBankText(List<CompanyBankAccount> accounts) {
    if (accounts.isEmpty) {
      return '振込先: ご入金方法は別途ご案内いたします。';
    }
    final buffer = StringBuffer('振込先:\n');
    for (var i = 0; i < accounts.length && i < kCompanyBankActiveLimit; i++) {
      final acc = accounts[i];
      buffer.writeln(
        '(${i + 1}) ${acc.bankName} ${acc.branchName} ${acc.accountType} ${acc.accountNumber} ${acc.holderName}',
      );
    }
    return buffer.toString().trim();
  }
}
