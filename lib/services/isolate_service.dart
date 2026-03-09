import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';

/// マルチスレッド処理サービス
class IsolateService {
  static final IsolateService _instance = IsolateService._internal();
  factory IsolateService() => _instance;
  IsolateService._internal();
  
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  // 売上分析のバックグラウンド処理
  Future<SalesAnalysisResult> analyzeSalesInBackground({
    required DateTime startDate,
    required DateTime endDate,
    String? productId,
    String? clientId,
  }) async {
    final params = SalesAnalysisParams(
      startDate: startDate,
      endDate: endDate,
      productId: productId,
      clientId: clientId,
    );
    
    return await compute(_analyzeSalesIsolate, params);
  }
  
  // 在庫評価のバックグラウンド処理
  Future<InventoryValuationResult> evaluateInventoryInBackground({
    String? warehouseId,
    String? categoryId,
  }) async {
    final params = InventoryValuationParams(
      warehouseId: warehouseId,
      categoryId: categoryId,
    );
    
    return await compute(_evaluateInventoryIsolate, params);
  }
  
  // 粗利分析のバックグラウンド処理
  Future<ProfitAnalysisResult> analyzeProfitInBackground({
    required DateTime startDate,
    required DateTime endDate,
    String? productId,
    String? clientId,
  }) async {
    final params = ProfitAnalysisParams(
      startDate: startDate,
      endDate: endDate,
      productId: productId,
      clientId: clientId,
    );
    
    return await compute(_analyzeProfitIsolate, params);
  }
  
  // 大量データの一括処理
  Future<BulkProcessResult> processBulkDataInBackground({
    required String operation,
    required List<Map<String, dynamic>> data,
  }) async {
    final params = BulkProcessParams(
      operation: operation,
      data: data,
    );
    
    return await compute(_processBulkDataIsolate, params);
  }
  
  // リアルタイムグラフデータ生成
  Future<ChartDataResult> generateChartDataInBackground({
    required String chartType,
    required DateTime startDate,
    required DateTime endDate,
    Map<String, dynamic>? filters,
  }) async {
    final params = ChartDataParams(
      chartType: chartType,
      startDate: startDate,
      endDate: endDate,
      filters: filters,
    );
    
    return await compute(_generateChartDataIsolate, params);
  }
}

/// 売上分析パラメータ
class SalesAnalysisParams {
  final DateTime startDate;
  final DateTime endDate;
  final String? productId;
  final String? clientId;
  
  SalesAnalysisParams({
    required this.startDate,
    required this.endDate,
    this.productId,
    this.clientId,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'productId': productId,
      'clientId': clientId,
    };
  }
  
  factory SalesAnalysisParams.fromMap(Map<String, dynamic> map) {
    return SalesAnalysisParams(
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      productId: map['productId'],
      clientId: map['clientId'],
    );
  }
}

/// 売上分析結果
class SalesAnalysisResult {
  final double totalSales;
  final int totalOrders;
  final double averageOrderValue;
  final List<DailySalesData> dailyData;
  final List<ProductSalesData> topProducts;
  final List<ClientSalesData> topClients;
  final Map<String, double> monthlyData;
  final double growthRate;
  final DateTime processedAt;
  
  SalesAnalysisResult({
    required this.totalSales,
    required this.totalOrders,
    required this.averageOrderValue,
    required this.dailyData,
    required this.topProducts,
    required this.topClients,
    required this.monthlyData,
    required this.growthRate,
    required this.processedAt,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'totalSales': totalSales,
      'totalOrders': totalOrders,
      'averageOrderValue': averageOrderValue,
      'dailyData': dailyData.map((d) => d.toMap()).toList(),
      'topProducts': topProducts.map((p) => p.toMap()).toList(),
      'topClients': topClients.map((c) => c.toMap()).toList(),
      'monthlyData': monthlyData,
      'growthRate': growthRate,
      'processedAt': processedAt.toIso8601String(),
    };
  }
  
