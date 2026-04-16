import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:intl/intl.dart';
import '../models/customer_model.dart';
import '../models/customer_model.dart' show HonorificCode;

class InvoiceItem {
  final String? id;
  final String? productId; // 追加
  String description;
  int quantity;
  int unitPrice;
  int? discountAmount; // 値引き額
  double? discountRate; // 値引き率

  InvoiceItem({
    this.id,
    this.productId, // 追加
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.discountAmount,
    this.discountRate,
  });

  int get subtotal {
    int base = quantity * unitPrice;
    if (discountAmount != null && discountAmount! > 0) {
      return base - discountAmount!;
    }
    if (discountRate != null && discountRate! > 0) {
      return (base * (1 - discountRate!)).round();
    }
    return base;
  }

  Map<String, dynamic> toMap(String invoiceId) {
    return {
      'id': id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      'invoice_id': invoiceId,
      'product_id': productId, // 追加
      'description': description,
      'quantity': quantity,
      'unit_price': unitPrice,
      'discount_amount': discountAmount,
      'discount_rate': discountRate,
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      id: map['id'],
      productId: map['product_id'], // 追加
      description: map['description'],
      quantity: map['quantity'],
      unitPrice: map['unit_price'],
      discountAmount: map['discount_amount'] as int?,
      discountRate: map['discount_rate'] as double?,
    );
  }

  InvoiceItem copyWith({
    String? id, // Added this to be complete
    String? description,
    int? quantity,
    int? unitPrice,
    String? productId,
    int? discountAmount,
    double? discountRate,
  }) {
    return InvoiceItem(
      id: id ?? this.id, // Added this to be complete
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      productId: productId ?? this.productId,
      discountAmount: discountAmount ?? this.discountAmount,
      discountRate: discountRate ?? this.discountRate,
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
  final int? totalDiscountAmount; // 合計値引き額
  final double? totalDiscountRate; // 合計値引き率
  final bool isReceiptIssued; // 領収証発行済みフラグ
  final DateTime? receiptIssuedAt; // 領収証発行日時
  final bool includeTax; // 税込みフラグ
  final String? priceAdjustmentType; // 価格調整タイプ: 'round_down', 'round_up', 'round_nearest'
  final int? priceAdjustmentUnit; // 価格調整単位: 1, 10, 100, 1000

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
    this.totalDiscountAmount,
    this.totalDiscountRate,
    this.isReceiptIssued = false,
    this.receiptIssuedAt,
    this.includeTax = false,
    this.priceAdjustmentType,
    this.priceAdjustmentUnit,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       terminalId = terminalId ?? "T1", // デフォルト端末ID
       updatedAt = updatedAt ?? DateTime.now();

  /// 伝票内容から決定論的なハッシュを生成する (SHA256の一部)
  String get contentHash {
    final input =
        "$id|$terminalId|${date.toIso8601String()}|${customer.id}|$totalAmount|${subject ?? ""}|${items.map((e) => "${e.description}${e.quantity}${e.unitPrice}").join()}";
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString().toUpperCase();
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
    return hasHonorific ? base : '$base ${HonorificCode.toName(customer.title)}';
  }

  int get subtotal => items.fold(0, (sum, item) => sum + item.subtotal);
  
  /// 価格調整値引きを計算
  int get priceAdjustmentDiscount {
    if (priceAdjustmentType == null || priceAdjustmentUnit == null) {
      return 0;
    }

    // 手動入力モードの場合はpriceAdjustmentUnitをそのまま値引き額として返す
    if (priceAdjustmentType == 'manual') {
      return priceAdjustmentUnit!;
    }

    final unit = priceAdjustmentUnit!;
    final baseAmount = subtotal - _regularDiscount;
    final taxAmount = includeTax ? (baseAmount * taxRate).floor() : 0;
    final totalBeforeAdjustment = baseAmount + taxAmount;

    int adjustedTotal;
    switch (priceAdjustmentType) {
      case 'round_down':
        // 切り捨て
        adjustedTotal = (totalBeforeAdjustment ~/ unit) * unit;
        break;
      case 'round_up':
        // 切り上げ
        adjustedTotal = ((totalBeforeAdjustment + unit - 1) ~/ unit) * unit;
        break;
      case 'round_nearest':
        // 四捨五入
        adjustedTotal = ((totalBeforeAdjustment + unit ~/ 2) ~/ unit) * unit;
        break;
      default:
        return 0;
    }

    final discount = totalBeforeAdjustment - adjustedTotal;
    return discount;
  }
  
  /// 通常の値引き額（明細単位 + 伝票全体）
  int get _regularDiscount {
    int itemDiscount = items.fold(0, (sum, item) {
      if (item.discountAmount != null && item.discountAmount! > 0) {
        return sum + item.discountAmount!;
      }
      if (item.discountRate != null && item.discountRate! > 0) {
        int base = item.quantity * item.unitPrice;
        return sum + (base * item.discountRate!).round();
      }
      return sum;
    });

    if (totalDiscountAmount != null && totalDiscountAmount! > 0) {
      return totalDiscountAmount!;
    }
    if (totalDiscountRate != null && totalDiscountRate! > 0) {
      return (subtotal * totalDiscountRate!).round();
    }

    return itemDiscount;
  }

  int get discountAmount => _regularDiscount + priceAdjustmentDiscount;

  int get taxableAmount => subtotal - discountAmount;
  int get tax => (taxableAmount * taxRate).floor();
  int get totalAmount => taxableAmount + tax;

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

  String get mailAttachmentFileName => '$mailTitleCore.pdf';

  String get mailBodyText {
    final docName = documentTypeName.replaceAll('書', '');
    return '$docNameをお送りします。ご確認ください。\n※このメールはシステムにより自動送信されています。';
  }

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
      'is_receipt_issued': isReceiptIssued ? 1 : 0,
      'receipt_issued_at': receiptIssuedAt?.toIso8601String(),
      'total_discount_amount': totalDiscountAmount,
      'total_discount_rate': totalDiscountRate,
      'price_adjustment_type': priceAdjustmentType,
      'price_adjustment_unit': priceAdjustmentUnit,
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
    int? totalDiscountAmount,
    double? totalDiscountRate,
    bool? isReceiptIssued,
    DateTime? receiptIssuedAt,
    bool? includeTax,
    String? priceAdjustmentType,
    int? priceAdjustmentUnit,
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
      totalDiscountAmount: totalDiscountAmount ?? this.totalDiscountAmount,
      totalDiscountRate: totalDiscountRate ?? this.totalDiscountRate,
      isReceiptIssued: isReceiptIssued ?? this.isReceiptIssued,
      receiptIssuedAt: receiptIssuedAt ?? this.receiptIssuedAt,
      includeTax: includeTax ?? this.includeTax,
      priceAdjustmentType: priceAdjustmentType ?? this.priceAdjustmentType,
      priceAdjustmentUnit: priceAdjustmentUnit ?? this.priceAdjustmentUnit,
    );
  }
}
