import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/payment_model.dart';
import '../models/supplier_model.dart';
import '../models/base_document.dart';
import '../services/supplier_repository.dart';
import '../services/database_helper.dart';

/// 支払リポジトリ
class PaymentRepository {
  final DatabaseHelper _db = DatabaseHelper();
  final SupplierRepository _supplierRepo = SupplierRepository();

  /// すべての支払を取得
  Future<List<Payment>> getAllPayments() async {
    final database = await _db.database;
    final suppliers = await _supplierRepo.getAllSuppliers();
    
    final maps = await database.query(
      'payments',
      orderBy: 'payment_date DESC',
    );

    return maps.map((map) {
      final supplierId = map['supplier_id'] as String;
      final supplier = suppliers.firstWhere(
        (s) => s.id == supplierId,
        orElse: () => Supplier(
          id: supplierId,
          displayName: '不明な仕入先',
          formalName: '不明な仕入先',
          updatedAt: DateTime.now(),
        ),
      );

      return Payment.fromMap(map, supplier);
    }).toList();
  }

  /// 支払を保存
  Future<void> savePayment(Payment payment) async {
    final database = await _db.database;
    await database.insert(
      'payments',
      payment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // 支払・仕入紐付けを保存
    for (final purchaseId in payment.purchaseIds) {
      await database.insert(
        'payment_purchases',
        {
          'id': const Uuid().v4(),
          'payment_id': payment.id,
          'purchase_id': purchaseId,
          'amount': payment.amount,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// 支払を削除
  Future<void> deletePayment(String id) async {
    final database = await _db.database;
    
    // 支払・仕入紐付けを削除
    await database.delete(
      'payment_purchases',
      where: 'payment_id = ?',
      whereArgs: [id],
    );
    
    // 支払を削除
    await database.delete(
      'payments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 特定支払を取得
  Future<Payment?> getPayment(String id) async {
    final database = await _db.database;
    final maps = await database.query(
      'payments',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    
    final map = maps.first;
    final supplierId = map['supplier_id'] as String;
    final supplier = await _supplierRepo.getSupplier(supplierId);
    
    if (supplier == null) return null;
    
    return Payment.fromMap(map, supplier);
  }

  /// 支払番号を生成
  String generatePaymentNumber() {
    final now = DateTime.now();
    final year = now.year % 100; // 下2桁
    final month = now.month.toString().padLeft(2, '0');
    return 'PAY$year$month-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
  }

  /// 仕入先別の支払集計
  Future<Map<String, int>> getPaymentTotalBySupplier() async {
    final database = await _db.database;
    final maps = await database.rawQuery('''
      SELECT supplier_id, SUM(amount) as total
      FROM payments
      GROUP BY supplier_id
    ''');

    final result = <String, int>{};
    for (final map in maps) {
      result[map['supplier_id'] as String] = map['total'] as int;
    }
    return result;
  }

  /// 月次支払集計
  Future<Map<String, int>> getMonthlyPaymentTotals({int months = 12}) async {
    final database = await _db.database;
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month - months + 1, 1);
    
    final maps = await database.rawQuery('''
      SELECT 
        strftime('%Y-%m', payment_date) as month,
        SUM(amount) as total
      FROM payments
      WHERE payment_date >= ?
      GROUP BY strftime('%Y-%m', payment_date)
      ORDER BY month
    ''', [startDate.toIso8601String()]);

    final result = <String, int>{};
    for (final map in maps) {
      result[map['month'] as String] = map['total'] as int;
    }
    return result;
  }

  /// 支払方法別集計
  Future<Map<PaymentMethod, int>> getPaymentTotalsByMethod() async {
    final database = await _db.database;
    final maps = await database.rawQuery('''
      SELECT payment_method, SUM(amount) as total
      FROM payments
      GROUP BY payment_method
    ''');

    final result = <PaymentMethod, int>{};
    for (final map in maps) {
      final method = PaymentMethod.values.firstWhere(
        (e) => e.name == map['payment_method'],
        orElse: () => PaymentMethod.bankTransfer,
      );
      result[method] = map['total'] as int;
    }
    return result;
  }

}
