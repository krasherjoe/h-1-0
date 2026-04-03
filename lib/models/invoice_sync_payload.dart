class InvoiceSyncSnapshot {
  InvoiceSyncSnapshot({
    required Map<String, dynamic> invoiceRow,
    required List<Map<String, dynamic>> items,
  })  : invoiceRow = Map<String, dynamic>.from(invoiceRow),
        items = items.map((item) => Map<String, dynamic>.from(item)).toList();

  final Map<String, dynamic> invoiceRow;
  final List<Map<String, dynamic>> items;

  String get recordId => (invoiceRow['id'] ?? '').toString();

  String get updatedAtIso {
    final value = invoiceRow['updated_at'];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return DateTime.now().toUtc().toIso8601String();
  }

  int get updatedAtMs {
    try {
      return DateTime.parse(updatedAtIso).millisecondsSinceEpoch;
    } catch (_) {
      return DateTime.now().millisecondsSinceEpoch;
    }
  }

  InvoiceSyncPayload toPayload() {
    return InvoiceSyncPayload(
      recordId: recordId,
      updatedAt: updatedAtIso,
      invoiceRow: invoiceRow,
      items: items,
      hash: invoiceRow['meta_hash']?.toString(),
    );
  }
}

class InvoiceSyncPayload {
  InvoiceSyncPayload({
    required this.recordId,
    required this.updatedAt,
    required Map<String, dynamic> invoiceRow,
    required List<Map<String, dynamic>> items,
    this.hash,
  })  : invoiceRow = Map<String, dynamic>.from(invoiceRow),
        items = items.map((item) => Map<String, dynamic>.from(item)).toList();

  final String recordId;
  final String updatedAt;
  final Map<String, dynamic> invoiceRow;
  final List<Map<String, dynamic>> items;
  final String? hash;

  Map<String, dynamic> toJson() => {
        'recordId': recordId,
        'updatedAt': updatedAt,
        'invoice': invoiceRow,
        'items': items,
        if (hash != null) 'hash': hash,
      };

  factory InvoiceSyncPayload.fromJson(Map<String, dynamic> json) {
    return InvoiceSyncPayload(
      recordId: json['recordId'] as String,
      updatedAt: json['updatedAt'] as String,
      invoiceRow: (json['invoice'] as Map).cast<String, dynamic>(),
      items: (json['items'] as List)
          .map((item) => (item as Map).cast<String, dynamic>())
          .toList(),
      hash: json['hash'] as String?,
    );
  }
}
