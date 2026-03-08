import 'package:uuid/uuid.dart';

import '../models/purchase_order_models.dart';
import 'purchase_order_repository.dart';

class PurchaseOrderService {
  PurchaseOrderService({PurchaseOrderRepository? repository}) : _repository = repository ?? PurchaseOrderRepository();

  final PurchaseOrderRepository _repository;
  final Uuid _uuid = const Uuid();

  Future<List<PurchaseOrder>> fetchOrders({PurchaseOrderStatus? status, int? limit}) {
    return _repository.fetchOrders(status: status, limit: limit);
  }

  Future<PurchaseOrder?> findById(String id) {
    return _repository.findById(id);
  }

  Future<PurchaseOrder> saveOrder(PurchaseOrder order) async {
    final withTotals = order.recalcTotals().copyWith(updatedAt: DateTime.now());
    await _repository.upsertOrder(withTotals);
    return withTotals;
  }

  Future<PurchaseOrder> createDraft({
    String? supplierId,
    String? supplierSnapshot,
    DateTime? orderDate,
    DateTime? expectedDate,
    List<PurchaseOrderItem>? items,
  }) async {
    final now = DateTime.now();
    final order = PurchaseOrder(
      id: _uuid.v4(),
      documentNumber: _generateDocumentNumber(orderDate ?? now),
      supplierId: supplierId,
      supplierSnapshot: supplierSnapshot,
      orderDate: orderDate ?? now,
      expectedDate: expectedDate,
      status: PurchaseOrderStatus.draft,
      subtotal: 0,
      taxAmount: 0,
      total: 0,
      notes: null,
      createdAt: now,
      updatedAt: now,
      items: items ?? const [],
    );
    return saveOrder(order);
  }

  Future<void> deleteOrder(String id) {
    return _repository.deleteOrder(id);
  }

  String generateDocumentNumber({DateTime? date}) => _generateDocumentNumber(date ?? DateTime.now());

  String _generateDocumentNumber(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return 'PO$y$m$d-${_uuid.v4().substring(0, 6)}';
  }
}
