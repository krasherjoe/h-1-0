import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/invoice_models.dart';

/// 請求書のオリジナルデータを管理するリポジトリ（簡易DB）
/// PDFファイルとデータの整合性を保つための機能を提供します
class InvoiceRepository {
  static const String _dbFileName = 'invoices_db.json';

  /// データベースファイルのパスを取得
  Future<File> _getDbFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_dbFileName');
  }

  /// 全ての請求書データを読み込む
  Future<List<Invoice>> getAllInvoices() async {
    try {
      final file = await _getDbFile();
      if (!await file.exists()) return [];

      final String content = await file.readAsString();
      final List<dynamic> jsonList = json.decode(content);

      return jsonList.map((json) => Invoice.fromJson(json)).toList()
        ..sort((a, b) => b.date.compareTo(a.date)); // 新しい順にソート
    } catch (e) {
      print('DB Loading Error: $e');
      return [];
    }
  }

  /// 請求書データを保存・更新する
  Future<void> saveInvoice(Invoice invoice) async {
    final List<Invoice> all = await getAllInvoices();

    // 同じ請求番号があれば差し替え、なければ追加
    final index = all.indexWhere((i) => i.invoiceNumber == invoice.invoiceNumber);
    if (index != -1) {
      // 古いファイルが存在し、かつ新しいパスと異なる場合は古いファイルを削除（無駄なPDFの掃除）
      final oldPath = all[index].filePath;
      if (oldPath != null && oldPath != invoice.filePath) {
        await _deletePhysicalFile(oldPath);
      }
      all[index] = invoice;
    } else {
      all.add(invoice);
    }

    final file = await _getDbFile();
    await file.writeAsString(json.encode(all.map((i) => i.toJson()).toList()));
  }

  /// 請求書データを削除する
  Future<void> deleteInvoice(Invoice invoice) async {
    final List<Invoice> all = await getAllInvoices();
    all.removeWhere((i) => i.invoiceNumber == invoice.invoiceNumber);

    // 物理ファイルも削除
    if (invoice.filePath != null) {
      await _deletePhysicalFile(invoice.filePath!);
    }

    final file = await _getDbFile();
    await file.writeAsString(json.encode(all.map((i) => i.toJson()).toList()));
  }

  /// 実際のPDFファイルをストレージから削除する
  Future<void> _deletePhysicalFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        print('Physical file deleted: $path');
      }
    } catch (e) {
      print('File Deletion Error: $path, $e');
    }
  }

  /// DBに登録されていない「浮いたPDFファイル」をスキャンして掃除する
  Future<int> cleanupOrphanedPdfs() async {
    final List<Invoice> all = await getAllInvoices();
    final Set<String> registeredPaths = all
        .where((i) => i.filePath != null)
        .map((i) => i.filePath!)
        .toSet();

    final directory = await getExternalStorageDirectory();
    if (directory == null) return 0;

    int deletedCount = 0;
    final List<FileSystemEntity> files = directory.listSync();

    for (var entity in files) {
      if (entity is File && entity.path.endsWith('.pdf')) {
        // DBに登録されていないPDFは削除（無駄なゴミ）
        if (!registeredPaths.contains(entity.path)) {
          await entity.delete();
          deletedCount++;
        }
      }
    }
    return deletedCount;
  }
}
