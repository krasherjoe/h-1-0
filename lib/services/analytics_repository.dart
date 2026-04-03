import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import '../models/analytics_metric_model.dart';
import '../models/analytics_summary_model.dart';
import 'database_helper.dart';

class AnalyticsRepository {
  AnalyticsRepository({DatabaseHelper? databaseHelper}) : _dbHelper = databaseHelper ?? DatabaseHelper();

  final DatabaseHelper _dbHelper;

  Future<AnalyticsSummary> fetchMonthlySummary(DateTime month) async {
    final database = await _dbHelper.database;
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    final metrics = <AnalyticsMetric>[];

    metrics.addAll(await _fetchSalesMetrics(database, start, end));
    metrics.addAll(await _fetchPurchaseMetrics(database, start, end));
    metrics.addAll(await _fetchInventoryMetrics(database, end));

    final formatter = DateFormat('yyyy年MM月');
    return AnalyticsSummary(
      generatedAt: DateTime.now(),
      periodLabel: formatter.format(start),
      metrics: metrics,
      notes: '対象期間: ${DateFormat('yyyy/MM/dd').format(start)} - ${DateFormat('yyyy/MM/dd').format(end)}',
    );
  }

  Future<List<AnalyticsMetric>> _fetchSalesMetrics(Database database, DateTime start, DateTime end) async {
    final results = await database.rawQuery(
      'SELECT SUM(total) as amount, COUNT(*) as count FROM sales WHERE date BETWEEN ? AND ?',
      [start.toIso8601String(), end.toIso8601String()],
    );
    final row = results.first;
    final amount = (row['amount'] as num?)?.toDouble() ?? 0;
    final count = (row['count'] as num?)?.toDouble() ?? 0;

    return [
      AnalyticsMetric(
        id: 'sales_total',
        type: MetricType.salesTotal,
        category: MetricCategory.sales,
        granularity: MetricGranularity.monthly,
        periodStart: start,
        periodEnd: end,
        value: amount,
      ),
      AnalyticsMetric(
        id: 'sales_count',
        type: MetricType.salesCount,
        category: MetricCategory.sales,
        granularity: MetricGranularity.monthly,
        periodStart: start,
        periodEnd: end,
        value: count,
        unitLabel: '件',
      ),
    ];
  }

  Future<List<AnalyticsMetric>> _fetchPurchaseMetrics(Database database, DateTime start, DateTime end) async {
    final results = await database.rawQuery(
      'SELECT SUM(total) as amount, COUNT(*) as count FROM purchases WHERE date BETWEEN ? AND ?',
      [start.toIso8601String(), end.toIso8601String()],
    );
    final row = results.first;
    final amount = (row['amount'] as num?)?.toDouble() ?? 0;
    final count = (row['count'] as num?)?.toDouble() ?? 0;

    return [
      AnalyticsMetric(
        id: 'purchase_total',
        type: MetricType.purchaseTotal,
        category: MetricCategory.purchasing,
        granularity: MetricGranularity.monthly,
        periodStart: start,
        periodEnd: end,
        value: amount,
      ),
      AnalyticsMetric(
        id: 'purchase_count',
        type: MetricType.purchaseCount,
        category: MetricCategory.purchasing,
        granularity: MetricGranularity.monthly,
        periodStart: start,
        periodEnd: end,
        value: count,
        unitLabel: '件',
      ),
    ];
  }

  Future<List<AnalyticsMetric>> _fetchInventoryMetrics(Database database, DateTime snapshot) async {
    final results = await database.rawQuery('SELECT SUM(quantity * unit_cost) as value FROM inventory');
    final value = (results.first['value'] as num?)?.toDouble() ?? 0;

    return [
      AnalyticsMetric(
        id: 'inventory_value',
        type: MetricType.inventoryValue,
        category: MetricCategory.inventory,
        granularity: MetricGranularity.monthly,
        periodStart: snapshot,
        periodEnd: snapshot,
        value: value,
      ),
    ];
  }
}
