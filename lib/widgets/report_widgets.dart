import 'package:flutter/material.dart';
import 'dart:math' as math;

/// レポート共通ウィジェット
class ReportWidgets {
  /// レポートヘッダー
  static Widget buildHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    List<Widget>? actions,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ),
          if (actions != null) ...actions,
        ],
      ),
    );
  }

  /// サマリーカード
  static Widget buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 統計カード
  static Widget buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    double? percentage,
    String? trend,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                if (trend != null) ...[
                  const Spacer(),
                  Icon(
                    trend == 'up' ? Icons.trending_up : Icons.trending_down,
                    color: trend == 'up' ? Colors.green : Colors.red,
                    size: 16,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (percentage != null) ...[
              const SizedBox(height: 4),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12,
                  color: percentage > 0 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// チャートコンテナ
  static Widget buildChartContainer({
    required String title,
    required Widget chart,
    List<Widget>? actions,
    double? height,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (actions != null)
                  Row(mainAxisSize: MainAxisSize.min, children: actions),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(height: height ?? 300, child: chart),
          ],
        ),
      ),
    );
  }

  /// フィルターセクション
  static Widget buildFilterSection({required List<Widget> filters}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'フィルター',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: filters),
          ],
        ),
      ),
    );
  }

  /// データテーブルコンテナ
  static Widget buildTableContainer({
    required String title,
    required Widget table,
    List<Widget>? actions,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (actions != null)
                  Row(mainAxisSize: MainAxisSize.min, children: actions),
              ],
            ),
            const SizedBox(height: 16),
            table,
          ],
        ),
      ),
    );
  }

  /// 進捗バー
  static Widget buildProgressBar({
    required double progress,
    required Color color,
    String? label,
    double? height,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
        ],
        Container(
          height: height ?? 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Colors.grey.shade300,
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 比較カード
  static Widget buildComparisonCard({
    required String title,
    required String currentValue,
    required String previousValue,
    required IconData icon,
    required Color color,
  }) {
    final current =
        double.tryParse(currentValue.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    final previous =
        double.tryParse(previousValue.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    final change = current - previous;
    final changePercent = previous > 0 ? (change / previous * 100) : 0;
    final isPositive = change >= 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '現在',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      currentValue,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      '前期比',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Row(
                      children: [
                        Icon(
                          isPositive ? Icons.trending_up : Icons.trending_down,
                          color: isPositive ? Colors.green : Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${changePercent.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isPositive ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// タイムラインチャート
  static Widget buildTimelineChart({
    required List<Map<String, dynamic>> data,
    required String titleKey,
    required String valueKey,
    required Color color,
    double? height,
  }) {
    return Container(
      height: height ?? 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: data.length,
        itemBuilder: (context, index) {
          final item = data[index];
          final value = item[valueKey] as double;
          final maxValue = data.fold<double>(
            0,
            (max, item) => math.max(max, (item[valueKey] as double)),
          );
          final percentage = maxValue > 0 ? value / maxValue : 0;

          return Container(
            width: 60,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  height: 150 * (percentage as double),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item[titleKey] as String,
                  style: const TextStyle(fontSize: 12),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value.toStringAsFixed(0),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// レポート用の拡張メソッド
extension ReportExtensions on List<Map<String, dynamic>> {
  /// 合計値を計算
  double sum(String key) {
    return fold<double>(0, (sum, item) => sum + (item[key] as double? ?? 0));
  }

  /// 平均値を計算
  double average(String key) {
    if (isEmpty) return 0;
    return sum(key) / length;
  }

  /// 最大値を取得
  double max(String key) {
    if (isEmpty) return 0;
    return fold<double>(
      0,
      (max, item) => math.max(max, item[key] as double? ?? 0),
    );
  }

  /// 最小値を取得
  double min(String key) {
    if (isEmpty) return 0;
    return fold<double>(
      double.infinity,
      (min, item) => math.min(min, item[key] as double? ?? 0),
    );
  }

  /// 指定キーでソート
  List<Map<String, dynamic>> sortBy(String key, {bool descending = false}) {
    final sorted = List<Map<String, dynamic>>.from(this);
    sorted.sort((a, b) {
      final aValue = a[key] as Comparable;
      final bValue = b[key] as Comparable;
      return descending ? bValue.compareTo(aValue) : aValue.compareTo(bValue);
    });
    return sorted;
  }

  /// 指定条件でフィルタリング
  List<Map<String, dynamic>> where(
    bool Function(Map<String, dynamic>) condition,
  ) {
    return where(condition).toList();
  }

  /// 指定キーの値のリストを取得
  List<T> pluck<T>(String key) {
    return map((item) => item[key] as T).toList();
  }
}

/// レポート用の計算ユーティリティ
class ReportCalculations {
  /// 前期比を計算
  static double calculateGrowthRate(double current, double previous) {
    if (previous == 0) return 0;
    return ((current - previous) / previous) * 100;
  }

  /// 構成比率を計算
  static double calculatePercentage(double value, double total) {
    if (total == 0) return 0;
    return (value / total) * 100;
  }

  /// 移動平均を計算
  static List<double> calculateMovingAverage(List<double> values, int period) {
    if (values.length < period) return [];

    final averages = <double>[];
    for (int i = period - 1; i < values.length; i++) {
      final sum = values.sublist(i - period + 1, i + 1).reduce((a, b) => a + b);
      averages.add(sum / period);
    }
    return averages;
  }

  /// 季節変動を計算
  static Map<String, double> calculateSeasonalVariation(
    List<Map<String, dynamic>> data,
  ) {
    final seasonalData = <String, List<double>>{
      'Q1': [],
      'Q2': [],
      'Q3': [],
      'Q4': [],
    };

    for (final item in data) {
      final month = DateTime.parse(item['date'] as String).month;
      final quarter = ((month - 1) ~/ 3 + 1).toString();
      final value = item['value'] as double;

      seasonalData['Q$quarter']?.add(value);
    }

    final averages = <String, double>{};
    for (final entry in seasonalData.entries) {
      final values = entry.value;
      if (values.isNotEmpty) {
        averages[entry.key] = values.reduce((a, b) => a + b) / values.length;
      }
    }

    return averages;
  }

  /// 標準偏差を計算
  static double calculateStandardDeviation(List<double> values) {
    if (values.length < 2) return 0;

    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values
            .map((value) => math.pow(value - mean, 2))
            .reduce((a, b) => a + b) /
        values.length;

    return math.sqrt(variance);
  }

  /// トレンドラインを計算
  static Map<String, double> calculateTrendLine(
    List<Map<String, dynamic>> data,
  ) {
    if (data.length < 2) return {'slope': 0, 'intercept': 0};

    final n = data.length.toDouble();
    double sumX = 0;
    double sumY = 0;
    double sumXY = 0;
    double sumX2 = 0;

    for (int i = 0; i < data.length; i++) {
      final x = i.toDouble();
      final y = data[i]['value'] as double;
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumX2 += x * x;
    }

    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    final intercept = (sumY - slope * sumX) / n;

    return {'slope': slope, 'intercept': intercept};
  }
}
