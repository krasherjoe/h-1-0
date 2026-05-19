import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/invoice_models.dart';
import 'invoice_history_item.dart';

class InvoiceHistoryList extends StatelessWidget {
  final List<Invoice> invoices;
  final bool isUnlocked;
  final NumberFormat amountFormatter;
  final DateFormat dateFormatter;
  final bool showInvoiceNumber;
  final void Function(Invoice) onTap;
  final void Function(Invoice) onLongPress;
  final void Function(Invoice) onEdit;

  const InvoiceHistoryList({
    super.key,
    required this.invoices,
    required this.isUnlocked,
    required this.amountFormatter,
    required this.dateFormatter,
    this.showInvoiceNumber = true,
    required this.onTap,
    required this.onLongPress,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Theme.of(context).colorScheme.outline),
            SizedBox(height: 16),
            Text("保存された伝票がありません"),
          ],
        ),
      );
    }

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 120), // 横揃えとFAB余白
      itemCount: invoices.length,
      itemBuilder: (context, index) {
        final invoice = invoices[index];
        return InvoiceHistoryItem(
          invoice: invoice,
          isUnlocked: isUnlocked,
          amountFormatter: amountFormatter,
          dateFormatter: dateFormatter,
          showInvoiceNumber: showInvoiceNumber,
          onTap: () => onTap(invoice),
          onLongPress: () => onLongPress(invoice),
          onEdit: () => onEdit(invoice),
        );
      },
    );
  }
}
