import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/invoice_models.dart';
import 'invoice_history_item.dart';

class InvoiceHistoryList extends StatelessWidget {
  final List<Invoice> invoices;
  final bool isUnlocked;
  final NumberFormat amountFormatter;
  final DateFormat dateFormatter;
  final void Function(Invoice) onTap;
  final void Function(Invoice) onLongPress;
  final void Function(Invoice) onEdit;

  const InvoiceHistoryList({
    Key? key,
    required this.invoices,
    required this.isUnlocked,
    required this.amountFormatter,
    required this.dateFormatter,
    required this.onTap,
    required this.onLongPress,
    required this.onEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.folder_open, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text("保存された伝票がありません"),
          ],
        ),
      );
    }

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 120), // FAB分の固定余白
      itemCount: invoices.length,
      itemBuilder: (context, index) {
        final invoice = invoices[index];
        return InvoiceHistoryItem(
          invoice: invoice,
          isUnlocked: isUnlocked,
          amountFormatter: amountFormatter,
          dateFormatter: dateFormatter,
          onTap: () => onTap(invoice),
          onLongPress: () => onLongPress(invoice),
          onEdit: () => onEdit(invoice),
        );
      },
    );
  }
}
