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
    Key? key,
    required this.invoice,
    required this.isUnlocked,
    required this.amountFormatter,
    required this.dateFormatter,
    this.onTap,
    this.onLongPress,
    this.onEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: invoice.isDraft ? Colors.orange.shade50 : null,
      leading: CircleAvatar(
        backgroundColor: invoice.isDraft
            ? Colors.orange.shade100
            : (isUnlocked ? Colors.indigo.shade100 : Colors.grey.shade200),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: Icon(
                invoice.isDraft ? Icons.edit_note : Icons.description_outlined,
                color: invoice.isDraft
                    ? Colors.orange
                    : (isUnlocked ? Colors.indigo : Colors.grey),
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
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            invoice.customerNameForDisplay,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: invoice.isLocked ? Colors.grey : Colors.black87,
            ),
          ),
          if (invoice.subject?.isNotEmpty ?? false)
            Text(
              invoice.subject!,
              style: TextStyle(
                fontSize: 13,
                color: Colors.indigo.shade700,
                fontWeight: FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      subtitle: Text("${dateFormatter.format(invoice.date)} - ${invoice.invoiceNumber}"),
      trailing: SizedBox(
        height: 48,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "￥${amountFormatter.format(invoice.totalAmount)}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            if (invoice.isSynced)
              const Icon(Icons.sync, size: 14, color: Colors.green)
            else
              const Icon(Icons.sync_disabled, size: 14, color: Colors.orange),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 28, height: 24),
              icon: const Icon(Icons.edit, size: 16),
              tooltip: invoice.isLocked
                  ? "ロック中"
                  : (isUnlocked ? "編集" : "アンロックして編集"),
              onPressed: (invoice.isLocked || !isUnlocked)
                  ? null
                  : onEdit,
            ),
          ],
        ),
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}
