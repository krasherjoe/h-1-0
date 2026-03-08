import 'package:uuid/uuid.dart';

import '../models/purchase_order_models.dart';
import 'purchase_return_repository.dart';

class PurchaseReturnService {
  PurchaseReturnService({PurchaseReturnRepository? repository}) : _repository = repository ?? PurchaseReturnRepository();

  final PurchaseReturnRepository _repository;
  final Uuid _uuid = const Uuid();

  Future<List<PurchaseReturn>> fetchReturns({PurchaseReturnStatus? status, int? limit}) {
    return _repository.fetchReturns(status: status, limit: limit);
  }

  Future<PurchaseReturn?> findById(String id) {
    return _repository.findById(id);
  }

  Future<PurchaseReturn> saveReturn(PurchaseReturn purchaseReturn) async {
    final withTotals = purchaseReturn.recalcTotals().copyWith(updatedAt: DateTime.now());
    await _repository.upsertReturn(withTotals);
    return withTotals;
  }

  Future<PurchaseReturn> createDraft({
    String? supplierId,
    String? supplierSnapshot,
    DateTime? returnDate,
    List<PurchaseReturnItem>? items,
  }) async {
    final now = DateTime.now();
    final purchaseReturn = PurchaseReturn(
      id: _uuid.v4(),
      documentNumber: _generateDocumentNumber(returnDate ?? now),
      supplierId: supplierId,
      supplierSnapshot: supplierSnapshot,
      returnDate: returnDate ?? now,
      status: PurchaseReturnStatus.draft,
      subtotal: 0,
      taxAmount: 0,
      total: 0,
      notes: null,
      createdAt: now,
      updatedAt: now,
      items: items ?? const [],
    );
    return saveReturn(purchaseReturn);
  }

  Future<void> deleteReturn(String id) {
    return _repository.deleteReturn(id);
  }

  String generateDocumentNumber({DateTime? date}) => _generateDocumentNumber(date ?? DateTime.now());

  String _generateDocumentNumber(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return 'PR$y$m$d-${_uuid.v4().substring(0, 6)}';
  }
}
