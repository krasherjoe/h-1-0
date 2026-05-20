import 'package:flutter/material.dart';

/// 販売フロー状態列挙
enum SalesFlowStatus {
  // 見積状態
  quoteDraft,      // 見積作成中
  quoteSubmitted,  // 見積提出済
  quoteApproved,   // 見積承認済
  quoteRejected,   // 見積却下
  quoteExpired,    // 見積期限切れ
  
  // 受注状態
  orderDraft,      // 受注作成中
  orderSubmitted,  // 受注登録済
  orderConfirmed,  // 受注確定
  orderCancelled,  // 受注キャンセル
  
  // 売上状態
  salesDraft,      // 売上作成中
  salesConfirmed,  // 売上確定
  salesInvoiced,   // 請求済
  salesPaid,       // 入金済
  salesCancelled,  // 売上キャンセル
  
  // 配送状態
  deliveryPending, // 配送待ち
  deliveryPreparing, // 配送準備中
  deliveryShipped, // 出荷済
  deliveryDelivered, // 配送完了
  deliveryFailed,  // 配送失敗
  
  // 請求状態
  invoiceDraft,    // 請求作成中
  invoiceIssued,   // 請求発行済
  invoiceOverdue,  // 請求期限切れ
  invoicePaid,     // 請求支払済
  invoiceCancelled, // 請求キャンセル
}

/// 販売フロー状態拡張
extension SalesFlowStatusExtension on SalesFlowStatus {
  String get displayName {
    switch (this) {
      case SalesFlowStatus.quoteDraft: return '見積作成中';
      case SalesFlowStatus.quoteSubmitted: return '見積提出済';
      case SalesFlowStatus.quoteApproved: return '見積承認済';
      case SalesFlowStatus.quoteRejected: return '見積却下';
      case SalesFlowStatus.quoteExpired: return '見積期限切れ';
      case SalesFlowStatus.orderDraft: return '受注作成中';
      case SalesFlowStatus.orderSubmitted: return '受注登録済';
      case SalesFlowStatus.orderConfirmed: return '受注確定';
      case SalesFlowStatus.orderCancelled: return '受注キャンセル';
      case SalesFlowStatus.salesDraft: return '売上作成中';
      case SalesFlowStatus.salesConfirmed: return '売上確定';
      case SalesFlowStatus.salesInvoiced: return '請求済';
      case SalesFlowStatus.salesPaid: return '入金済';
      case SalesFlowStatus.salesCancelled: return '売上キャンセル';
      case SalesFlowStatus.deliveryPending: return '配送待ち';
      case SalesFlowStatus.deliveryPreparing: return '配送準備中';
      case SalesFlowStatus.deliveryShipped: return '出荷済';
      case SalesFlowStatus.deliveryDelivered: return '配送完了';
      case SalesFlowStatus.deliveryFailed: return '配送失敗';
      case SalesFlowStatus.invoiceDraft: return '請求作成中';
      case SalesFlowStatus.invoiceIssued: return '請求発行済';
      case SalesFlowStatus.invoiceOverdue: return '請求期限切れ';
      case SalesFlowStatus.invoicePaid: return '請求支払済';
      case SalesFlowStatus.invoiceCancelled: return '請求キャンセル';
    }
  }
  
  String get category {
    switch (this) {
      case SalesFlowStatus.quoteDraft:
      case SalesFlowStatus.quoteSubmitted:
      case SalesFlowStatus.quoteApproved:
      case SalesFlowStatus.quoteRejected:
      case SalesFlowStatus.quoteExpired:
        return '見積';
      case SalesFlowStatus.orderDraft:
      case SalesFlowStatus.orderSubmitted:
      case SalesFlowStatus.orderConfirmed:
      case SalesFlowStatus.orderCancelled:
        return '受注';
      case SalesFlowStatus.salesDraft:
      case SalesFlowStatus.salesConfirmed:
      case SalesFlowStatus.salesInvoiced:
      case SalesFlowStatus.salesPaid:
      case SalesFlowStatus.salesCancelled:
        return '売上';
      case SalesFlowStatus.deliveryPending:
      case SalesFlowStatus.deliveryPreparing:
      case SalesFlowStatus.deliveryShipped:
      case SalesFlowStatus.deliveryDelivered:
      case SalesFlowStatus.deliveryFailed:
        return '配送';
      case SalesFlowStatus.invoiceDraft:
      case SalesFlowStatus.invoiceIssued:
      case SalesFlowStatus.invoiceOverdue:
      case SalesFlowStatus.invoicePaid:
      case SalesFlowStatus.invoiceCancelled:
        return '請求';
    }
  }
  