  factory SalesAnalysisResult.fromMap(Map<String, dynamic> map) {
    return SalesAnalysisResult(
      totalSales: map['totalSales'],
      totalOrders: map['totalOrders'],
      averageOrderValue: map['averageOrderValue'],
      dailyData: (map['dailyData'] as List).map((d) => DailySalesData.fromMap(d)).toList(),
      topProducts: (map['topProducts'] as List).map((p) => ProductSalesData.fromMap(p)).toList(),
      topClients: (map['topClients'] as List).map((c) => ClientSalesData.fromMap(c)).toList(),
      monthlyData: Map<String, double>.from(map['monthlyData']),
      growthRate: map['growthRate'],
      processedAt: DateTime.parse(map['processedAt']),
    );
  }
}

/// 日次売上データ
class DailySalesData {
  final DateTime date;
  final double sales;
  final int orders;
  
  DailySalesData({
    required this.date,
    required this.sales,
    required this.orders,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'sales': sales,
      'orders': orders,
    };
  }
  
  factory DailySalesData.fromMap(Map<String, dynamic> map) {
    return DailySalesData(
      date: DateTime.parse(map['date']),
      sales: map['sales'],
      orders: map['orders'],
    );
  }
}

/// 商品別売上データ
class ProductSalesData {
  final String productId;
  final String productName;
  final double totalSales;
  final int quantity;
  final double revenue;
  
  ProductSalesData({
    required this.productId,
    required this.productName,
    required this.totalSales,
    required this.quantity,
    required this.revenue,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'totalSales': totalSales,
      'quantity': quantity,
      'revenue': revenue,
    };
  }
  
  factory ProductSalesData.fromMap(Map<String, dynamic> map) {
    return ProductSalesData(
      productId: map['productId'],
      productName: map['productName'],
      totalSales: map['totalSales'],
      quantity: map['quantity'],
      revenue: map['revenue'],
    );
  }
}

/// 顧客別売上データ
class ClientSalesData {
  final String clientId;
  final String clientName;
  final double totalSales;
  final int orders;
  final double averageOrderValue;
  
  ClientSalesData({
    required this.clientId,
    required this.clientName,
    required this.totalSales,
    required this.orders,
    required this.averageOrderValue,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'clientName': clientName,
      'totalSales': totalSales,
      'orders': orders,
      'averageOrderValue': averageOrderValue,
    };
  }
  
  factory ClientSalesData.fromMap(Map<String, dynamic> map) {
    return ClientSalesData(
      clientId: map['clientId'],
      clientName: map['clientName'],
      totalSales: map['totalSales'],
      orders: map['orders'],
      averageOrderValue: map['averageOrderValue'],
    );
  }
}

/// 在庫評価パラメータ
class InventoryValuationParams {
  final String? warehouseId;
  final String? categoryId;
  
  InventoryValuationParams({
    this.warehouseId,
    this.categoryId,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'warehouseId': warehouseId,
      'categoryId': categoryId,
    };
  }
  
  factory InventoryValuationParams.fromMap(Map<String, dynamic> map) {
    return InventoryValuationParams(
      warehouseId: map['warehouseId'],
      categoryId: map['categoryId'],
    );
  }
}

/// 在庫評価結果
class InventoryValuationResult {
  final double totalValue;
  final int totalItems;
  final int totalProducts;
  final Map<String, double> warehouseValues;
  final Map<String, double> categoryValues;
  final List<InventoryItemData> topItems;
  final List<LowStockItemData> lowStockItems;
  final DateTime processedAt;
  
  InventoryValuationResult({
    required this.totalValue,
    required this.totalItems,
    required this.totalProducts,
    required this.warehouseValues,
    required this.categoryValues,
    required this.topItems,
    required this.lowStockItems,
    required this.processedAt,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'totalValue': totalValue,
      'totalItems': totalItems,
      'totalProducts': totalProducts,
      'warehouseValues': warehouseValues,
      'categoryValues': categoryValues,
      'topItems': topItems.map((i) => i.toMap()).toList(),
      'lowStockItems': lowStockItems.map((i) => i.toMap()).toList(),
      'processedAt': processedAt.toIso8601String(),
    };
  }
  
