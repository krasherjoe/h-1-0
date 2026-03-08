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
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomPaint(
        painter: _ChartPainter(metrics),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.metrics);

  final List<AnalyticsMetric> metrics;

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
          ..color = Colors.grey.shade300
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
      ..color = Colors.blue
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
        Paint()..color = Colors.blue,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
