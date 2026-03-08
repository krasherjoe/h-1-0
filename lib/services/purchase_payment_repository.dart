import 'package:sqflite/sqflite.dart';

import '../models/purchase_order_models.dart';
import 'database_helper.dart';

class PurchasePaymentRepository {
  PurchasePaymentRepository();

  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<void> upsertPayment(PurchasePayment payment) async {
    final db = await _dbHelper.database;
    await db.insert('purchase_payments', payment.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<PurchasePayment?> findById(String id) async {
    final db = await _dbHelper.database;
    final rows = await db.query('purchase_payments', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return PurchasePayment.fromMap(rows.first);
  }

  Future<List<PurchasePayment>> fetchPayments({String? supplierId, String? purchaseOrderId, PurchasePaymentStatus? status}) async {
    final db = await _dbHelper.database;
    final where = <String>[];
    final args = <Object?>[];
    if (supplierId != null) {
      where.add('supplier_id = ?');
      args.add(supplierId);
    }
    if (purchaseOrderId != null) {
      where.add('purchase_order_id = ?');
      args.add(purchaseOrderId);
    }
    if (status != null) {
      where.add('status = ?');
      args.add(status.name);
    }
    final rows = await db.query(
      'purchase_payments',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'payment_date DESC, updated_at DESC',
    );
    return rows.map(PurchasePayment.fromMap).toList();
  }

  Future<void> deletePayment(String id) async {
    final db = await _dbHelper.database;
    await db.delete('purchase_payments', where: 'id = ?', whereArgs: [id]);
  }
}
