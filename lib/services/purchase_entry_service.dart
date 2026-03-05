import 'package:uuid/uuid.dart';

import '../models/purchase_entry_models.dart';
import 'purchase_entry_repository.dart';
import 'purchase_receipt_repository.dart';

class PurchaseEntryService {
  PurchaseEntryService({
    PurchaseEntryRepository? entryRepository,
    PurchaseReceiptRepository? receiptRepository,
  })  : _entryRepository = entryRepository ?? PurchaseEntryRepository(),
        _receiptRepository = receiptRepository ?? PurchaseReceiptRepository();

  final PurchaseEntryRepository _entryRepository;
  final PurchaseReceiptRepository _receiptRepository;
  final Uuid _uuid = const Uuid();

  Future<List<PurchaseEntry>> fetchEntries({PurchaseEntryStatus? status, int? limit}) {
    return _entryRepository.fetchEntries(status: status, limit: limit);
  }

  Future<PurchaseEntry?> findById(String id) {
    return _entryRepository.findById(id);
  }

  Future<void> deleteEntry(String id) {
    return _entryRepository.deleteEntry(id);
  }

  Future<PurchaseEntry> saveEntry(PurchaseEntry entry) async {
    final updated = entry.recalcTotals().copyWith(updatedAt: DateTime.now());
    await _entryRepository.upsertEntry(updated);
    return updated;
  }

  Future<PurchaseEntry> createQuickEntry({
    String? supplierId,
    String? supplierNameSnapshot,
    String? subject,
    DateTime? issueDate,
    List<PurchaseLineItem>? items,
  }) async {
    final now = DateTime.now();
    final entry = PurchaseEntry(
      id: _uuid.v4(),
      supplierId: supplierId,
      supplierNameSnapshot: supplierNameSnapshot,
      subject: subject,
      issueDate: issueDate ?? now,
      status: PurchaseEntryStatus.draft,
      createdAt: now,
      updatedAt: now,
      items: items ?? const [],
    );
    return saveEntry(entry);
  }

  Future<Map<String, int>> fetchAllocatedTotals(Iterable<String> entryIds) {
    return _receiptRepository.fetchAllocatedTotals(entryIds);
  }
}
