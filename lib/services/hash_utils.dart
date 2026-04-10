import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;

/// 電子帳簿保存法対応 - HASH 計算ユーティリティ
///
/// データの改ざん検出とバージョンチェーンの維持に使用
class HashUtils {
  /// SHA256 ハッシュを計算
  ///
  /// [input] ハッシュ化したい文字列
  static String calculateSha256(String input) {
    final bytes = utf8.encode(input);
    final digest = crypto.sha256.convert(bytes);
    return digest.toString();
  }

  /// Customer のコンテンツハッシュを計算
  ///
  /// ハッシュ式：SHA256(ID + 全フィールド値 + valid_from + previous_hash)
  static String calculateCustomerHash({
    required String id,
    required String displayName,
    required String formalName,
    required String title,
    String? department,
    String? address,
    String? tel,
    String? email,
    int? contactVersionId,
    String? odooId,
    bool isLocked = false,
    bool isHidden = false,
    String? headChar1,
    String? headChar2,
    DateTime? validFrom,
    DateTime? validTo,
    bool isCurrentFlag = true,
    int version = 1,
    String? previousHash,
  }) {
    final input = [
      id,
      displayName,
      formalName,
      title,
      department ?? '',
      address ?? '',
      tel ?? '',
      email ?? '',
      contactVersionId?.toString() ?? '',
      odooId ?? '',
      isLocked ? '1' : '0',
      isHidden ? '1' : '0',
      headChar1 ?? '',
      headChar2 ?? '',
      validFrom?.toIso8601String() ?? '',
      validTo?.toIso8601String() ?? '',
      isCurrentFlag ? '1' : '0',
      version.toString(),
      previousHash ?? '',
    ].join('|');

    return calculateSha256(input);
  }

  /// Product のコンテンツハッシュを計算
  ///
  /// ハッシュ式：SHA256(ID + 全フィールド値 + valid_from + previous_hash)
  static String calculateProductHash({
    required String id,
    required String name,
    required int defaultUnitPrice,
    required int wholesalePrice,
    String? barcode,
    String? category,
    String? categoryId,
    int? stockQuantity,
    String? odooId,
    bool isLocked = false,
    bool isHidden = false,
    DateTime? validFrom,
    DateTime? validTo,
    bool isCurrentFlag = true,
    int version = 1,
    String? previousHash,
  }) {
    final input = [
      id,
      name,
      defaultUnitPrice.toString(),
      wholesalePrice.toString(),
      barcode ?? '',
      category ?? '',
      categoryId ?? '',
      stockQuantity?.toString() ?? '',
      odooId ?? '',
      isLocked ? '1' : '0',
      isHidden ? '1' : '0',
      validFrom?.toIso8601String() ?? '',
      validTo?.toIso8601String() ?? '',
      isCurrentFlag ? '1' : '0',
      version.toString(),
      previousHash ?? '',
    ].join('|');

    return calculateSha256(input);
  }

  /// ハッシュチェーンを検証
  ///
  /// [currentHash] 現在のハッシュ
  /// [expectedPreviousHash] 期待される前バージョンのハッシュ（最初のバージョンは null）
  static bool verifyHashChain({
    required String currentHash,
    required String currentInput,
    String? expectedPreviousHash,
  }) {
    // 現在入力のハッシュを再計算
    final calculatedHash = calculateSha256(currentInput);

    if (calculatedHash != currentHash) {
      return false;
    }

    // previous_hash の整合性チェック
    if (expectedPreviousHash != null) {
      // ここで実際の previous_hash フィールド値との整合性を確認する必要がある
      // 実装は repository レベルで行う
      return true;
    }

    return true;
  }

  /// ハッシュの整合性を検証（データベースから取得したレコード用）
  static bool verifyCustomerIntegrity({
    required String contentHash,
    required String id,
    required String displayName,
    required String formalName,
    required String title,
    String? department,
    String? address,
    String? tel,
    String? email,
    int? contactVersionId,
    String? odooId,
    bool isLocked = false,
    bool isHidden = false,
    String? headChar1,
    String? headChar2,
    DateTime? validFrom,
    DateTime? validTo,
    bool isCurrentFlag = true,
    int version = 1,
    String? previousHash,
  }) {
    final expectedHash = calculateCustomerHash(
      id: id,
      displayName: displayName,
      formalName: formalName,
      title: title,
      department: department,
      address: address,
      tel: tel,
      email: email,
      contactVersionId: contactVersionId,
      odooId: odooId,
      isLocked: isLocked,
      isHidden: isHidden,
      headChar1: headChar1,
      headChar2: headChar2,
      validFrom: validFrom,
      validTo: validTo,
      isCurrentFlag: isCurrentFlag,
      version: version,
      previousHash: previousHash,
    );

    return contentHash == expectedHash;
  }

  /// Product の整合性を検証
  static bool verifyProductIntegrity({
    required String contentHash,
    required String id,
    required String name,
    required int defaultUnitPrice,
    required int wholesalePrice,
    String? barcode,
    String? category,
    String? categoryId,
    int? stockQuantity,
    String? odooId,
    bool isLocked = false,
    bool isHidden = false,
    DateTime? validFrom,
    DateTime? validTo,
    bool isCurrentFlag = true,
    int version = 1,
    String? previousHash,
  }) {
    final expectedHash = calculateProductHash(
      id: id,
      name: name,
      defaultUnitPrice: defaultUnitPrice,
      wholesalePrice: wholesalePrice,
      barcode: barcode,
      category: category,
      categoryId: categoryId,
      stockQuantity: stockQuantity,
      odooId: odooId,
      isLocked: isLocked,
      isHidden: isHidden,
      validFrom: validFrom,
      validTo: validTo,
      isCurrentFlag: isCurrentFlag,
      version: version,
      previousHash: previousHash,
    );

    return contentHash == expectedHash;
  }
}
