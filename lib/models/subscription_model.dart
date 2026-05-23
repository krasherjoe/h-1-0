import 'dart:convert';

/// 定期請求明細テンプレート
class SubscriptionLineItem {
  final String description;
  final int quantity;
  final int unitPrice;
  final double taxRate;

  const SubscriptionLineItem({
    required this.description,
    this.quantity = 1,
    required this.unitPrice,
    this.taxRate = 0.10,
  });

  Map<String, dynamic> toJson() => {
    'description': description,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'taxRate': taxRate,
  };

  factory SubscriptionLineItem.fromJson(Map<String, dynamic> json) => SubscriptionLineItem(
    description: json['description'] as String,
    quantity: json['quantity'] as int? ?? 1,
    unitPrice: json['unitPrice'] as int,
    taxRate: (json['taxRate'] as num?)?.toDouble() ?? 0.10,
  );
}

/// 定期請求（サブスクリプション）モデル
class Subscription {
  final String id;
  final String customerId;
  final String customerName;
  final int amount; // 1回あたりの請求額
  final String cycle; // monthly, yearly, custom
  final int cycleDays; // customの場合の日数
  final int totalCycles; // 総回数（0=無制限）
  final int completedCycles; // 完了回数
  final DateTime startDate;
  final DateTime? nextBillingDate;
  final String? description;
  final List<SubscriptionLineItem> lineItems;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Subscription({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.amount,
    this.cycle = 'monthly',
    this.cycleDays = 30,
    this.totalCycles = 0,
    this.completedCycles = 0,
    required this.startDate,
    this.nextBillingDate,
    this.description,
    this.lineItems = const [],
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'customer_id': customerId,
    'customer_name': customerName,
    'amount': amount,
    'cycle': cycle,
    'cycle_days': cycleDays,
    'total_cycles': totalCycles,
    'completed_cycles': completedCycles,
    'start_date': startDate.toIso8601String(),
    'next_billing_date': nextBillingDate?.toIso8601String(),
    'description': description,
    'line_items': lineItems.isNotEmpty ? jsonEncode(lineItems.map((l) => l.toJson()).toList()) : null,
    'is_active': isActive ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory Subscription.fromMap(Map<String, dynamic> map) => Subscription(
    id: map['id'] as String,
    customerId: map['customer_id'] as String,
    customerName: map['customer_name'] as String,
    amount: map['amount'] as int? ?? 0,
    cycle: map['cycle'] as String? ?? 'monthly',
    cycleDays: map['cycle_days'] as int? ?? 30,
    totalCycles: map['total_cycles'] as int? ?? 0,
    completedCycles: map['completed_cycles'] as int? ?? 0,
    startDate: DateTime.parse(map['start_date'] as String),
    nextBillingDate: map['next_billing_date'] != null ? DateTime.parse(map['next_billing_date'] as String) : null,
    description: map['description'] as String?,
    lineItems: map['line_items'] != null ? (jsonDecode(map['line_items'] as String) as List<dynamic>).map((e) => SubscriptionLineItem.fromJson(e as Map<String, dynamic>)).toList() : [],
    isActive: (map['is_active'] as int? ?? 1) == 1,
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
  );

  Subscription copyWith({
    String? customerId,
    String? customerName,
    int? amount,
    String? cycle,
    int? cycleDays,
    int? totalCycles,
    int? completedCycles,
    DateTime? startDate,
    DateTime? nextBillingDate,
    String? description,
    List<SubscriptionLineItem>? lineItems,
    bool? isActive,
  }) => Subscription(
    id: id,
    customerId: customerId ?? this.customerId,
    customerName: customerName ?? this.customerName,
    amount: amount ?? this.amount,
    cycle: cycle ?? this.cycle,
    cycleDays: cycleDays ?? this.cycleDays,
    totalCycles: totalCycles ?? this.totalCycles,
    completedCycles: completedCycles ?? this.completedCycles,
    startDate: startDate ?? this.startDate,
    nextBillingDate: nextBillingDate ?? this.nextBillingDate,
    description: description ?? this.description,
    lineItems: lineItems ?? this.lineItems,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