  factory InventoryValuationResult.fromMap(Map<String, dynamic> map) {
    return InventoryValuationResult(
      totalValue: map['totalValue'],
      totalItems: map['totalItems'],
      totalProducts: map['totalProducts'],
      warehouseValues: Map<String, double>.from(map['warehouseValues']),
      categoryValues: Map<String, double>.from(map['categoryValues']),
      topItems: (map['topItems'] as List).map((i) => InventoryItemData.fromMap(i)).toList(),
      lowStockItems: (map['lowStockItems'] as List).map((i) => LowStockItemData.fromMap(i)).toList(),
      processedAt: DateTime.parse(map['processedAt']),
    );
  }
}

/// 在庫アイテムデータ
class InventoryItemData {
  final String productId;
  final String productName;
  final int quantity;
  final double unitCost;
  final double totalValue;
  final String warehouseName;
  
  InventoryItemData({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitCost,
    required this.totalValue,
    required this.warehouseName,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unitCost': unitCost,
      'totalValue': totalValue,
      'warehouseName': warehouseName,
    };
  }
  
  factory InventoryItemData.fromMap(Map<String, dynamic> map) {
    return InventoryItemData(
      productId: map['productId'],
      productName: map['productName'],
      quantity: map['quantity'],
      unitCost: map['unitCost'],
      totalValue: map['totalValue'],
      warehouseName: map['warehouseName'],
    );
  }
}

/// 在庫不足アイテムデータ
class LowStockItemData {
  final String productId;
  final String productName;
  final int currentStock;
  final int minStock;
  final int shortage;
  final String warehouseName;
  
  LowStockItemData({
    required this.productId,
    required this.productName,
    required this.currentStock,
    required this.minStock,
    required this.shortage,
    required this.warehouseName,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'currentStock': currentStock,
      'minStock': minStock,
      'shortage': shortage,
      'warehouseName': warehouseName,
    };
  }
  
  factory LowStockItemData.fromMap(Map<String, dynamic> map) {
    return LowStockItemData(
      productId: map['productId'],
      productName: map['productName'],
      currentStock: map['currentStock'],
      minStock: map['minStock'],
      shortage: map['shortage'],
      warehouseName: map['warehouseName'],
    );
  }
}

/// 粗利分析パラメータ
class ProfitAnalysisParams {
  final DateTime startDate;
  final DateTime endDate;
  final String? productId;
  final String? clientId;
  
  ProfitAnalysisParams({
    required this.startDate,
    required this.endDate,
    this.productId,
    this.clientId,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'productId': productId,
      'clientId': clientId,
    };
  }
  
  factory ProfitAnalysisParams.fromMap(Map<String, dynamic> map) {
    return ProfitAnalysisParams(
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      productId: map['productId'],
      clientId: map['clientId'],
    );
  }
}

/// 粗利分析結果
class ProfitAnalysisResult {
  final double totalRevenue;
  final double totalCost;
  final double grossProfit;
  final double profitMargin;
  final List<DailyProfitData> dailyData;
  final List<ProductProfitData> topProducts;
  final Map<String, double> monthlyData;
  final DateTime processedAt;
  
  ProfitAnalysisResult({
    required this.totalRevenue,
    required this.totalCost,
    required this.grossProfit,
    required this.profitMargin,
    required this.dailyData,
    required this.topProducts,
    required this.monthlyData,
    required this.processedAt,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'totalRevenue': totalRevenue,
      'totalCost': totalCost,
      'grossProfit': grossProfit,
      'profitMargin': profitMargin,
      'dailyData': dailyData.map((d) => d.toMap()).toList(),
      'topProducts': topProducts.map((p) => p.toMap()).toList(),
      'monthlyData': monthlyData,
      'processedAt': processedAt.toIso8601String(),
    };
  }
  