  Color getColor(ColorScheme cs) {
    switch (this) {
      case SalesFlowStatus.quoteDraft:
      case SalesFlowStatus.orderDraft:
      case SalesFlowStatus.salesDraft:
      case SalesFlowStatus.invoiceDraft:
        return cs.onSurfaceVariant;
      case SalesFlowStatus.quoteSubmitted:
      case SalesFlowStatus.orderSubmitted:
        return cs.primary;
      case SalesFlowStatus.quoteApproved:
      case SalesFlowStatus.orderConfirmed:
      case SalesFlowStatus.salesConfirmed:
        return cs.tertiary;
      case SalesFlowStatus.quoteRejected:
      case SalesFlowStatus.orderCancelled:
      case SalesFlowStatus.salesCancelled:
      case SalesFlowStatus.invoiceCancelled:
      case SalesFlowStatus.deliveryFailed:
      case SalesFlowStatus.invoiceOverdue:
        return cs.error;
      case SalesFlowStatus.quoteExpired:
        return cs.secondary;
      case SalesFlowStatus.salesInvoiced:
      case SalesFlowStatus.invoiceIssued:
        return cs.secondary;
      case SalesFlowStatus.salesPaid:
      case SalesFlowStatus.invoicePaid:
        return cs.tertiary;
      case SalesFlowStatus.deliveryPending:
        return cs.secondary;
      case SalesFlowStatus.deliveryPreparing:
        return cs.primary;
      case SalesFlowStatus.deliveryShipped:
        return cs.primary;
      case SalesFlowStatus.deliveryDelivered:
        return cs.tertiary;
    }
  }
  
  IconData get icon {
    switch (this) {
      case SalesFlowStatus.quoteDraft:
      case SalesFlowStatus.orderDraft:
      case SalesFlowStatus.salesDraft:
      case SalesFlowStatus.invoiceDraft:
        return Icons.edit;
      case SalesFlowStatus.quoteSubmitted:
      case SalesFlowStatus.orderSubmitted:
        return Icons.send;
      case SalesFlowStatus.quoteApproved:
      case SalesFlowStatus.orderConfirmed:
      case SalesFlowStatus.salesConfirmed:
        return Icons.check_circle;
      case SalesFlowStatus.quoteRejected:
      case SalesFlowStatus.orderCancelled:
      case SalesFlowStatus.salesCancelled:
      case SalesFlowStatus.invoiceCancelled:
        return Icons.cancel;
      case SalesFlowStatus.quoteExpired:
        return Icons.access_time;
      case SalesFlowStatus.salesInvoiced:
      case SalesFlowStatus.invoiceIssued:
        return Icons.receipt;
      case SalesFlowStatus.salesPaid:
      case SalesFlowStatus.invoicePaid:
        return Icons.payment;
      case SalesFlowStatus.deliveryPending:
        return Icons.inventory;
      case SalesFlowStatus.deliveryPreparing:
        return Icons.local_shipping;
      case SalesFlowStatus.deliveryShipped:
        return Icons.local_mall;
      case SalesFlowStatus.deliveryDelivered:
        return Icons.home;
      case SalesFlowStatus.deliveryFailed:
        return Icons.error;
      case SalesFlowStatus.invoiceOverdue:
        return Icons.warning;
    }
  }
  
  bool get isFinal {
    return [
      SalesFlowStatus.quoteRejected,
      SalesFlowStatus.quoteExpired,
      SalesFlowStatus.orderCancelled,
      SalesFlowStatus.salesCancelled,
      SalesFlowStatus.deliveryDelivered,
      SalesFlowStatus.deliveryFailed,
      SalesFlowStatus.invoicePaid,
      SalesFlowStatus.invoiceCancelled,
    ].contains(this);
  }
  
  bool get isActive {
    return ![
      SalesFlowStatus.quoteDraft,
      SalesFlowStatus.orderDraft,
      SalesFlowStatus.salesDraft,
      SalesFlowStatus.invoiceDraft,
      SalesFlowStatus.quoteExpired,
      SalesFlowStatus.orderCancelled,
      SalesFlowStatus.salesCancelled,
      SalesFlowStatus.deliveryFailed,
      SalesFlowStatus.invoiceCancelled,
    ].contains(this);
  }
  
