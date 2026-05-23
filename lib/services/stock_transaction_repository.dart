import 'package:uuid/uuid.dart';
import '../models/stock_transaction_model.dart';
import 'database_helper.dart';

/// 在庫入出庫トランザクションリポジトリ
class StockTransactionRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<StockTransaction>> getAll({String? productId, int limit = 100}) async {
    final db = await _db.database;
    final where = <String>[];
    final args = <Object?>[];
    if (productId != null) { where.add('product_id = ?'); args.add(productId); }
    final rows = await db.query('stock_transactions',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(StockTransaction.fromMap).toList();
  }

  /// 入庫処理
  Future<void> inbound({
    required String productId,
    required String productName,
    required int quantity,
    String? warehouseId,
    String? warehouseName,
    String? type,
    String? referenceId,
    String? referenceNumber,
    String? notes,
  }) async {
    final db = await _db.database;
    await db.insert('stock_transactions', StockTransaction(
      id: const Uuid().v4(),
      productId: productId,
      productName: productName,
      warehouseId: warehouseId,
      warehouseName: warehouseName,
      quantity: quantity.abs(),
      type: type ?? 'inbound',
      referenceId: referenceId,
      referenceNumber: referenceNumber,
      notes: notes,
      createdAt: DateTime.now(),
    ).toMap());
    await _updateStock(productId, quantity.abs(), warehouseId);
  }

  /// 出庫処理
  Future<void> outbound({
    required String productId,
    required String productName,
    required int quantity,
    String? warehouseId,
    String? warehouseName,
    String? type,
    String? referenceId,
    String? referenceNumber,
    String? notes,
  }) async {
    final db = await _db.database;
    await db.insert('stock_transactions', StockTransaction(
      id: const Uuid().v4(),
      productId: productId,
      productName: productName,
      warehouseId: warehouseId,
      warehouseName: warehouseName,
      quantity: -quantity.abs(),
      type: type ?? 'outbound',
      referenceId: referenceId,
      referenceNumber: referenceNumber,
      notes: notes,
      createdAt: DateTime.now(),
    ).toMap());
    await _updateStock(productId, -quantity.abs(), warehouseId);
  }

  /// warehouse_stock と products.stock_quantity を更新
  Future<void> _updateStock(String productId, int deltaQty, String? warehouseId) async {
    final db = await _db.database;
    if (warehouseId != null) {
      await db.execute('''
        INSERT INTO warehouse_stock (product_id, warehouse_id, quantity)
        VALUES (?, ?, ?)
        ON CONFLICT(product_id, warehouse_id) DO UPDATE SET
          quantity = quantity + ?
      ''', [productId, warehouseId, deltaQty > 0 ? deltaQty : 0, deltaQty]);
    }
    // 全体在庫を更新
    await db.execute('''
      UPDATE products SET stock_quantity = COALESCE((
        SELECT SUM(quantity) FROM warehouse_stock WHERE product_id = ?
      ), 0) WHERE id = ?
    ''', [productId, productId]);
    // warehouse_stock がない場合のフォールバック
    await db.execute('''
      UPDATE products SET stock_quantity = COALESCE(stock_quantity, 0) + ?
      WHERE id = ? AND (SELECT COUNT(*) FROM warehouse_stock WHERE product_id = ?) = 0
    ''', [deltaQty, productId, productId]);
  }
}
