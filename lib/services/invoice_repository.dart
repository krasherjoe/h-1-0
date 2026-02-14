import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../models/invoice_models.dart';
import '../models/customer_model.dart';
import 'database_helper.dart';
import 'activity_log_repository.dart';

class InvoiceRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ActivityLogRepository _logRepo = ActivityLogRepository();

  Future<void> saveInvoice(Invoice invoice) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // 在庫の調整（更新の場合、以前の数量を戻してから新しい数量を引く）
      final List<Map<String, dynamic>> oldItems = await txn.query(
        'invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [invoice.id],
      );

      // 旧在庫を戻す
      for (var item in oldItems) {
        if (item['product_id'] != null) {
          await txn.execute(
            'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
            [item['quantity'], item['product_id']],
          );
        }
      }

      // 伝票ヘッダーの保存
      await txn.insert(
        'invoices',
        invoice.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 既存の明細を一旦削除
      await txn.delete(
        'invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [invoice.id],
      );

      // 新しい明細の保存と在庫の減算
      for (var item in invoice.items) {
        await txn.insert('invoice_items', item.toMap(invoice.id));
        if (item.productId != null) {
          await txn.execute(
            'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
            [item.quantity, item.productId],
          );
        }
      }
    });

    await _logRepo.logAction(
      action: "SAVE_INVOICE",
      targetType: "INVOICE",
      targetId: invoice.id,
      details: "種別: ${invoice.documentTypeName}, 取引先: ${invoice.customerNameForDisplay}, 合計: ￥${invoice.totalAmount}",
    );
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

      // document_typeのパース
      DocumentType docType = DocumentType.invoice;
      if (iMap['document_type'] != null) {
        try {
          docType = DocumentType.values.firstWhere((e) => e.name == iMap['document_type']);
        } catch (_) {}
      }

      invoices.add(Invoice(
        id: iMap['id'],
        customer: customer,
        date: DateTime.parse(iMap['date']),
        items: items,
        notes: iMap['notes'],
        filePath: iMap['file_path'],
        taxRate: iMap['tax_rate'] ?? 0.10,
        documentType: docType,
        customerFormalNameSnapshot: iMap['customer_formal_name'],
        odooId: iMap['odoo_id'],
        isSynced: iMap['is_synced'] == 1,
        updatedAt: DateTime.parse(iMap['updated_at']),
        latitude: iMap['latitude'],
        longitude: iMap['longitude'],
      ));
    }
    return invoices;
  }

  Future<void> deleteInvoice(String id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // 在庫の復元
      final List<Map<String, dynamic>> items = await txn.query(
        'invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [id],
      );

      for (var item in items) {
        if (item['product_id'] != null) {
          await txn.execute(
            'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
            [item['quantity'], item['product_id']],
          );
        }
      }

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

  Future<Map<String, int>> getMonthlySales(int year) async {
    final db = await _dbHelper.database;
    final String yearStr = year.toString();
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT strftime('%m', date) as month, SUM(total_amount) as total
      FROM invoices
      WHERE strftime('%Y', date) = ? AND document_type = 'invoice'
      GROUP BY month
      ORDER BY month ASC
    ''', [yearStr]);

    Map<String, int> monthlyTotal = {};
    for (var r in results) {
      monthlyTotal[r['month']] = (r['total'] as num).toInt();
    }
    return monthlyTotal;
  }

  Future<int> getYearlyTotal(int year) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT SUM(total_amount) as total
      FROM invoices
      WHERE strftime('%Y', date) = ? AND document_type = 'invoice'
    ''', [year.toString()]);

    if (results.isEmpty || results.first['total'] == null) return 0;
    return (results.first['total'] as num).toInt();
  }
}
