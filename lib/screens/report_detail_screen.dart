import 'package:flutter/material.dart';
import '../models/analytics_summary_model.dart';
import '../models/analytics_metric_model.dart';

class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({
    super.key,
    required this.summary,
  });

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('A2:詳細レポート - ${summary.periodLabel}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(context),
            const SizedBox(height: 16),
            _buildMetricsTable(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '集計サマリ',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '対象期間: ${summary.periodLabel}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (summary.notes != null) ...[
              const SizedBox(height: 4),
              Text(
                summary.notes!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsTable(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '指標詳細',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Table(
              border: TableBorder.all(color: Colors.grey.shade300),
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1),
              },
              children: [
                const TableRow(
                  decoration: BoxDecoration(color: Colors.grey),
                  children: [
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('指標名', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('値', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('前回比', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('成長率', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                ...summary.metrics.map((metric) => TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(_getMetricTitle(metric.type)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(metric.formatValue(withSymbol: false)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(metric.previousValue?.toStringAsFixed(0) ?? '-'),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        metric.growthRate != null
                            ? '${(metric.growthRate! * 100).toStringAsFixed(1)}%'
                            : '-',
                      ),
                    ),
                  ],
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getMetricTitle(MetricType type) {
    switch (type) {
      case MetricType.salesTotal:
        return '売上合計';
      case MetricType.salesCount:
        return '売上件数';
      case MetricType.averageOrderValue:
        return '平均単価';
      case MetricType.purchaseTotal:
        return '仕入合計';
      case MetricType.purchaseCount:
        return '仕入件数';
      case MetricType.inventoryValue:
        return '在庫評価額';
      case MetricType.inventoryTurnover:
        return '在庫回転率';
      case MetricType.cashOnHand:
        return '現金残高';
      case MetricType.grossMargin:
        return '粗利益';
    }
  }
}
