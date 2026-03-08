import 'package:uuid/uuid.dart';

import '../models/purchase_order_models.dart';
import 'purchase_payment_repository.dart';

class PurchasePaymentService {
  PurchasePaymentService({PurchasePaymentRepository? repository})
      : _repository = repository ?? PurchasePaymentRepository();

  final PurchasePaymentRepository _repository;
  final Uuid _uuid = const Uuid();

  Future<List<PurchasePayment>> fetchPayments({
    String? supplierId,
    String? purchaseOrderId,
    PurchasePaymentStatus? status,
  }) {
    return _repository.fetchPayments(
      supplierId: supplierId,
      purchaseOrderId: purchaseOrderId,
      status: status,
    );
  }

  Future<PurchasePayment?> findById(String id) {
    return _repository.findById(id);
  }

  Future<PurchasePayment> savePayment(PurchasePayment payment) async {
    final updated = payment.copyWith(updatedAt: DateTime.now());
    await _repository.upsertPayment(updated);
    return updated;
  }

  Future<PurchasePayment> createPayment({
    String? supplierId,
    String? purchaseOrderId,
    required DateTime paymentDate,
    required int amount,
    String? method,
    PurchasePaymentStatus status = PurchasePaymentStatus.scheduled,
    String? notes,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('amount must be greater than 0');
    }
    final now = DateTime.now();
    final payment = PurchasePayment(
      id: _uuid.v4(),
      purchaseOrderId: purchaseOrderId,
      supplierId: supplierId,
      paymentDate: paymentDate,
      amount: amount,
      method: method,
      status: status,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
    return savePayment(payment);
  }

  Future<void> deletePayment(String id) {
    return _repository.deletePayment(id);
  }
}
