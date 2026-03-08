import 'package:flutter/material.dart';
import '../models/analytics_metric_model.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.metric,
  });

  final AnalyticsMetric metric;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _getMetricTitle(),
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (metric.trend != MetricTrend.flat)
                  Icon(
                    _getTrendIcon(),
                    color: metric.trendColor,
                    size: 16,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              metric.formatValue(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (metric.delta != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatDelta(),
                style: TextStyle(
                  fontSize: 12,
                  color: metric.trendColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getMetricTitle() {
    switch (metric.type) {
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

  IconData _getTrendIcon() {
    switch (metric.trend) {
      case MetricTrend.up:
        return Icons.trending_up;
      case MetricTrend.down:
        return Icons.trending_down;
      case MetricTrend.flat:
        return Icons.trending_flat;
    }
  }

  String _formatDelta() {
    final delta = metric.delta!;
    final sign = delta >= 0 ? '+' : '';
    return '$sign${delta.toStringAsFixed(0)}';
  }
}
