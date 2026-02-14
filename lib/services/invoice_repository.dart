import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../models/invoice_models.dart';
import '../models/customer_model.dart';
import 'database_helper.dart';

class InvoiceRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<void> saveInvoice(Invoice invoice) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // 伝票ヘッダーの保存
      await txn.insert(
        'invoices',
        invoice.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 既存の明細を一旦削除（更新対応）
      await txn.delete(
        'invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [invoice.id],
      );

      // 新しい明細の保存
      for (var item in invoice.items) {
        await txn.insert('invoice_items', item.toMap(invoice.id));
      }
    });
  }

  Future<List<Invoice>> getAllInvoices(List<Customer> customers) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> invoiceMaps = await db.query('invoices', orderBy: 'date DESC');

    List<Invoice> invoices = [];
    for (var iMap in invoiceMaps) {
      final customer = customers.firstWhere(
        (c) => c.id == iMap['customer_id'],
        orElse: () => Customer(id: iMap['customer_id'], displayName: "不明", formalName: "不明"),
      );

      final List<Map<String, dynamic>> itemMaps = await db.query(
        'invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [iMap['id']],
      );

      final items = List.generate(itemMaps.length, (i) => InvoiceItem.fromMap(itemMaps[i]));

      invoices.add(Invoice(
        id: iMap['id'],
        customer: customer,
        date: DateTime.parse(iMap['date']),
        items: items,
        notes: iMap['notes'],
        filePath: iMap['file_path'],
        taxRate: iMap['tax_rate'] ?? 0.10, // 追加
        odooId: iMap['odoo_id'],
        isSynced: iMap['is_synced'] == 1,
        updatedAt: DateTime.parse(iMap['updated_at']),
      ));
    }
    return invoices;
  }

  Future<void> deleteInvoice(String id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // PDFパスの取得（削除用）
      final List<Map<String, dynamic>> maps = await txn.query(
        'invoices',
        columns: ['file_path'],
        where: 'id = ?',
        whereArgs: [id],
      );
      
      if (maps.isNotEmpty && maps.first['file_path'] != null) {
        final file = File(maps.first['file_path']);
        if (await file.exists()) {
          await file.delete();
        }
      }

      await txn.delete(
        'invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'invoices',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<int> cleanupOrphanedPdfs() async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) return 0;

      final files = directory.listSync().whereType<File>().toList();
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> results = await db.query('invoices', columns: ['file_path']);
      final activePaths = results.map((r) => r['file_path'] as String?).where((p) => p != null).toSet();

      int count = 0;
      for (var file in files) {
        if (file.path.endsWith('.pdf') && !activePaths.contains(file.path)) {
          await file.delete();
          count++;
        }
      }
      return count;
    } catch (e) {
      return 0;
    }
  }
}
