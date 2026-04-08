import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';
import '../models/company_model.dart';

/// 会社情報のエクスポート・インポート機能
class CompanyInfoExportImport {
  /// システムのダウンロードフォルダを取得
  /// Android: /storage/emulated/0/Download
  /// iOS: Documents フォルダ（iOS にはシステムダウンロードフォルダがない）
  static Future<Directory> _getDownloadDirectory() async {
    try {
      final dir = await getDownloadsDirectory();
      if (dir != null) {
        debugPrint('[CompanyExport] ダウンロードフォルダ: ${dir.path}');
        return dir;
      }
    } catch (e) {
      debugPrint('[CompanyExport] ダウンロードフォルダ取得エラー: $e');
    }
    
    // フォールバック: Documents フォルダ
    final docDir = await getApplicationDocumentsDirectory();
    debugPrint('[CompanyExport] Documents フォルダを使用: ${docDir.path}');
    return docDir;
  }

  /// 会社情報を JSON ファイルにエクスポート（システムのダウンロードフォルダに保存）
  static Future<File> exportToJson(CompanyInfo info) async {
    final dir = await _getDownloadDirectory();
    final fileName = 'company_info_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File('${dir.path}/$fileName');

    final json = {
      'name': info.name,
      'zipCode': info.zipCode,
      'address': info.address,
      'tel': info.tel,
      'email': info.email,
      'fax': info.fax,
      'url': info.url,
      'defaultTaxRate': info.defaultTaxRate,
      'taxDisplayMode': info.taxDisplayMode,
      'exportedAt': DateTime.now().toIso8601String(),
    };

    await file.writeAsString(jsonEncode(json));
    return file;
  }

  /// 会社情報を CSV ファイルにエクスポート（システムのダウンロードフォルダに保存）
  static Future<File> exportToCsv(CompanyInfo info) async {
    final dir = await _getDownloadDirectory();
    final fileName = 'company_info_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File('${dir.path}/$fileName');

    final csv = '''項目,値
自社名,${_escapeCsv(info.name)}
郵便番号,${_escapeCsv(info.zipCode ?? '')}
住所,${_escapeCsv(info.address ?? '')}
電話番号,${_escapeCsv(info.tel ?? '')}
メールアドレス,${_escapeCsv(info.email ?? '')}
FAX,${_escapeCsv(info.fax ?? '')}
ウェブサイト URL,${_escapeCsv(info.url ?? '')}
デフォルト消費税率,${(info.defaultTaxRate * 100).toStringAsFixed(0)}%
消費税表示設定,${_getTaxDisplayModeLabel(info.taxDisplayMode)}
エクスポート日時,${DateTime.now().toIso8601String()}
''';

    await file.writeAsString(csv);
    return file;
  }

  /// JSON ファイルから会社情報をインポート
  static Future<CompanyInfo> importFromJson(File file) async {
    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;

    return CompanyInfo(
      name: json['name'] ?? '',
      zipCode: json['zipCode'],
      address: json['address'],
      tel: json['tel'],
      email: json['email'],
      fax: json['fax'],
      url: json['url'],
      defaultTaxRate: (json['defaultTaxRate'] ?? 0.10).toDouble(),
      taxDisplayMode: json['taxDisplayMode'] ?? 'normal',
      sealPath: null, // 角印は含めない
    );
  }

  /// CSV ファイルから会社情報をインポート（簡易版）
  static Future<CompanyInfo> importFromCsv(File file) async {
    final content = await file.readAsString();
    final lines = content.split('\n');

    final data = <String, String>{};
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final parts = line.split(',');
      if (parts.length >= 2) {
        final key = parts[0].trim();
        final value = parts.sublist(1).join(',').trim();
        data[key] = _unescapeCsv(value);
      }
    }

    double taxRate = 0.10;
    if (data['デフォルト消費税率'] != null) {
      final rateStr = data['デフォルト消費税率']!.replaceAll('%', '').trim();
      taxRate = double.tryParse(rateStr) ?? 10.0;
      taxRate = taxRate / 100.0;
    }

    return CompanyInfo(
      name: data['自社名'] ?? '',
      zipCode: data['郵便番号'],
      address: data['住所'],
      tel: data['電話番号'],
      email: data['メールアドレス'],
      fax: data['FAX'],
      url: data['ウェブサイト URL'],
      defaultTaxRate: taxRate,
      taxDisplayMode: data['消費税表示設定'] ?? 'normal',
      sealPath: null, // 角印は含めない
    );
  }

  /// CSV エスケープ処理
  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// CSV アンエスケープ処理
  static String _unescapeCsv(String value) {
    if (value.startsWith('"') && value.endsWith('"')) {
      return value.substring(1, value.length - 1).replaceAll('""', '"');
    }
    return value;
  }

  /// 消費税表示モードのラベルを取得
  static String _getTaxDisplayModeLabel(String mode) {
    switch (mode) {
      case 'normal':
        return '通常表示';
      case 'hidden':
        return '表示しない';
      case 'text_only':
        return '「税別」と表示';
      default:
        return mode;
    }
  }
}
