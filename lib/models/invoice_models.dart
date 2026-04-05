import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'customer_model.dart';

class InvoiceItem {
  final String? id;
  final String? productId; // 追加
  String description;
  int quantity;
  int unitPrice;

  InvoiceItem({
    this.id,
    this.productId, // 追加
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });

  int get subtotal => quantity * unitPrice;

  Map<String, dynamic> toMap(String invoiceId) {
    return {
      'id': id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      'invoice_id': invoiceId,
      'product_id': productId, // 追加
      'description': description,
      'quantity': quantity,
      'unit_price': unitPrice,
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      id: map['id'],
      productId: map['product_id'], // 追加
      description: map['description'],
      quantity: map['quantity'],
      unitPrice: map['unit_price'],
    );
  }

  InvoiceItem copyWith({
    String? id, // Added this to be complete
    String? description,
    int? quantity,
    int? unitPrice,
    String? productId,
  }) {
    return InvoiceItem(
      id: id ?? this.id, // Added this to be complete
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      productId: productId ?? this.productId,
    );
  }
}

enum DocumentType {
  estimation, // 見積
  order, // 受注
  delivery, // 納品
  invoice, // 請求
  receipt, // 領収
}

enum OrderStatus { draft, confirmed, fulfilled }

extension OrderStatusLabel on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.draft:
        return '下書き';
      case OrderStatus.confirmed:
        return '確定';
      case OrderStatus.fulfilled:
        return '完了';
    }
  }
}

class Invoice {
  static const String lockStatement =
      '正式発行ボタン押下時にこの伝票はロックされ、以後の編集・削除はできません。ロック状態はハッシュチェーンで保護されます。';
  static const String hashDescription =
      'metaJson = JSON.stringify({id, invoiceNumber, customer, date, total, documentType, hash, lockStatement, companySnapshot, companySealHash}); metaHash = SHA-256(metaJson).';
  final String id;
  final Customer customer;
  final DateTime date;
  final List<InvoiceItem> items;
  final String? notes;
  final String? filePath;
  final double taxRate;
  final DocumentType documentType; // 追加
  final OrderStatus orderStatus;
  final DateTime? promisedDate;
  final DateTime? fulfilledDate;
  final String? sourceDocumentId;
  final String? linkedDeliveryId;
  final String? linkedInvoiceId;
  final String? customerFormalNameSnapshot;
  final String? odooId;
  final bool isSynced;
  final DateTime updatedAt;
  final double? latitude; // 追加
  final double? longitude; // 追加
  final String terminalId; // 追加: 端末識別子
  final bool isDraft; // 追加: 下書きフラグ
  final String? subject; // 追加: 案件名
  final bool isLocked; // 追加: ロック
  final int? contactVersionId; // 追加: 連絡先バージョン
  final String? contactEmailSnapshot;
  final String? contactTelSnapshot;
  final String? contactAddressSnapshot;
  final String? companySnapshot; // 追加: 発行時会社情報スナップショット
  final String? companySealHash; // 追加: 角印画像ハッシュ
  final String? metaJson;
  final String? metaHash;

