import 'package:flutter/material.dart';

/// 電子帳簿保存法対応・赤伝起票ボタン
class InvoiceRedInvoiceButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String buttonLabel;

  const InvoiceRedInvoiceButton({
    super.key,
    required this.onPressed,
    required this.buttonLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0.5,
      color: isDark ? const Color(0xFF2C2C2C) : theme.colorScheme.surface,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.error.withOpacity(0.5), width: 1.5),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '電子帳簿保存法対応',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.undo, size: 22),
                label: Text(
                  buttonLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'ロック済みの伝票を取消す場合、電子帳簿保存法に基づき元伝票を保持したまま、全明細をマイナスにした赤伝を自動生成・ロックします。',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5) : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