  factory ProfitAnalysisResult.fromMap(Map<String, dynamic> map) {
    return ProfitAnalysisResult(
      totalRevenue: map['totalRevenue'],
      totalCost: map['totalCost'],
      grossProfit: map['grossProfit'],
      profitMargin: map['profitMargin'],
      dailyData: (map['dailyData'] as List).map((d) => DailyProfitData.fromMap(d)).toList(),
      topProducts: (map['topProducts'] as List).map((p) => ProductProfitData.fromMap(p)).toList(),
      monthlyData: Map<String, double>.from(map['monthlyData']),
      processedAt: DateTime.parse(map['processedAt']),
    );
  }
}

/// 日次粗利データ
class DailyProfitData {
  final DateTime date;
  final double revenue;
  final double cost;
  final double profit;
  final double margin;
  
  DailyProfitData({
    required this.date,
    required this.revenue,
    required this.cost,
    required this.profit,
    required this.margin,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'revenue': revenue,
      'cost': cost,
      'profit': profit,
      'margin': margin,
    };
  }
  
  factory DailyProfitData.fromMap(Map<String, dynamic> map) {
    return DailyProfitData(
      date: DateTime.parse(map['date']),
      revenue: map['revenue'],
      cost: map['cost'],
      profit: map['profit'],
      margin: map['margin'],
    );
  }
}

/// 商品別粗利データ
class ProductProfitData {
  final String productId;
  final String productName;
  final double revenue;
  final double cost;
  final double profit;
  final double margin;
  final int quantity;
  
  ProductProfitData({
    required this.productId,
    required this.productName,
    required this.revenue,
    required this.cost,
    required this.profit,
    required this.margin,
    required this.quantity,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'revenue': revenue,
      'cost': cost,
      'profit': profit,
      'margin': margin,
      'quantity': quantity,
    };
  }
  
  factory ProductProfitData.fromMap(Map<String, dynamic> map) {
    return ProductProfitData(
      productId: map['productId'],
      productName: map['productName'],
      revenue: map['revenue'],
      cost: map['cost'],
      profit: map['profit'],
      margin: map['margin'],
      quantity: map['quantity'],
    );
  }
}

/// 一括処理パラメータ
class BulkProcessParams {
  final String operation;
  final List<Map<String, dynamic>> data;
  
  BulkProcessParams({
    required this.operation,
    required this.data,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'operation': operation,
      'data': data,
    };
  }
  
  factory BulkProcessParams.fromMap(Map<String, dynamic> map) {
    return BulkProcessParams(
      operation: map['operation'],
      data: List<Map<String, dynamic>>.from(map['data']),
    );
  }
}

/// 一括処理結果
class BulkProcessResult {
  final int totalItems;
  final int successItems;
  final int failedItems;
  final List<String> errors;
  final Duration processingTime;
  final DateTime processedAt;
  
  BulkProcessResult({
    required this.totalItems,
    required this.successItems,
    required this.failedItems,
    required this.errors,
    required this.processingTime,
    required this.processedAt,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'totalItems': totalItems,
      'successItems': successItems,
      'failedItems': failedItems,
      'errors': errors,
      'processingTime': processingTime.inMilliseconds,
      'processedAt': processedAt.toIso8601String(),
    };
  }
  
  factory BulkProcessResult.fromMap(Map<String, dynamic> map) {
    return BulkProcessResult(
      totalItems: map['totalItems'],
      successItems: map['successItems'],
      failedItems: map['failedItems'],
      errors: List<String>.from(map['errors']),
      processingTime: Duration(milliseconds: map['processingTime']),
      processedAt: DateTime.parse(map['processedAt']),
    );
  }
}

/// グラフデータパラメータ
class ChartDataParams {
  final String chartType;
  final DateTime startDate;
  final DateTime endDate;
  final Map<String, dynamic>? filters;
  
