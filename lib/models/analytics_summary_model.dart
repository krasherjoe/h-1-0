import 'package:flutter/material.dart';
import 'analytics_metric_model.dart';

/// ダッシュボードで表示する集計サマリ
class AnalyticsSummary {
  const AnalyticsSummary({
    required this.generatedAt,
    required this.periodLabel,
    required this.metrics,
    this.notes,
    this.themeColor,
  });

  /// サマリ生成日時
  final DateTime generatedAt;

  /// サマリ対象期間のラベル（例: 2026年3月, 2026-03-01〜03-31）
  final String periodLabel;

  /// 表示する指標群
  final List<AnalyticsMetric> metrics;

  /// 注釈やコメント
  final String? notes;

  /// ダッシュボードで使用するテーマカラー（任意）
  final Color? themeColor;

  /// 指定タイプの指標を取得
  AnalyticsMetric? metricOfType(MetricType type) {
    try {
      return metrics.firstWhere((metric) => metric.type == type);
    } catch (_) {
      return null;
    }
  }

  /// 指定カテゴリの指標リスト
  List<AnalyticsMetric> metricsByCategory(MetricCategory category) {
    return metrics.where((metric) => metric.category == category).toList();
  }

  /// 売上系のハイライト指標（存在すれば）
  AnalyticsMetric? get primarySalesMetric => metricOfType(MetricType.salesTotal);

  AnalyticsSummary copyWith({
    DateTime? generatedAt,
    String? periodLabel,
    List<AnalyticsMetric>? metrics,
    String? notes,
    Color? themeColor,
  }) {
    return AnalyticsSummary(
      generatedAt: generatedAt ?? this.generatedAt,
      periodLabel: periodLabel ?? this.periodLabel,
      metrics: metrics ?? this.metrics,
      notes: notes ?? this.notes,
      themeColor: themeColor ?? this.themeColor,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'generated_at': generatedAt.toIso8601String(),
      'period_label': periodLabel,
      'notes': notes,
      'theme_color': themeColor?.value,
      'metrics': metrics.map((metric) => metric.toMap()).toList(),
    };
  }

  factory AnalyticsSummary.fromMap(Map<String, dynamic> map) {
    return AnalyticsSummary(
      generatedAt: DateTime.parse(map['generated_at'] as String),
      periodLabel: map['period_label'] as String,
      notes: map['notes'] as String?,
      themeColor: map['theme_color'] != null ? Color(map['theme_color'] as int) : null,
      metrics: (map['metrics'] as List<dynamic>)
          .map((entry) => AnalyticsMetric.fromMap(entry as Map<String, dynamic>))
          .toList(),
    );
  }
}