  Invoice({
    String? id,
    required this.customer,
    required this.date,
    required this.items,
    this.notes,
    this.filePath,
    this.taxRate = 0.10,
    this.documentType = DocumentType.invoice, // デフォルト請求書
    this.orderStatus = OrderStatus.draft,
    this.promisedDate,
    this.fulfilledDate,
    this.sourceDocumentId,
    this.linkedDeliveryId,
    this.linkedInvoiceId,
    this.customerFormalNameSnapshot,
    this.odooId,
    this.isSynced = false,
    DateTime? updatedAt,
    this.latitude, // 追加
    this.longitude, // 追加
    String? terminalId, // 追加
    this.isDraft = false, // 追加: デフォルトは通常
    this.subject, // 追加: 案件
    this.isLocked = false,
    this.contactVersionId,
    this.contactEmailSnapshot,
    this.contactTelSnapshot,
    this.contactAddressSnapshot,
    this.companySnapshot,
    this.companySealHash,
    this.metaJson,
    this.metaHash,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       terminalId = terminalId ?? "T1", // デフォルト端末ID
       updatedAt = updatedAt ?? DateTime.now();

  /// 伝票内容から決定論的なハッシュを生成する (SHA256の一部)
  String get contentHash {
    final input =
        "$id|$terminalId|${date.toIso8601String()}|${customer.id}|$totalAmount|${subject ?? ""}|${items.map((e) => "${e.description}${e.quantity}${e.unitPrice}").join()}";
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString().substring(0, 8).toUpperCase();
  }

  String get documentTypeName {
    switch (documentType) {
      case DocumentType.estimation:
        return "見積書";
      case DocumentType.order:
        return "受注伝票";
      case DocumentType.delivery:
        return "納品書";
      case DocumentType.invoice:
        return "請求書";
      case DocumentType.receipt:
        return "領収書";
    }
  }

  static const Map<DocumentType, String> _docTypeShortLabel = {
    DocumentType.estimation: '見積',
    DocumentType.order: '受注',
    DocumentType.delivery: '納品',
    DocumentType.invoice: '請求',
    DocumentType.receipt: '領収',
  };

  String get invoiceNumberPrefix {
    switch (documentType) {
      case DocumentType.estimation:
        return "EST";
      case DocumentType.order:
        return "ORD";
      case DocumentType.delivery:
        return "DEL";
      case DocumentType.invoice:
        return "INV";
      case DocumentType.receipt:
        return "REC";
    }
  }

  bool get isOrder => documentType == DocumentType.order;
  bool get isOrderConfirmed => isOrder && orderStatus == OrderStatus.confirmed;

  String get invoiceNumber =>
      "$invoiceNumberPrefix-$terminalId-${DateFormat('yyyyMMdd').format(date)}-${id.substring(id.length > 4 ? id.length - 4 : 0)}";

  // 表示用の宛名（スナップショットがあれば優先）。必ず敬称を付与。
  String get customerNameForDisplay {
    final base = customerFormalNameSnapshot ?? customer.formalName;
    final hasHonorific = RegExp(r'(様|御中|殿)$').hasMatch(base);
    return hasHonorific ? base : '$base ${customer.title}';
  }

  int get subtotal => items.fold(0, (sum, item) => sum + item.subtotal);
  int get tax => (subtotal * taxRate).floor();
  int get totalAmount => subtotal + tax;

  String get _projectLabel {
    if (subject != null && subject!.trim().isNotEmpty) {
      return subject!.trim();
    }
    return '案件';
  }

  String get mailTitleCore {
    final dateStr = DateFormat('yyyyMMdd').format(date);
    final docLabel =
        _docTypeShortLabel[documentType] ??
        documentTypeName.replaceAll('書', '');
    final customerCompact = customerNameForDisplay.replaceAll(
      RegExp(r'\s+'),
      '',
    );
    final amountStr = NumberFormat('#,###').format(totalAmount);
    final buffer = StringBuffer()
      ..write(dateStr)
      ..write('($docLabel)')
      ..write(_projectLabel)
      ..write('@')
      ..write(customerCompact)
      ..write('_')
      ..write(amountStr)
      ..write('円');
    final raw = buffer.toString();
    return _sanitizeForFile(raw);
  }

  String get mailAttachmentFileName => '$mailTitleCore.PDF';

  String get mailBodyText => '請求書をお送りします。ご確認ください。';

  static String _sanitizeForFile(String input) {
    var sanitized = input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
    sanitized = sanitized.replaceAll(RegExp(r'[\r\n]+'), '');
    sanitized = sanitized.replaceAll('　', '');
    sanitized = sanitized.replaceAll(' ', '');
    return sanitized;
  }

  Map<String, dynamic> metaPayload() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'customer': customerNameForDisplay,
      'date': date.toIso8601String(),
      'total': totalAmount,
      'documentType': documentType.name,
      'hash': contentHash,
      'lockStatement': lockStatement,
      'hashDescription': hashDescription,
      'companySnapshot': companySnapshot,
      'companySealHash': companySealHash,
    };
  }

  String get metaJsonValue => metaJson ?? jsonEncode(metaPayload());

