import 'package:flutter/material.dart';

/// 価格計算用テンキーパッド
class InvoiceCalculatorKeypad extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onUpdate;

  const InvoiceCalculatorKeypad({
    super.key,
    required this.controller,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final defaultBg = isDark ? theme.colorScheme.surfaceContainerHighest : theme.colorScheme.primaryContainer;
    final defaultFg = isDark ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onPrimaryContainer;
    final clearBg = isDark ? theme.colorScheme.errorContainer : Colors.red.shade100;
    final clearFg = isDark ? theme.colorScheme.onErrorContainer : Colors.red.shade900;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      childAspectRatio: 1.0,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: [
        for (final num in ['7', '8', '9', 'C'])
          ElevatedButton(
            onPressed: () {
              if (num == 'C') {
                controller.text = '';
              } else {
                controller.text += num;
              }
              onUpdate();
            },
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: num == 'C' ? clearBg : defaultBg,
              foregroundColor: num == 'C' ? clearFg : defaultFg,
            ),
            child: Text(
              num,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        for (final num in ['4', '5', '6', '00'])
          ElevatedButton(
            onPressed: () {
              controller.text += num;
              onUpdate();
            },
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: defaultBg,
              foregroundColor: defaultFg,
            ),
            child: Text(
              num,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        for (final num in ['1', '2', '3', '000'])
          ElevatedButton(
            onPressed: () {
              controller.text += num;
              onUpdate();
            },
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: defaultBg,
              foregroundColor: defaultFg,
            ),
            child: Text(
              num,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        for (final num in ['0', '0000'])
          ElevatedButton(
            onPressed: () {
              controller.text += num;
              onUpdate();
            },
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: defaultBg,
              foregroundColor: defaultFg,
            ),
            child: Text(
              num,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }
}