  ChartDataParams({
    required this.chartType,
    required this.startDate,
    required this.endDate,
    this.filters,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'chartType': chartType,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'filters': filters,
    };
  }
  
  factory ChartDataParams.fromMap(Map<String, dynamic> map) {
    return ChartDataParams(
      chartType: map['chartType'],
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      filters: map['filters'],
    );
  }
}

/// グラフデータ結果
class ChartDataResult {
  final List<ChartDataPoint> dataPoints;
  final Map<String, dynamic> metadata;
  final DateTime processedAt;
  
  ChartDataResult({
    required this.dataPoints,
    required this.metadata,
    required this.processedAt,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'dataPoints': dataPoints.map((d) => d.toMap()).toList(),
      'metadata': metadata,
      'processedAt': processedAt.toIso8601String(),
    };
  }
  
  factory ChartDataResult.fromMap(Map<String, dynamic> map) {
    return ChartDataResult(
      dataPoints: (map['dataPoints'] as List).map((d) => ChartDataPoint.fromMap(d)).toList(),
      metadata: Map<String, dynamic>.from(map['metadata']),
      processedAt: DateTime.parse(map['processedAt']),
    );
  }
}

/// グラフデータポイント
class ChartDataPoint {
  final String label;
  final double value;
  final Map<String, dynamic>? additionalData;
  
  ChartDataPoint({
    required this.label,
    required this.value,
    this.additionalData,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'value': value,
      'additionalData': additionalData,
    };
  }
  
  factory ChartDataPoint.fromMap(Map<String, dynamic> map) {
    return ChartDataPoint(
      label: map['label'],
      value: map['value'],
      additionalData: map['additionalData'],
    );
  }
}

// Isolate処理関数（トップレベル関数である必要がある）
SalesAnalysisResult _analyzeSalesIsolate(SalesAnalysisParams params) {
  // ここで重い売上分析処理を実行
  // UIスレッドをブロックせずにバックグラウンドで処理
  
  final startDate = params.startDate;
  final endDate = params.endDate;
  
  // サンプル実装（実際にはデータベースアクセス）
  final dailyData = <DailySalesData>[];
  final topProducts = <ProductSalesData>[];
  final topClients = <ClientSalesData>[];
  final monthlyData = <String, double>{};
  
  // 日次データ生成
  var current = startDate;
  double totalSales = 0;
  int totalOrders = 0;
  
  while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
    final dailySales = (current.day * 1000.0) + (current.hour * 100.0);
    final dailyOrders = (current.day * 5) + 2;
    
    dailyData.add(DailySalesData(
      date: current,
      sales: dailySales,
      orders: dailyOrders,
    ));
    
    totalSales += dailySales;
    totalOrders += dailyOrders;
    
    // 月次データ
    final monthKey = DateFormat('yyyy-MM').format(current);
    monthlyData[monthKey] = (monthlyData[monthKey] ?? 0) + dailySales;
    
    current = current.add(const Duration(days: 1));
  }
  
  // トップ商品データ（サンプル）
  topProducts.addAll([
    ProductSalesData(
      productId: 'P001',
      productName: '商品A',
      totalSales: totalSales * 0.3,
      quantity: 100,
      revenue: totalSales * 0.3,
    ),
    ProductSalesData(
      productId: 'P002',
      productName: '商品B',
      totalSales: totalSales * 0.2,
      quantity: 80,
      revenue: totalSales * 0.2,
    ),
  ]);
  
  // トップ顧客データ（サンプル）
  topClients.addAll([
    ClientSalesData(
      clientId: 'C001',
      clientName: '顧客A',
      totalSales: totalSales * 0.4,
      orders: totalOrders ~/ 2,
      averageOrderValue: (totalSales * 0.4) / (totalOrders ~/ 2),
    ),
    ClientSalesData(
      clientId: 'C002',
      clientName: '顧客B',
      totalSales: totalSales * 0.3,
      orders: totalOrders ~/ 3,
      averageOrderValue: (totalSales * 0.3) / (totalOrders ~/ 3),
    ),
  ]);
  
  return SalesAnalysisResult(
    totalSales: totalSales,
    totalOrders: totalOrders,
    averageOrderValue: totalOrders > 0 ? totalSales / totalOrders : 0,
    dailyData: dailyData,
    topProducts: topProducts,
    topClients: topClients,
    monthlyData: monthlyData,
    growthRate: 15.5, // サンプル成長率
    processedAt: DateTime.now(),
  );
}

