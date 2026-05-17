import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import '../models/sales_model.dart';
import '../models/customer_model.dart';
import '../widgets/document_card.dart';
import 'database_helper.dart';
import 'customer_repository.dart';

/// 売上リポジトリ
class SalesRepository {
  final DatabaseHelper _db = DatabaseHelper();
  final CustomerRepository _customerRepo = CustomerRepository();

  /// すべての売上を取得
  Future<List<Sales>> getAllSales() async {
    final database = await _db.database;
    final customers = await _customerRepo.getAllCustomers();
    
    final maps = await database.query(
      'sales',
      orderBy: 'date DESC',
    );

    return maps.map((map) {
      final customerId = map['customer_id'] as String?;
      final customer = customerId != null
          ? customers.firstWhere(
              (c) => c.id == customerId,
              orElse: () => Customer(
                id: customerId,
                displayName: '不明な顧客',
                formalName: '不明な顧客',
              ),
            )
          : null;

      return Sales.fromMap(map, customer);
    }).toList();
  }

  /// IDで売上を取得
  Future<Sales?> getSales(String id) async {
    final database = await _db.database;
    final customers = await _customerRepo.getAllCustomers();
    
    final maps = await database.query(
      'sales',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    
    final map = maps.first;
    final customerId = map['customer_id'] as String?;
    final customer = customerId != null
        ? customers.firstWhere(
            (c) => c.id == customerId,
            orElse: () => Customer(
              id: customerId,
              displayName: '不明な顧客',
              formalName: '不明な顧客',
            ),
          )
        : null;

    return Sales.fromMap(map, customer);
  }

  /// 売上を保存
  Future<void> saveSales(Sales sales) async {
    final database = await _db.database;
    await database.insert(
      'sales',
      sales.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // 明細を保存
    await database.delete(
      'sales_items',
      where: 'sales_id = ?',
      whereArgs: [sales.id],
    );

    for (final item in sales.items) {
      await database.insert(
        'sales_items',
        {
          ...item.toMap(),
          'sales_id': sales.id,
        },
      );
    }
  }

  /// 請求書IDに紐づく売上伝票を取得
  Future<List<Sales>> getSalesByInvoiceId(String invoiceId) async {
    final database = await _db.database;
    final customers = await _customerRepo.getAllCustomers();

    final maps = await database.query(
      'sales',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
      orderBy: 'date DESC',
    );

    return maps.map((map) {
      final customerId = map['customer_id'] as String?;
      final customer = customerId != null
          ? customers.firstWhere(
              (c) => c.id == customerId,
              orElse: () => Customer(
                id: customerId,
                displayName: '不明な顧客',
                formalName: '不明な顧客',
              ),
            )
          : null;
      return Sales.fromMap(map, customer);
    }).toList();
  }

  /// 売上を削除
  Future<void> deleteSales(String id) async {
    final database = await _db.database;
    await database.delete(
      'sales',
      where: 'id = ?',
      whereArgs: [id],
    );
    await database.delete(
      'sales_items',
      where: 'sales_id = ?',
      whereArgs: [id],
    );
  }

  /// 売上をコピー
  Future<Sales> copySales(Sales original) async {
    final newSales = original.copyWith(
      id: const Uuid().v4(),
      documentNumber: await _generateDocumentNumber(),
      date: DateTime.now(),
      status: DocumentStatus.draft,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await saveSales(newSales);
    return newSales;
  }

  /// 伝票番号を生成
  Future<String> _generateDocumentNumber() async {
    final database = await _db.database;
    final now = DateTime.now();
    final prefix = 'S${now.year}${now.month.toString().padLeft(2, '0')}';
    
    final result = await database.rawQuery(
      'SELECT COUNT(*) as count FROM sales WHERE document_number LIKE ?',
      ['$prefix%'],
    );
    
    final count = result.first['count'] as int;
    return '$prefix-${(count + 1).toString().padLeft(4, '0')}';
  }
}