  List<SalesFlowStatus> get nextStatuses {
    switch (this) {
      case SalesFlowStatus.quoteDraft:
        return [SalesFlowStatus.quoteSubmitted];
      case SalesFlowStatus.quoteSubmitted:
        return [SalesFlowStatus.quoteApproved, SalesFlowStatus.quoteRejected];
      case SalesFlowStatus.quoteApproved:
        return [SalesFlowStatus.orderDraft];
      case SalesFlowStatus.quoteRejected:
      case SalesFlowStatus.quoteExpired:
        return [];
      case SalesFlowStatus.orderDraft:
        return [SalesFlowStatus.orderSubmitted];
      case SalesFlowStatus.orderSubmitted:
        return [SalesFlowStatus.orderConfirmed, SalesFlowStatus.orderCancelled];
      case SalesFlowStatus.orderConfirmed:
        return [SalesFlowStatus.salesDraft, SalesFlowStatus.deliveryPending];
      case SalesFlowStatus.orderCancelled:
        return [];
      case SalesFlowStatus.salesDraft:
        return [SalesFlowStatus.salesConfirmed];
      case SalesFlowStatus.salesConfirmed:
        return [SalesFlowStatus.salesInvoiced];
      case SalesFlowStatus.salesInvoiced:
        return [SalesFlowStatus.salesPaid];
      case SalesFlowStatus.salesPaid:
        return [];
      case SalesFlowStatus.salesCancelled:
        return [];
      case SalesFlowStatus.deliveryPending:
        return [SalesFlowStatus.deliveryPreparing];
      case SalesFlowStatus.deliveryPreparing:
        return [SalesFlowStatus.deliveryShipped];
      case SalesFlowStatus.deliveryShipped:
        return [SalesFlowStatus.deliveryDelivered, SalesFlowStatus.deliveryFailed];
      case SalesFlowStatus.deliveryDelivered:
      case SalesFlowStatus.deliveryFailed:
        return [];
      case SalesFlowStatus.invoiceDraft:
        return [SalesFlowStatus.invoiceIssued];
      case SalesFlowStatus.invoiceIssued:
        return [SalesFlowStatus.invoicePaid, SalesFlowStatus.invoiceOverdue];
      case SalesFlowStatus.invoiceOverdue:
        return [SalesFlowStatus.invoicePaid];
      case SalesFlowStatus.invoicePaid:
        return [];
      case SalesFlowStatus.invoiceCancelled:
        return [];
    }
  }
}

/// 在庫引当状態
enum StockAllocationStatus {
  notAllocated,   // 未引当
  allocated,      // 引当済
  partiallyAllocated, // 部分引当
  overAllocated,  // 過剰引当
  released,       // 引当解除
}

/// 在庫引当状態拡張
extension StockAllocationStatusExtension on StockAllocationStatus {
  String get displayName {
    switch (this) {
      case StockAllocationStatus.notAllocated: return '未引当';
      case StockAllocationStatus.allocated: return '引当済';
      case StockAllocationStatus.partiallyAllocated: return '部分引当';
      case StockAllocationStatus.overAllocated: return '過剰引当';
      case StockAllocationStatus.released: return '引当解除';
    }
  }
  
  Color getColor(ColorScheme cs) {
    switch (this) {
      case StockAllocationStatus.notAllocated: return cs.onSurfaceVariant;
      case StockAllocationStatus.allocated: return cs.tertiary;
      case StockAllocationStatus.partiallyAllocated: return cs.secondary;
      case StockAllocationStatus.overAllocated: return cs.error;
      case StockAllocationStatus.released: return cs.primary;
    }
  }
}

/// 配送連携状態
enum DeliveryLinkStatus {
  notLinked,      // 未連携
  linked,         // 連携済
  inTransit,      // 輸送中
  completed,      // 完了
  failed,         // 失敗
  cancelled,      // キャンセル
}

/// 配送連携状態拡張
extension DeliveryLinkStatusExtension on DeliveryLinkStatus {
  String get displayName {
    switch (this) {
      case DeliveryLinkStatus.notLinked: return '未連携';
      case DeliveryLinkStatus.linked: return '連携済';
      case DeliveryLinkStatus.inTransit: return '輸送中';
      case DeliveryLinkStatus.completed: return '完了';
      case DeliveryLinkStatus.failed: return '失敗';
      case DeliveryLinkStatus.cancelled: return 'キャンセル';
    }
  }
  
  Color getColor(ColorScheme cs) {
    switch (this) {
      case DeliveryLinkStatus.notLinked: return cs.onSurfaceVariant;
      case DeliveryLinkStatus.linked: return cs.primary;
      case DeliveryLinkStatus.inTransit: return cs.secondary;
      case DeliveryLinkStatus.completed: return cs.tertiary;
      case DeliveryLinkStatus.failed: return cs.error;
      case DeliveryLinkStatus.cancelled: return cs.secondary;
    }
  }
}

/// 請求連携状態
enum InvoiceLinkStatus {
  notLinked,      // 未連携
  linked,         // 連携済
  issued,         // 発行済
  overdue,        // 期限切れ
  paid,           // 支払済
  cancelled,      // キャンセル
}

/// 請求連携状態拡張
extension InvoiceLinkStatusExtension on InvoiceLinkStatus {
  String get displayName {
    switch (this) {
      case InvoiceLinkStatus.notLinked: return '未連携';
      case InvoiceLinkStatus.linked: return '連携済';
      case InvoiceLinkStatus.issued: return '発行済';
      case InvoiceLinkStatus.overdue: return '期限切れ';
      case InvoiceLinkStatus.paid: return '支払済';
      case InvoiceLinkStatus.cancelled: return 'キャンセル';
    }
  }
  
  Color getColor(ColorScheme cs) {
    switch (this) {
      case InvoiceLinkStatus.notLinked: return cs.onSurfaceVariant;
      case InvoiceLinkStatus.linked: return cs.primary;
      case InvoiceLinkStatus.issued: return cs.secondary;
      case InvoiceLinkStatus.overdue: return cs.error;
      case InvoiceLinkStatus.paid: return cs.tertiary;
      case InvoiceLinkStatus.cancelled: return cs.secondary;
    }
  }
}
