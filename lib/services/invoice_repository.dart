import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/invoice_models.dart';

class InvoiceRepository {
  // 注: 本来は SQLite (sqflite) を使用しますが、現時点ではリファクタリングを優先し、
  // スタブ実装、または簡単な保存ロジックを提供します。
  
  Future<void> saveInvoice(Invoice invoice) async {
    debugPrint("Saving invoice: ${invoice.invoiceNumber} for ${invoice.customer.formalName}");
    // TODO: ここに SQLite への保存処理を実装予定
  }

  Future<int> cleanupOrphanedPdfs() async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) return 0;

      final List<FileSystemEntity> files = directory.listSync();
      int count = 0;
      // シンプルなクリーンアップロジック（例：古いファイルを消すなど、必要に応じて実装）
      // 現時点ではスタブとして 0 を返します。
      return count;
    } catch (e) {
      debugPrint("Cleanup error: $e");
      return 0;
    }
  }
}