InventoryValuationResult _evaluateInventoryIsolate(InventoryValuationParams params) {
  // 在庫評価の重い処理を実行
  final warehouseValues = <String, double>{};
  final categoryValues = <String, double>{};
  final topItems = <InventoryItemData>[];
  final lowStockItems = <LowStockItemData>[];
  
  // サンプルデータ生成
  final items = List.generate(1000, (index) => InventoryItemData(
    productId: 'P${index.toString().padLeft(3, '0')}',
    productName: '商品${index + 1}',
    quantity: 100 + (index % 500),
    unitCost: 1000.0 + (index * 10),
    totalValue: (100 + (index % 500)) * (1000.0 + (index * 10)),
    warehouseName: '倉庫${(index % 3) + 1}',
  ));
  
  // 倉庫別集計
  for (final item in items) {
    warehouseValues[item.warehouseName] = (warehouseValues[item.warehouseName] ?? 0) + item.totalValue;
  }
  
  // カテゴリ別集計（サンプル）
  categoryValues['カテゴリA'] = items.take(300).fold(0.0, (sum, item) => sum + item.totalValue);
  categoryValues['カテゴリB'] = items.skip(300).take(400).fold(0.0, (sum, item) => sum + item.totalValue);
  categoryValues['カテゴリC'] = items.skip(700).fold(0.0, (sum, item) => sum + item.totalValue);
  
  // トップアイテム
  topItems.addAll(items.take(10));
  
  // 在庫不足アイテム
  lowStockItems.addAll(items.where((item) => item.quantity < 50).take(20).map((item) => LowStockItemData(
    productId: item.productId,
    productName: item.productName,
    currentStock: item.quantity,
    minStock: 50,
    shortage: 50 - item.quantity,
    warehouseName: item.warehouseName,
  )));
  
  final totalValue = items.fold(0.0, (sum, item) => sum + item.totalValue);
  final totalItems = items.fold(0, (sum, item) => sum + item.quantity);
  final totalProducts = items.length;
  
  return InventoryValuationResult(
    totalValue: totalValue,
    totalItems: totalItems,
    totalProducts: totalProducts,
    warehouseValues: warehouseValues,
    categoryValues: categoryValues,
    topItems: topItems,
    lowStockItems: lowStockItems,
    processedAt: DateTime.now(),
  );
}

