import 'package:flutter/material.dart';

import '../models/invoice_list_style.dart';

class InvoiceListStyleTheme {
  final bool showStatusChip;
  final Color? draftCardColor;
  final Color? confirmedCardColor;
  final double draftElevation;
  final double confirmedElevation;
  final ShapeBorder? cardShape;

  const InvoiceListStyleTheme({
    required this.showStatusChip,
    required this.draftCardColor,
    required this.confirmedCardColor,
    required this.draftElevation,
    required this.confirmedElevation,
    required this.cardShape,
  });

  Color? cardColor(bool isDraft) => isDraft ? draftCardColor : confirmedCardColor;

  double cardElevation(bool isDraft) => isDraft ? draftElevation : confirmedElevation;
}

class InvoiceListStyleThemes {
  static InvoiceListStyleTheme resolve(InvoiceListStyle style) {
    switch (style) {
      case InvoiceListStyle.a2:
        return InvoiceListStyleTheme(
          showStatusChip: false,
          draftCardColor: Colors.orange.shade50,
          confirmedCardColor: Colors.white,
          draftElevation: 2,
          confirmedElevation: 0.5,
          cardShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        );
      case InvoiceListStyle.legacy:
      default:
        return const InvoiceListStyleTheme(
          showStatusChip: true,
          draftCardColor: null,
          confirmedCardColor: null,
          draftElevation: 1,
          confirmedElevation: 0.5,
          cardShape: null,
        );
    }
  }
}
