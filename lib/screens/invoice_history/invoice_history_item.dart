import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/invoice_models.dart';

class InvoiceHistoryItem extends StatelessWidget {
  final Invoice invoice;
  final bool isUnlocked;
  final NumberFormat amountFormatter;
  final DateFormat dateFormatter;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onEdit;

  const InvoiceHistoryItem({
    super.key,
    required this.invoice,
    required this.isUnlocked,
    required this.amountFormatter,
    required this.dateFormatter,
    this.onTap,
    this.onLongPress,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final draftTint = isDark ? const Color(0xFF3D3020) : Colors.orange.shade50;
    final cardColor = invoice.isDraft ? draftTint : surfaceColor;
    final iconBg = isUnlocked
        ? _docTypeColor(invoice.documentType).withValues(alpha: 0.18)
        : (isDark ? Colors.grey.shade700 : Colors.grey.shade200);
    final iconColor = isUnlocked ? _docTypeColor(invoice.documentType) : Colors.grey;

    final hasSubject = invoice.subject?.isNotEmpty ?? false;
    final firstItemDesc = invoice.items.isNotEmpty ? invoice.items.first.description : '';
    final othersCount = invoice.items.length > 1 ? invoice.items.length - 1 : 0;
    final subjectLine = hasSubject ? invoice.subject! : firstItemDesc;
    final subjectDisplay = hasSubject
        ? subjectLine
        : (othersCount > 0 ? "$subjectLine 他$othersCount件" : subjectLine);
    final customerName = invoice.customerNameForDisplay.endsWith('様')
        ? invoice.customerNameForDisplay
        : '${invoice.customerNameForDisplay} 様';
    final subjectColor = invoice.isLocked
        ? (isDark ? Colors.grey.shade500 : Colors.grey.shade500)
        : (isDark ? Colors.indigo.shade300 : Colors.indigo.shade700);
    final amountColor = invoice.isLocked
        ? (isDark ? Colors.grey.shade500 : Colors.grey.shade500)
        : (isDark ? Colors.white : Colors.black87);
    final dateColor = isDark ? Colors.white70 : Colors.black87;

    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: invoice.isDraft ? 1.5 : 0.5,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: iconBg,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Icon(
                        _docTypeIcon(invoice.documentType),
                        color: iconColor,
                      ),
                    ),
                    if (invoice.isLocked)
                      const Align(
                        alignment: Alignment.bottomRight,
                        child: Icon(Icons.link, size: 14, color: Colors.redAccent),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (invoice.isDraft)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              '下書き',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.orange),
                            ),
                          ),
                        Text(
                          dateFormatter.format(invoice.date),
                          style: TextStyle(fontSize: 12, color: dateColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customerName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: invoice.isLocked ? Colors.grey : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      invoice.invoiceNumber,
                      style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subjectDisplay,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: subjectColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "￥${amountFormatter.format(invoice.totalAmount)}",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: amountColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _docTypeIcon(DocumentType type) {
    switch (type) {
      case DocumentType.estimation:
        return Icons.request_quote;
      case DocumentType.order:
        return Icons.assignment;
      case DocumentType.delivery:
        return Icons.local_shipping;
      case DocumentType.invoice:
        return Icons.receipt_long;
      case DocumentType.receipt:
        return Icons.task_alt;
    }
  }

  Color _docTypeColor(DocumentType type) {
    switch (type) {
      case DocumentType.estimation:
        return Colors.blue;
      case DocumentType.order:
        return Colors.orange;
      case DocumentType.delivery:
        return Colors.teal;
      case DocumentType.invoice:
        return Colors.indigo;
      case DocumentType.receipt:
        return Colors.green;
    }
  }
}
