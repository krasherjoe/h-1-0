import 'package:flutter/material.dart';

/// 分析指標カテゴリ
enum MetricCategory {
  sales,
  purchasing,
  inventory,
  finance,
  operations,
}

/// 指標の期間粒度
enum MetricGranularity {
  daily,
  weekly,
  monthly,
  quarterly,
  yearly,
}

/// 指標タイプ（必要に応じて拡張）
enum MetricType {
  salesTotal,
  salesCount,
  averageOrderValue,
  purchaseTotal,
  purchaseCount,
  inventoryValue,
  inventoryTurnover,
  cashOnHand,
  grossMargin,
}

/// トレンド方向
enum MetricTrend {
  up,
  down,
  flat,
}

/// 集計指標モデル
class AnalyticsMetric {
  AnalyticsMetric({
    required this.id,
    required this.type,
    required this.category,
    required this.granularity,
    required this.periodStart,
    required this.periodEnd,
    required this.value,
    this.previousValue,
    this.targetValue,
    this.unitLabel = '¥',
    this.isForecast = false,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final MetricType type;
  final MetricCategory category;
  final MetricGranularity granularity;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double value;
  final double? previousValue;
  final double? targetValue;
  final String unitLabel;
  final bool isForecast;
  final DateTime updatedAt;

  double? get delta => previousValue != null ? value - previousValue! : null;

  double? get growthRate {
    if (previousValue == null || previousValue == 0) return null;
    return (value - previousValue!) / previousValue!;
  }

  MetricTrend get trend {
    final diff = delta;
    if (diff == null) return MetricTrend.flat;
    if (diff.abs() < 0.0001) return MetricTrend.flat;
    return diff > 0 ? MetricTrend.up : MetricTrend.down;
  }

  Color getTrendColor(ColorScheme cs) {
    switch (trend) {
      case MetricTrend.up:
        return cs.tertiary;
      case MetricTrend.down:
        return cs.error;
      case MetricTrend.flat:
        return cs.onSurfaceVariant;
    }
  }

  String formatValue({bool withSymbol = true}) {
    final formatted = value.toStringAsFixed(0);
    if (!withSymbol) return formatted;
    return '$unitLabel$formatted';
  }

  AnalyticsMetric copyWith({
    String? id,
    MetricType? type,
    MetricCategory? category,
    MetricGranularity? granularity,
    DateTime? periodStart,
    DateTime? periodEnd,
    double? value,
    double? previousValue,
    double? targetValue,
    String? unitLabel,
    bool? isForecast,
    DateTime? updatedAt,
  }) {
    return AnalyticsMetric(
      id: id ?? this.id,
      type: type ?? this.type,
      category: category ?? this.category,
      granularity: granularity ?? this.granularity,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      value: value ?? this.value,
      previousValue: previousValue ?? this.previousValue,
      targetValue: targetValue ?? this.targetValue,
      unitLabel: unitLabel ?? this.unitLabel,
      isForecast: isForecast ?? this.isForecast,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'category': category.name,
      'granularity': granularity.name,
      'period_start': periodStart.toIso8601String(),
      'period_end': periodEnd.toIso8601String(),
      'value': value,
      'previous_value': previousValue,
      'target_value': targetValue,
      'unit_label': unitLabel,
      'is_forecast': isForecast ? 1 : 0,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AnalyticsMetric.fromMap(Map<String, dynamic> map) {
    return AnalyticsMetric(
      id: map['id'] as String,
      type: MetricType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => MetricType.salesTotal,
      ),
      category: MetricCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => MetricCategory.sales,
      ),
      granularity: MetricGranularity.values.firstWhere(
        (g) => g.name == map['granularity'],
        orElse: () => MetricGranularity.monthly,
      ),
      periodStart: DateTime.parse(map['period_start'] as String),
      periodEnd: DateTime.parse(map['period_end'] as String),
      value: (map['value'] as num).toDouble(),
      previousValue: (map['previous_value'] as num?)?.toDouble(),
      targetValue: (map['target_value'] as num?)?.toDouble(),
      unitLabel: map['unit_label'] as String? ?? '¥',
      isForecast: (map['is_forecast'] ?? 0) == 1,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
