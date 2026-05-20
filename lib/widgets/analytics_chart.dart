import 'package:flutter/material.dart';
import '../models/analytics_metric_model.dart';

class AnalyticsChart extends StatelessWidget {
  const AnalyticsChart({
    super.key,
    required this.metrics,
    this.height = 200,
  });

  final List<AnalyticsMetric> metrics;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('データがありません')),
      );
    }

    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomPaint(
        painter: _ChartPainter(metrics, Theme.of(context).colorScheme),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.metrics, this.cs);

  final List<AnalyticsMetric> metrics;
  final ColorScheme cs;

  @override
  void paint(Canvas canvas, Size size) {
    if (metrics.isEmpty) return;

    final maxValue = metrics.map((m) => m.value).reduce((a, b) => a > b ? a : b);
    final padding = 40.0;
    final chartWidth = size.width - padding * 2;
    final chartHeight = size.height - padding * 2;

    // Draw grid lines
    final gridLines = 5;
    for (int i = 0; i <= gridLines; i++) {
      final y = padding + (chartHeight / gridLines) * i;
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        Paint()
          ..color = cs.outlineVariant
          ..strokeWidth = 1,
      );
    }

    // Draw line chart
    final points = <Offset>[];
    for (int i = 0; i < metrics.length; i++) {
      final metric = metrics[i];
      final x = padding + (chartWidth / (metrics.length - 1)) * i;
      final y = padding + chartHeight - (metric.value / maxValue) * chartHeight;
      points.add(Offset(x, y));
    }

    final paint = Paint()
      ..color = cs.primary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }

    // Draw dots
    for (final point in points) {
      canvas.drawCircle(
        point,
        4,
        Paint()..color = cs.primary,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
