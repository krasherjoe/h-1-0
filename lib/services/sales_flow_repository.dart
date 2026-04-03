import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/sales_flow_models.dart';
import 'database_helper.dart';

/// 販売フローリポジトリ
class SalesFlowRepository {
  static final SalesFlowRepository _instance = SalesFlowRepository._internal();
  factory SalesFlowRepository() => _instance;
  SalesFlowRepository._internal();
  
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();
  
  // 各種ドキュメント取得
  Future<List<Map<String, dynamic>>> getQuotes({SalesFlowStatus? status}) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'quotes',
      where: status != null ? 'status = ?' : null,
      whereArgs: status != null ? [status.toString()] : null,
      orderBy: 'updated_at DESC',
    );
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }
  
  Future<List<Map<String, dynamic>>> getOrders({SalesFlowStatus? status}) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'orders',
      where: status != null ? 'status = ?' : null,
      whereArgs: status != null ? [status.toString()] : null,
      orderBy: 'updated_at DESC',
    );
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }
  
  Future<List<Map<String, dynamic>>> getSales({SalesFlowStatus? status}) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'sales',
      where: status != null ? 'status = ?' : null,
      whereArgs: status != null ? [status.toString()] : null,
      orderBy: 'updated_at DESC',
    );
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }
  
  Future<List<Map<String, dynamic>>> getDeliveries({DeliveryLinkStatus? status}) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'deliveries',
      where: status != null ? 'status = ?' : null,
      whereArgs: status != null ? [status.toString()] : null,
      orderBy: 'updated_at DESC',
    );
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }
  
  Future<List<Map<String, dynamic>>> getInvoices({InvoiceLinkStatus? status}) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'invoices',
      where: status != null ? 'status = ?' : null,
      whereArgs: status != null ? [status.toString()] : null,
      orderBy: 'updated_at DESC',
    );
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }
  
  // 見積から受注への状態遷移
  Future<String> convertQuoteToOrder({
    required String quoteId,
    required String userId,
    String? notes,
  }) async {
    final db = await _dbHelper.database;
    
    // トランザクション開始
    return await db.transaction((txn) async {
      // 見積情報取得
      final quoteResult = await txn.query(
        'quotes',
        where: 'id = ?',
        whereArgs: [quoteId],
      );
      
      if (quoteResult.isEmpty) {
        throw Exception('見積が見つかりません');
      }
      
      final quote = quoteResult.first;
      
      // 見積アイテム取得
      final quoteItems = await txn.query(
        'quote_items',
        where: 'quote_id = ?',
        whereArgs: [quoteId],
      );
      
      // 受注データ作成
      final orderId = _uuid.v4();
      final orderNo = 'ORD-${DateTime.now().year}-${(orderId.substring(0, 8)).toUpperCase()}';
      
      await txn.insert('orders', {
        'id': orderId,
        'order_no': orderNo,
        'client_id': quote['client_id'],
        'client_name': quote['client_name'],
        'title': quote['title'],
        'subtotal': quote['subtotal'],
        'tax': quote['tax'],
        'total': quote['total'],
        'status': SalesFlowStatus.orderConfirmed.toString(),
        'notes': notes,
        'quote_id': quoteId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'created_by': userId,
      });
      
      // 受注アイテム作成
      for (final item in quoteItems) {
        await txn.insert('order_items', {
          'id': _uuid.v4(),
          'order_id': orderId,
          'product_id': item['product_id'],
          'product_name': item['product_name'],
          'quantity': item['quantity'],
          'unit_price': item['unit_price'],
          'subtotal': item['subtotal'],
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      
      // 見積状態更新
      await txn.update(
        'quotes',
        {
          'status': SalesFlowStatus.quoteApproved.toString(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [quoteId],
      );
      
      // 在庫引当処理
      await _allocateStock(txn, orderId, userId);
      
      return orderId;
    });
  }
  
  // 受注から売上への状態遷移
  Future<String> convertOrderToSales({
    required String orderId,
    required String userId,
    String? notes,
  }) async {
    final db = await _dbHelper.database;
    
    return await db.transaction((txn) async {
      // 受注情報取得
      final orderResult = await txn.query(
        'orders',
        where: 'id = ?',
        whereArgs: [orderId],
      );
      
      if (orderResult.isEmpty) {
        throw Exception('受注が見つかりません');
      }
      
      final order = orderResult.first;
      
      // 受注アイテム取得
      final orderItems = await txn.query(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [orderId],
      );
      
      // 売上データ作成
      final salesId = _uuid.v4();
      final salesNo = 'SLS-${DateTime.now().year}-${(salesId.substring(0, 8)).toUpperCase()}';
      
      await txn.insert('sales', {
        'id': salesId,
        'sales_no': salesNo,
        'client_id': order['client_id'],
        'client_name': order['client_name'],
        'title': order['title'],
        'subtotal': order['subtotal'],
        'tax': order['tax'],
        'total': order['total'],
        'status': SalesFlowStatus.salesConfirmed.toString(),
        'notes': notes,
        'order_id': orderId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'created_by': userId,
      });
      
      // 売上アイテム作成
      for (final item in orderItems) {
        await txn.insert('sales_items', {
          'id': _uuid.v4(),
          'sales_id': salesId,
          'product_id': item['product_id'],
          'product_name': item['product_name'],
          'quantity': item['quantity'],
          'unit_price': item['unit_price'],
          'subtotal': item['subtotal'],
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      
      // 受注状態更新
      await txn.update(
        'orders',
        {
          'status': SalesFlowStatus.salesConfirmed.toString(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );
      
      // 配送連携処理
      await _createDeliveryLink(txn, salesId, userId);
      
      // 請求連携処理
      await _createInvoiceLink(txn, salesId, userId);
      
      return salesId;
    });
  }
  
  // 在庫引当処理
  Future<void> _allocateStock(Transaction txn, String orderId, String userId) async {
    // 受注アイテム取得
    final orderItems = await txn.query(
      'order_items',
      where: 'order_id = ?',
      whereArgs: [orderId],
    );
    
    for (final item in orderItems) {
      final productId = item['product_id'] as String;
      final requiredQuantity = item['quantity'] as int;
      
      // 在庫確認
      final stockResult = await txn.rawQuery('''
        SELECT SUM(quantity) as total_quantity 
        FROM warehouse_stock 
        WHERE product_id = ? AND quantity > 0
      ''', [productId]);
      
      final availableQuantity = (stockResult.first['total_quantity'] as int?) ?? 0;
      
      if (availableQuantity >= requiredQuantity) {
        // 在庫引当実行
        int remainingQuantity = requiredQuantity;
        
        // 倉庫ごとに在庫を引当
        final warehouseStocks = await txn.query(
          'warehouse_stock',
          where: 'product_id = ? AND quantity > 0',
          whereArgs: [productId],
          orderBy: 'updated_at ASC', // 古い在庫から引当
        );
        
        for (final stock in warehouseStocks) {
          if (remainingQuantity <= 0) break;
          
          final warehouseId = stock['warehouse_id'] as String;
          final availableStock = stock['quantity'] as int;
          final allocateQuantity = availableStock > remainingQuantity 
              ? remainingQuantity 
              : availableStock;
          
          // 在庫引当記録
          await txn.insert('stock_allocations', {
            'id': _uuid.v4(),
            'order_id': orderId,
            'product_id': productId,
            'warehouse_id': warehouseId,
            'allocated_quantity': allocateQuantity,
            'status': StockAllocationStatus.allocated.toString(),
            'created_at': DateTime.now().toIso8601String(),
            'created_by': userId,
          });
          
          // 在庫数量更新
          await txn.update(
            'warehouse_stock',
            {'quantity': availableStock - allocateQuantity, 'updated_at': DateTime.now().toIso8601String()},
            where: 'product_id = ? AND warehouse_id = ?',
            whereArgs: [productId, warehouseId],
          );
          
          remainingQuantity -= allocateQuantity;
        }
      } else {
        // 在庫不足の場合
        await txn.insert('stock_allocations', {
          'id': _uuid.v4(),
          'order_id': orderId,
          'product_id': productId,
          'warehouse_id': '',
          'allocated_quantity': 0,
          'required_quantity': requiredQuantity,
          'available_quantity': availableQuantity,
          'status': StockAllocationStatus.notAllocated.toString(),
          'notes': '在庫不足',
          'created_at': DateTime.now().toIso8601String(),
          'created_by': userId,
        });
      }
    }
  }
  
  // 配送連携処理
  Future<void> _createDeliveryLink(Transaction txn, String salesId, String userId) async {
    final deliveryId = _uuid.v4();
    final deliveryNo = 'DEL-${DateTime.now().year}-${(deliveryId.substring(0, 8)).toUpperCase()}';
    
    await txn.insert('deliveries', {
      'id': deliveryId,
      'delivery_no': deliveryNo,
      'sales_id': salesId,
      'status': DeliveryLinkStatus.linked.toString(),
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'created_by': userId,
    });
    
    // 売上状態更新
    await txn.update(
      'sales',
      {
        'delivery_id': deliveryId,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [salesId],
    );
  }
  
  // 請求連携処理
  Future<void> _createInvoiceLink(Transaction txn, String salesId, String userId) async {
    final invoiceId = _uuid.v4();
    final invoiceNo = 'INV-${DateTime.now().year}-${(invoiceId.substring(0, 8)).toUpperCase()}';
    
    // 売上情報取得
    final salesResult = await txn.query(
      'sales',
      where: 'id = ?',
      whereArgs: [salesId],
    );
    
    if (salesResult.isEmpty) return;
    
    final sales = salesResult.first;
    
    await txn.insert('invoices', {
      'id': invoiceId,
      'invoice_no': invoiceNo,
      'client_id': sales['client_id'],
      'client_name': sales['client_name'],
      'title': sales['title'],
      'subtotal': sales['subtotal'],
      'tax': sales['tax'],
      'total': sales['total'],
      'status': InvoiceLinkStatus.linked.toString(),
      'sales_id': salesId,
      'due_date': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'created_by': userId,
    });
    
    // 売上状態更新
    await txn.update(
      'sales',
      {
        'invoice_id': invoiceId,
        'status': SalesFlowStatus.salesInvoiced.toString(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [salesId],
    );
  }
  
  // 状態遷移の実行
  Future<void> updateStatus({
    required String documentId,
    required String documentType, // 'quote', 'order', 'sales', 'delivery', 'invoice'
    required SalesFlowStatus newStatus,
    required String userId,
    String? notes,
  }) async {
    final db = await _dbHelper.database;
    
    String tableName;
    switch (documentType) {
      case 'quote':
        tableName = 'quotes';
        break;
      case 'order':
        tableName = 'orders';
        break;
      case 'sales':
        tableName = 'sales';
        break;
      case 'delivery':
        tableName = 'deliveries';
        break;
      case 'invoice':
        tableName = 'invoices';
        break;
      default:
        throw Exception('無効なドキュメントタイプ: $documentType');
    }
    
    await db.update(
      tableName,
      {
        'status': newStatus.toString(),
        'notes': notes,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [documentId],
    );
    
    // 操作ログ記録
    await _logStatusChange(documentId, documentType, newStatus, userId);
  }
  
  // 状態変更ログ記録
  Future<void> _logStatusChange(
    String documentId,
    String documentType,
    SalesFlowStatus newStatus,
    String userId,
  ) async {
    final db = await _dbHelper.database;
    
    await db.insert('flow_status_logs', {
      'id': _uuid.v4(),
      'document_id': documentId,
      'document_type': documentType,
      'status': newStatus.toString(),
      'user_id': userId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
  
  // フロー状況取得
  Future<Map<String, dynamic>> getFlowStatus(String documentId) async {
    final db = await _dbHelper.database;
    
    // 各テーブルから関連情報取得
    final quote = await db.query('quotes', where: 'id = ?', whereArgs: [documentId]);
    final order = await db.query('orders', where: 'id = ?', whereArgs: [documentId]);
    final sales = await db.query('sales', where: 'id = ?', whereArgs: [documentId]);
    final delivery = await db.query('deliveries', where: 'id = ?', whereArgs: [documentId]);
    final invoice = await db.query('invoices', where: 'id = ?', whereArgs: [documentId]);
    
    // 在庫引当状況
    final allocations = await db.query(
      'stock_allocations',
      where: 'order_id = ? OR sales_id = ?',
      whereArgs: [documentId, documentId],
    );
    
    // 状態変更ログ
    final statusLogs = await db.query(
      'flow_status_logs',
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'created_at DESC',
    );
    
    return {
      'quote': quote.isNotEmpty ? quote.first : null,
      'order': order.isNotEmpty ? order.first : null,
      'sales': sales.isNotEmpty ? sales.first : null,
      'delivery': delivery.isNotEmpty ? delivery.first : null,
      'invoice': invoice.isNotEmpty ? invoice.first : null,
      'allocations': allocations,
      'statusLogs': statusLogs,
    };
  }
  
  // 在庫引当解除
  Future<void> releaseStockAllocation({
    required String allocationId,
    required String userId,
    String? reason,
  }) async {
    final db = await _dbHelper.database;
    
    await db.transaction((txn) async {
      // 引当情報取得
      final allocation = await txn.query(
        'stock_allocations',
        where: 'id = ?',
        whereArgs: [allocationId],
      );
      
      if (allocation.isEmpty) {
        throw Exception('在庫引当が見つかりません');
      }
      
      final alloc = allocation.first;
      final productId = alloc['product_id'] as String;
      final warehouseId = alloc['warehouse_id'] as String;
      final allocatedQuantity = alloc['allocated_quantity'] as int;
      
      // 在庫数量戻し
      await txn.rawUpdate('''
        UPDATE warehouse_stock 
        SET quantity = quantity + ?, updated_at = ?
        WHERE product_id = ? AND warehouse_id = ?
      ''', [allocatedQuantity, DateTime.now().toIso8601String(), productId, warehouseId]);
      
      // 引当状態更新
      await txn.update(
        'stock_allocations',
        {
          'status': StockAllocationStatus.released.toString(),
          'notes': reason,
          'released_at': DateTime.now().toIso8601String(),
          'released_by': userId,
        },
        where: 'id = ?',
        whereArgs: [allocationId],
      );
    });
  }
  
  // 配送状況更新
  Future<void> updateDeliveryStatus({
    required String deliveryId,
    required DeliveryLinkStatus status,
    required String userId,
    String? notes,
    DateTime? deliveredAt,
  }) async {
    final db = await _dbHelper.database;
    
    await db.update(
      'deliveries',
      {
        'status': status.toString(),
        'notes': notes,
        'delivered_at': deliveredAt?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [deliveryId],
    );
    
    // 関連売上の状態更新
    if (status == DeliveryLinkStatus.completed) {
      await db.update(
        'sales',
        {'status': SalesFlowStatus.salesPaid.toString(), 'updated_at': DateTime.now().toIso8601String()},
        where: 'delivery_id = ?',
        whereArgs: [deliveryId],
      );
    }
  }
  
  // 請求状況更新
  Future<void> updateInvoiceStatus({
    required String invoiceId,
    required InvoiceLinkStatus status,
    required String userId,
    String? notes,
    DateTime? paidAt,
  }) async {
    final db = await _dbHelper.database;
    
    await db.update(
      'invoices',
      {
        'status': status.toString(),
        'notes': notes,
        'paid_at': paidAt?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
    
    // 関連売上の状態更新
    if (status == InvoiceLinkStatus.paid) {
      await db.update(
        'sales',
        {'status': SalesFlowStatus.salesPaid.toString(), 'updated_at': DateTime.now().toIso8601String()},
        where: 'invoice_id = ?',
        whereArgs: [invoiceId],
      );
    }
  }
}
