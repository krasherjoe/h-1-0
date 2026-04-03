enum InvoiceListStyle {
  legacy,
  a2,
}

extension InvoiceListStyleStorage on InvoiceListStyle {
  String get storageValue => name;

  static InvoiceListStyle fromStorage(String? value) {
    if (value == null) return InvoiceListStyle.legacy;
    return InvoiceListStyle.values.firstWhere(
      (style) => style.storageValue == value,
      orElse: () => InvoiceListStyle.legacy,
    );
  }
}