ProfitAnalysisResult _analyzeProfitIsolate(ProfitAnalysisParams params) {
  // 粗利分析の重い処理を実行
  final dailyData = <DailyProfitData>[];
  final topProducts = <ProductProfitData>[];
  final monthlyData = <String, double>{};
  
  final startDate = params.startDate;
  final endDate = params.endDate;
  
  var current = startDate;
  double totalRevenue = 0;
  double totalCost = 0;
  
  while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
    final dailyRevenue = (current.day * 2000.0) + (current.hour * 200.0);
    final dailyCost = dailyRevenue * 0.7; // 70%が原価
    final dailyProfit = dailyRevenue - dailyCost;
    final dailyMargin = dailyRevenue > 0 ? (dailyProfit / dailyRevenue) * 100 : 0.0;
    
    dailyData.add(DailyProfitData(
      date: current,
      revenue: dailyRevenue,
      cost: dailyCost,
      profit: dailyProfit,
      margin: dailyMargin,
    ));
    
    totalRevenue += dailyRevenue;
    totalCost += dailyCost;
    
    // 月次データ
    final monthKey = DateFormat('yyyy-MM').format(current);
    monthlyData[monthKey] = (monthlyData[monthKey] ?? 0) + dailyProfit;
    
    current = current.add(const Duration(days: 1));
  }
  
  // トップ商品データ
  topProducts.addAll([
    ProductProfitData(
      productId: 'P001',
      productName: '商品A',
      revenue: totalRevenue * 0.3,
      cost: totalRevenue * 0.2,
      profit: totalRevenue * 0.1,
      margin: 33.3,
      quantity: 100,
    ),
    ProductProfitData(
      productId: 'P002',
      productName: '商品B',
      revenue: totalRevenue * 0.2,
      cost: totalRevenue * 0.15,
      profit: totalRevenue * 0.05,
      margin: 25.0,
      quantity: 80,
    ),
  ]);
  
  final grossProfit = totalRevenue - totalCost;
  final profitMargin = totalRevenue > 0 ? (grossProfit / totalRevenue) * 100 : 0;
  
  return ProfitAnalysisResult(
    totalRevenue: totalRevenue,
    totalCost: totalCost,
    grossProfit: grossProfit,
    profitMargin: profitMargin,
    dailyData: dailyData,
    topProducts: topProducts,
    monthlyData: monthlyData,
    processedAt: DateTime.now(),
  );
}

BulkProcessResult _processBulkDataIsolate(BulkProcessParams params) {
  // 一括処理の重い処理を実行
  final startTime = DateTime.now();
  final errors = <String>[];
  int successCount = 0;
  int failCount = 0;
  
  for (int i = 0; i < params.data.length; i++) {
    try {
      // 各データ項目の処理（サンプル）
      // Future.delayedの代わりに同期処理を使用
      int delay = 10; // ミリ秒
      
      if (i % 20 == 0) { // 5%の確率でエラー
        errors.add('Item ${i + 1}: 処理エラー');
        failCount++;
      } else {
        successCount++;
      }
    } catch (e) {
      errors.add('Item ${i + 1}: ${e.toString()}');
      failCount++;
    }
  }
  
  final processingTime = DateTime.now().difference(startTime);
  
  return BulkProcessResult(
    totalItems: params.data.length,
    successItems: successCount,
    failedItems: failCount,
    errors: errors,
    processingTime: processingTime,
    processedAt: DateTime.now(),
  );
}

ChartDataResult _generateChartDataIsolate(ChartDataParams params) {
  // グラフデータ生成の重い処理を実行
  final dataPoints = <ChartDataPoint>[];
  final metadata = <String, dynamic>{};
  
  final startDate = params.startDate;
  final endDate = params.endDate;
  
  switch (params.chartType) {
    case 'sales':
      var current = startDate;
      while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
        dataPoints.add(ChartDataPoint(
          label: DateFormat('MM/dd').format(current),
          value: (current.day * 1000.0) + (current.hour * 100.0),
        ));
        current = current.add(const Duration(days: 1));
      }
      metadata['type'] = 'sales';
      metadata['unit'] = '円';
      break;
      
    case 'profit':
      var current = startDate;
      while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
        final revenue = (current.day * 2000.0) + (current.hour * 200.0);
        final profit = revenue * 0.3; // 30%の利益率
        dataPoints.add(ChartDataPoint(
          label: DateFormat('MM/dd').format(current),
          value: profit,
        ));
        current = current.add(const Duration(days: 1));
      }
      metadata['type'] = 'profit';
      metadata['unit'] = '円';
      break;
      
    case 'inventory':
      // 在庫データ（サンプル）
      for (int i = 0; i < 30; i++) {
        dataPoints.add(ChartDataPoint(
          label: '商品${i + 1}',
          value: 100 + (i * 50),
        ));
      }
      metadata['type'] = 'inventory';
      metadata['unit'] = '個';
      break;
  }
  
  return ChartDataResult(
    dataPoints: dataPoints,
    metadata: metadata,
    processedAt: DateTime.now(),
  );
}
