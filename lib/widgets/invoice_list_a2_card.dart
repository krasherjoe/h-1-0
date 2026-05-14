import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/invoice_models.dart';

class InvoiceListA2Card extends StatelessWidget {
  final Invoice invoice;
  final NumberFormat amountFormatter;
  final DateFormat dateFormatter;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String draftLabel;
  final bool showLockedBadge;
  final bool hasRedInvoice; // 元伝票に対する赤伝が発行済みか

  const InvoiceListA2Card({
    super.key,
    required this.invoice,
    required this.amountFormatter,
    required this.dateFormatter,
    this.onTap,
    this.onLongPress,
    this.draftLabel = '下書き',
    this.showLockedBadge = true,
    this.hasRedInvoice = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDraft = invoice.isDraft;
    final isRed = invoice.isRedInvoice;
    final isCancelled = hasRedInvoice && !isRed; // 元伝票で赤伝済み

    final cardColor = isRed
        ? Colors.red.shade50
        : (isCancelled ? Colors.red.shade50.withValues(alpha: 0.55) : (isDraft ? Colors.orange.shade50 : Colors.white));
    final borderColor = isRed || isCancelled ? Colors.red.shade200 : null;
    final iconColor = isRed ? Colors.red : _docTypeColor(invoice.documentType);
    final iconBg = iconColor.withValues(alpha: 0.18);

    final hasSubject = invoice.subject?.isNotEmpty ?? false;
    final firstItemDesc = invoice.items.isNotEmpty ? invoice.items.first.description : '';
    final othersCount = invoice.items.length > 1 ? invoice.items.length - 1 : 0;
    final subjectLine = hasSubject ? invoice.subject! : firstItemDesc;
    final subjectDisplay = hasSubject
        ? subjectLine
        : (othersCount > 0 ? '$subjectLine 他$othersCount件' : subjectLine);
    final customerName = invoice.customerNameForDisplay.endsWith('様')
        ? invoice.customerNameForDisplay
        : '${invoice.customerNameForDisplay} 様';
    final subjectColor = invoice.isLocked ? Colors.grey.shade500 : Colors.indigo.shade700;
    final amountColor = isRed ? Colors.red : (invoice.isLocked ? Colors.grey.shade500 : Colors.black87);

    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: borderColor != null ? BorderSide(color: borderColor, width: 1.2) : BorderSide.none,
      ),
      elevation: isDraft ? 1.5 : 0.5,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                        isRed ? Icons.undo : _docTypeIcon(invoice.documentType),
                        color: iconColor,
                      ),
                    ),
                    if (invoice.isLocked && showLockedBadge)
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
                          if (subjectDisplay.isNotEmpty)
                            Text(
                              subjectDisplay,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isRed ? Colors.red.shade700 : subjectColor,
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
                            if (isRed)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  '赤伝',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.red,
                                  ),
                                ),
                              )
                            else if (isCancelled)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  '赤伝済',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.red,
                                  ),
                                ),
                              )
                            else if (isDraft)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  draftLabel,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                            Text(
                              dateFormatter.format(invoice.date),
                              style: const TextStyle(fontSize: 12, color: Colors.black87),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: Text(
                            invoice.invoiceNumber,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '￥${amountFormatter.format(invoice.totalAmount)}',
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
