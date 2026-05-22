import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/invoice_models.dart';
import '../utils/theme_utils.dart';

class InvoiceListA2Card extends StatelessWidget {
  final Invoice invoice;
  final NumberFormat amountFormatter;
  final DateFormat dateFormatter;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String draftLabel;
  final bool showLockedBadge;
  final bool hasRedInvoice; // 元伝票に対する赤伝が発行済みか
  final bool q1Layout; // Q1: 日付左上・顧客名右上・コード非表示

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
    this.q1Layout = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDraft = invoice.isDraft;
    final isRed = invoice.isRedInvoice;
    final isCancelled = hasRedInvoice && !isRed; // 元伝票で赤伝済み

    final cardColor = isRed
        ? cs.errorContainer
        : (isCancelled ? cs.errorContainer.withValues(alpha: 0.55) : (isDraft ? cs.secondaryContainer : cs.surface));
    final borderColor = isRed || isCancelled ? cs.error : null;
    final iconColor = isRed ? cs.error : documentTypeBadgeColor(invoice.documentType);
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
    final subjectColor = invoice.isLocked ? cs.onSurfaceVariant : cs.primary;
    final amountColor = isRed ? cs.error : (invoice.isLocked ? cs.onSurfaceVariant : cs.onSurface);

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
                        child: Icon(Icons.lock, size: 14),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: q1Layout
                    ? _buildQ1Content(cs, isDraft, subjectDisplay, customerName, subjectColor, amountColor)
                    : _buildDefaultContent(cs, isDraft, isRed, isCancelled, subjectDisplay, customerName, subjectColor, amountColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQ1Content(ColorScheme cs, bool isDraft, String subjectDisplay, String customerName, Color subjectColor, Color amountColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(dateFormatter.format(invoice.date), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            const Spacer(),
            Text(customerName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: cs.onSurface)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(subjectDisplay.isNotEmpty ? subjectDisplay : '(明細なし)',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: subjectColor)),
            ),
            const SizedBox(width: 8),
            Text('￥${amountFormatter.format(invoice.totalAmount)}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: amountColor)),
          ],
        ),
        if (isDraft) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(4)),
            child: Text('下書き', style: TextStyle(fontSize: 9, color: cs.onSecondaryContainer)),
          ),
        ],
      ],
    );
  }

  Widget _buildDefaultContent(ColorScheme cs, bool isDraft, bool isRed, bool isCancelled, String subjectDisplay, String customerName, Color subjectColor, Color amountColor) {
    return Row(
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
                  color: invoice.isLocked ? cs.onSurfaceVariant : cs.onSurface,
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
                    color: isRed ? cs.onErrorContainer : subjectColor,
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
                    decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(10)),
                    child: Text('赤伝', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onErrorContainer)),
                  )
                else if (isCancelled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(10)),
                    child: Text('赤伝済', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onErrorContainer)),
                  )
                else if (isDraft)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(10)),
                    child: Text(draftLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSecondaryContainer)),
                  ),
                Text(invoice.invoiceNumber, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right),
              ],
            ),
            const SizedBox(height: 8),
            Text('￥${amountFormatter.format(invoice.totalAmount)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: amountColor), textAlign: TextAlign.right),
          ],
        ),
      ],
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

}
