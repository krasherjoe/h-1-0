import '../models/customer_model.dart';
import '../models/customer_model.dart' show HonorificCode;

/// 敬称スクリーニング結果
class HonorificsIssue {
  final Customer original;
  final String fixedFormalName;
  final String fixedDisplayName;
  final List<String> reasons;

  HonorificsIssue({
    required this.original,
    required this.fixedFormalName,
    required this.fixedDisplayName,
    required this.reasons,
  });

  Customer get fixed => original.copyWith(
        formalName: fixedFormalName,
        displayName: fixedDisplayName,
      );

  bool get hasChange =>
      fixedFormalName != original.formalName ||
      fixedDisplayName != original.displayName;
}

/// 顧客データのクリーニング機能
class CustomerDataCleaner {
  /// 末尾の敬称を検出する正規表現（半角・全角スペース対応）
  static final _honorificRegex = RegExp(r'[\s\u3000]*(様|御中|殿|先生)$');

  /// 文字列末尾の敬称を除去
  static String removeTitleFromName(String name) {
    return name.replaceAll(_honorificRegex, '').trim();
  }

  /// 文字列が末尾に敬称を持つか
  static bool hasTrailingHonorific(String name) {
    return _honorificRegex.hasMatch(name);
  }

  /// 顧客の敬称問題を分析して返す（問題なければ null）
  static HonorificsIssue? analyzeCustomer(Customer customer) {
    final reasons = <String>[];
    var fixedFormal = customer.formalName;
    var fixedDisplay = customer.displayName;

    // formalName の末尾に敬称がある → invoiceName で二重になる
    if (hasTrailingHonorific(customer.formalName)) {
      fixedFormal = removeTitleFromName(customer.formalName);
      reasons.add('正式名称末尾「${customer.formalName}」に敬称あり');
    }

    // displayName の末尾に敬称がある
    if (hasTrailingHonorific(customer.displayName)) {
      fixedDisplay = removeTitleFromName(customer.displayName);
      reasons.add('表示名末尾「${customer.displayName}」に敬称あり');
    }

    if (reasons.isEmpty) return null;
    return HonorificsIssue(
      original: customer,
      fixedFormalName: fixedFormal,
      fixedDisplayName: fixedDisplay,
      reasons: reasons,
    );
  }

  /// 全顧客をスキャンして問題リストを返す
  static List<HonorificsIssue> screenAll(List<Customer> customers) {
    return customers
        .map(analyzeCustomer)
        .whereType<HonorificsIssue>()
        .toList();
  }

  // ─── 後方互換メソッド（既存コードから呼ばれる） ──────────────────────

  static int cleanTitle(String formalName, int title) {
    final titleStr = HonorificCode.toName(title);
    for (final h in ['様', '御中', '殿', '貴社']) {
      if (formalName.endsWith(h) && titleStr == h) return HonorificCode.san;
    }
    return title;
  }

  static Customer cleanCustomer(Customer customer) {
    final cleanedTitle = cleanTitle(customer.formalName, customer.title);
    return cleanedTitle != customer.title
        ? customer.copyWith(title: cleanedTitle)
        : customer;
  }

  static List<Customer> cleanCustomers(List<Customer> customers) =>
      customers.map(cleanCustomer).toList();

  static bool hasDuplicateHonorific(String formalName, int title) {
    final titleStr = HonorificCode.toName(title);
    for (final h in ['様', '御中', '殿', '貴社']) {
      if (formalName.endsWith(h) && titleStr == h) return true;
    }
    return false;
  }

  static List<Customer> filterDuplicateHonorific(List<Customer> customers) =>
      customers.where((c) => hasDuplicateHonorific(c.formalName, c.title)).toList();

  static Customer removeHonorificFromName(Customer customer) {
    final cleaned = removeTitleFromName(customer.formalName);
    return cleaned != customer.formalName
        ? customer.copyWith(formalName: cleaned)
        : customer;
  }

  static List<Customer> removeHonorificFromNames(List<Customer> customers) =>
      customers.map(removeHonorificFromName).toList();
}
