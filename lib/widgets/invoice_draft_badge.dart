import 'package:flutter/material.dart';

/// 下書きバッジ
class InvoiceDraftBadge extends StatelessWidget {
  const InvoiceDraftBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.tertiaryContainer : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '下書き',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDark ? theme.colorScheme.onTertiaryContainer : Colors.orange,
        ),
      ),
    );
  }
}
