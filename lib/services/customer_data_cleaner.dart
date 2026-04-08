import '../models/customer_model.dart';

/// 顧客データのクリーニング機能
class CustomerDataCleaner {
  /// 敬称の重複をチェックして削除
  static String cleanTitle(String formalName, String title) {
    // 正式名称の末尾に敬称が既に含まれているかチェック
    final honorifics = ['様', '御中', '殿', '貴社'];
    
    for (final honorific in honorifics) {
      if (formalName.endsWith(honorific)) {
        // 正式名称に敬称が含まれている場合、title から同じ敬称を削除
        if (title == honorific) {
          return '様'; // デフォルトに戻す
        }
        return title;
      }
    }
    
    return title;
  }

  /// 顧客データから無駄な敬称を削除
  static Customer cleanCustomer(Customer customer) {
    final cleanedTitle = cleanTitle(customer.formalName, customer.title);
    
    if (cleanedTitle != customer.title) {
      return customer.copyWith(title: cleanedTitle);
    }
    
    return customer;
  }

  /// 複数の顧客データをクリーニング
  static List<Customer> cleanCustomers(List<Customer> customers) {
    return customers.map((c) => cleanCustomer(c)).toList();
  }

  /// 敬称の重複を検出
  static bool hasDuplicateHonorific(String formalName, String title) {
    final honorifics = ['様', '御中', '殿', '貴社'];
    
    for (final honorific in honorifics) {
      if (formalName.endsWith(honorific) && title == honorific) {
        return true;
      }
    }
    
    return false;
  }

  /// 敬称の重複がある顧客をフィルタ
  static List<Customer> filterDuplicateHonorific(List<Customer> customers) {
    return customers.where((c) => hasDuplicateHonorific(c.formalName, c.title)).toList();
  }

  /// 正式名称から敬称を削除
  static String removeTitleFromName(String formalName) {
    final honorifics = ['様', '御中', '殿', '貴社'];
    
    String cleaned = formalName;
    for (final honorific in honorifics) {
      if (cleaned.endsWith(honorific)) {
        cleaned = cleaned.substring(0, cleaned.length - honorific.length).trim();
      }
    }
    
    return cleaned;
  }

  /// 正式名称から敬称を削除した顧客を返す
  static Customer removeHonorificFromName(Customer customer) {
    final cleanedName = removeTitleFromName(customer.formalName);
    
    if (cleanedName != customer.formalName) {
      return customer.copyWith(formalName: cleanedName);
    }
    
    return customer;
  }

  /// 複数の顧客から敬称を削除
  static List<Customer> removeHonorificFromNames(List<Customer> customers) {
    return customers.map((c) => removeHonorificFromName(c)).toList();
  }
}
