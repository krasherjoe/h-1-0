import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/invoice_models.dart';

class InvoiceHistoryItem extends StatelessWidget {
  final Invoice invoice;
  final bool isUnlocked;
  final NumberFormat amountFormatter;
  final DateFormat dateFormatter;
  final bool showInvoiceNumber;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onEdit;

  const InvoiceHistoryItem({
    super.key,
    required this.invoice,
    required this.isUnlocked,
    required this.amountFormatter,
    required this.dateFormatter,
    this.showInvoiceNumber = true,
    this.onTap,
    this.onLongPress,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final surfaceColor = cs.surface;
    final draftTint = cs.secondaryContainer.withValues(alpha: 0.25);
    final cardColor = invoice.isDraft ? draftTint : surfaceColor;
    final iconBg = isUnlocked
        ? _docTypeBgColor(invoice.documentType)
        : cs.surfaceContainerHighest;
    final iconColor = isUnlocked ? _docTypeColor(invoice.documentType) : cs.outline;
    final docLabel = _docTypeLabel(invoice.documentType);
    final docLabelColor = _docTypeColor(invoice.documentType);

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
        ? cs.outline
        : cs.primary;
    final amountColor = invoice.isLocked
        ? cs.outline
        : cs.onSurface;
    final dateColor = cs.onSurfaceVariant;

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
              Column(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: iconBg,
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: Icon(
                            _docTypeIcon(invoice.documentType),
                            color: iconColor,
                            size: 20,
                          ),
                        ),
                        if (invoice.isLocked)
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Icon(Icons.link, size: 12, color: Theme.of(context).colorScheme.error),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    docLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: docLabelColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          dateFormatter.format(invoice.date),
                          style: TextStyle(fontSize: 12, color: dateColor),
                        ),
                        if (invoice.isDraft)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(10),
                            ),
                  child: Text(
                               '下書き',
                               style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.secondary),
                             ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customerName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: invoice.isLocked ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showInvoiceNumber) ...[                      const SizedBox(height: 2),
                      Text(
                        invoice.invoiceNumber,
                          style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.outline),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
      case DocumentType.estimation: return Icons.request_quote;
      case DocumentType.order: return Icons.assignment;
      case DocumentType.delivery: return Icons.local_shipping;
      case DocumentType.invoice: return Icons.receipt_long;
      case DocumentType.receipt: return Icons.task_alt;
    }
  }

  String _docTypeLabel(DocumentType type) {
    switch (type) {
      case DocumentType.estimation: return '見積';
      case DocumentType.order: return '受注';
      case DocumentType.delivery: return '納品';
      case DocumentType.invoice: return '請求';
      case DocumentType.receipt: return '領収';
    }
  }

  Color _docTypeColor(DocumentType type) {
    switch (type) {
      case DocumentType.estimation: return const Color(0xFF1976D2);
      case DocumentType.order: return const Color(0xFF7B1FA2);
      case DocumentType.delivery: return const Color(0xFFF57C00);
      case DocumentType.invoice: return const Color(0xFFD32F2F);
      case DocumentType.receipt: return const Color(0xFF388E3C);
    }
  }

  Color _docTypeBgColor(DocumentType type) {
    switch (type) {
      case DocumentType.estimation: return const Color(0xFF1976D2).withValues(alpha: 0.12);
      case DocumentType.order: return const Color(0xFF7B1FA2).withValues(alpha: 0.12);
      case DocumentType.delivery: return const Color(0xFFF57C00).withValues(alpha: 0.12);
      case DocumentType.invoice: return const Color(0xFFD32F2F).withValues(alpha: 0.12);
      case DocumentType.receipt: return const Color(0xFF388E3C).withValues(alpha: 0.12);
    }
  }
}
