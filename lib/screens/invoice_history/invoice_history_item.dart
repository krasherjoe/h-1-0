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
    final cardColor = invoice.isDraft ? Colors.orange.shade50 : Colors.white;
    final iconBg = isUnlocked
        ? _docTypeColor(invoice.documentType).withValues(alpha: 0.18)
        : Colors.grey.shade200;
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
    final subjectColor = invoice.isLocked ? Colors.grey.shade500 : Colors.indigo.shade700;
    final amountColor = invoice.isLocked ? Colors.grey.shade500 : Colors.black87;
    final dateColor = Colors.black87;

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
                        child: Icon(Icons.lock, size: 14, color: Colors.redAccent),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: invoice.isLocked ? Colors.grey : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subjectDisplay,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: subjectColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
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
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: Text(
                            invoice.invoiceNumber,
                            style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "￥${amountFormatter.format(invoice.totalAmount)}",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: amountColor),
                          textAlign: TextAlign.right,
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