  String get metaHashValue =>
      metaHash ?? sha256.convert(utf8.encode(metaJsonValue)).toString();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customer.id,
      'date': date.toIso8601String(),
      'notes': notes,
      'file_path': filePath,
      'total_amount': totalAmount,
      'tax_rate': taxRate,
      'document_type': documentType.name, // 追加
      'order_status': orderStatus.name,
      'promised_date': promisedDate?.millisecondsSinceEpoch,
      'fulfilled_date': fulfilledDate?.millisecondsSinceEpoch,
      'source_document_id': sourceDocumentId,
      'linked_delivery_id': linkedDeliveryId,
      'linked_invoice_id': linkedInvoiceId,
      'customer_formal_name': customerFormalNameSnapshot ?? customer.formalName,
      'odoo_id': odooId,
      'is_synced': isSynced ? 1 : 0,
      'updated_at': updatedAt.toIso8601String(),
      'latitude': latitude, // 追加
      'longitude': longitude, // 追加
      'terminal_id': terminalId, // 追加
      'content_hash': contentHash, // 追加
      'is_draft': isDraft ? 1 : 0, // 追加
      'subject': subject, // 追加
      'is_locked': isLocked ? 1 : 0,
      'contact_version_id': contactVersionId,
      'contact_email_snapshot': contactEmailSnapshot,
      'contact_tel_snapshot': contactTelSnapshot,
      'contact_address_snapshot': contactAddressSnapshot,
      'company_snapshot': companySnapshot,
      'company_seal_hash': companySealHash,
      'meta_json': metaJsonValue,
      'meta_hash': metaHashValue,
    };
  }

  Invoice copyWith({
    String? id,
    Customer? customer,
    DateTime? date,
    List<InvoiceItem>? items,
    String? notes,
    String? filePath,
    double? taxRate,
    DocumentType? documentType,
    OrderStatus? orderStatus,
    DateTime? promisedDate,
    DateTime? fulfilledDate,
    String? sourceDocumentId,
    String? linkedDeliveryId,
    String? linkedInvoiceId,
    String? customerFormalNameSnapshot,
    String? odooId,
    bool? isSynced,
    DateTime? updatedAt,
    double? latitude,
    double? longitude,
    String? terminalId,
    bool? isDraft,
    String? subject,
    bool? isLocked,
    int? contactVersionId,
    String? contactEmailSnapshot,
    String? contactTelSnapshot,
    String? contactAddressSnapshot,
    String? companySnapshot,
    String? companySealHash,
    String? metaJson,
    String? metaHash,
  }) {
    return Invoice(
      id: id ?? this.id,
      customer: customer ?? this.customer,
      date: date ?? this.date,
      items: items ?? List.from(this.items),
      notes: notes ?? this.notes,
      filePath: filePath ?? this.filePath,
      taxRate: taxRate ?? this.taxRate,
      documentType: documentType ?? this.documentType,
      orderStatus: orderStatus ?? this.orderStatus,
      promisedDate: promisedDate ?? this.promisedDate,
      fulfilledDate: fulfilledDate ?? this.fulfilledDate,
      sourceDocumentId: sourceDocumentId ?? this.sourceDocumentId,
      linkedDeliveryId: linkedDeliveryId ?? this.linkedDeliveryId,
      linkedInvoiceId: linkedInvoiceId ?? this.linkedInvoiceId,
      customerFormalNameSnapshot:
          customerFormalNameSnapshot ?? this.customerFormalNameSnapshot,
      odooId: odooId ?? this.odooId,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      terminalId: terminalId ?? this.terminalId,
      isDraft: isDraft ?? this.isDraft,
      subject: subject ?? this.subject,
      isLocked: isLocked ?? this.isLocked,
      contactVersionId: contactVersionId ?? this.contactVersionId,
      contactEmailSnapshot: contactEmailSnapshot ?? this.contactEmailSnapshot,
      contactTelSnapshot: contactTelSnapshot ?? this.contactTelSnapshot,
      contactAddressSnapshot:
          contactAddressSnapshot ?? this.contactAddressSnapshot,
      companySnapshot: companySnapshot ?? this.companySnapshot,
      companySealHash: companySealHash ?? this.companySealHash,
      metaJson: metaJson ?? this.metaJson,
      metaHash: metaHash ?? this.metaHash,
    );
  }

  String toCsv() {
    final buffer = StringBuffer();
    buffer.writeln('伝票種別,伝票番号,日付,取引先,合計金額,緯度,経度');
    buffer.writeln(
      '$documentTypeName,$invoiceNumber,${DateFormat('yyyy/MM/dd').format(date)},$customerNameForDisplay,$totalAmount,${latitude ?? ""},${longitude ?? ""}',
    );
    buffer.writeln('');
    buffer.writeln('品名,数量,単価,小計');
    for (var item in items) {
      buffer.writeln(
        '${item.description},${item.quantity},${item.unitPrice},${item.subtotal}',
      );
    }
    return buffer.toString();
  }
}
