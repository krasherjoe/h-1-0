import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import '../models/sales_model.dart';
import '../models/customer_model.dart';
import '../models/base_document.dart';
import '../widgets/document_card.dart';
import 'database_helper.dart';
import 'customer_repository.dart';
import 'product_repository.dart';

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

    final List<Sales> result = [];
    for (final map in maps) {
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
      final sales = Sales.fromMap(map, customer);
      sales.items = await _loadSalesItems(sales.id);
      result.add(sales);
    }
    return result;
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

    final sales = Sales.fromMap(map, customer);
    sales.items = await _loadSalesItems(sales.id);
    return sales;
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

    final List<Sales> result = [];
    for (final map in maps) {
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
      final sales = Sales.fromMap(map, customer);
      sales.items = await _loadSalesItems(sales.id);
      result.add(sales);
    }
    return result;
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

  /// 売上の明細をロード
  Future<List<DocumentItem>> _loadSalesItems(String salesId) async {
    final database = await _db.database;
    final maps = await database.query(
      'sales_items',
      where: 'sales_id = ?',
      whereArgs: [salesId],
    );
    return maps.map((map) => DocumentItem.fromMap(map)).toList();
  }

  /// 粗利を計算（売上 - 仕入原価）
  Future<int> calculateGrossProfit(Sales sales) async {
    final productRepo = ProductRepository();
    int totalProfit = 0;
    
    for (final item in sales.items) {
      final product = await productRepo.getProduct(item.productId);
      if (product != null) {
        final cost = product.wholesalePrice * item.quantity;
        final revenue = item.subtotal;
        totalProfit += (revenue - cost);
      }
    }
    
    return totalProfit;
  }

  /// 粗利率を計算（パーセント）
  Future<double> calculateGrossMargin(Sales sales) async {
    if (sales.total == 0) return 0.0;
    final profit = await calculateGrossProfit(sales);
    return (profit / sales.total) * 100;
  }

  /// すべての売上を明細付きで取得（粗利計算用）
  Future<List<Sales>> getAllSalesWithItems() async {
    final database = await _db.database;
    final customers = await _customerRepo.getAllCustomers();
    final productRepo = ProductRepository();
    
    final maps = await database.query(
      'sales',
      orderBy: 'date DESC',
    );

    List<Sales> salesList = [];
    for (var map in maps) {
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

      final sales = Sales.fromMap(map, customer);
      sales.items = await _loadSalesItems(sales.id);
      
      int totalProfit = 0;
      for (final item in sales.items) {
        final product = await productRepo.getProduct(item.productId);
        if (product != null) {
          final cost = product.wholesalePrice * item.quantity;
          final revenue = item.subtotal;
          totalProfit += (revenue - cost);
        }
      }
      sales.grossProfit = totalProfit;

      salesList.add(sales);
    }

    return salesList;
  }
}
