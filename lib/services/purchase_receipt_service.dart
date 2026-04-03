import 'package:uuid/uuid.dart';

import '../models/purchase_entry_models.dart';
import 'purchase_entry_repository.dart';
import 'purchase_receipt_repository.dart';

class PurchaseReceiptService {
  PurchaseReceiptService({
    PurchaseReceiptRepository? receiptRepository,
    PurchaseEntryRepository? entryRepository,
  })  : _receiptRepository = receiptRepository ?? PurchaseReceiptRepository(),
        _entryRepository = entryRepository ?? PurchaseEntryRepository();

  final PurchaseReceiptRepository _receiptRepository;
  final PurchaseEntryRepository _entryRepository;
  final Uuid _uuid = const Uuid();

  Future<List<PurchaseReceipt>> fetchReceipts({DateTime? startDate, DateTime? endDate}) {
    return _receiptRepository.fetchReceipts(startDate: startDate, endDate: endDate);
  }

  Future<Map<String, int>> fetchAllocatedTotals(Iterable<String> entryIds) {
    return _receiptRepository.fetchAllocatedTotals(entryIds);
  }

  Future<List<PurchaseReceiptLink>> fetchLinks(String receiptId) {
    return _receiptRepository.fetchLinks(receiptId);
  }

  Future<PurchaseReceipt?> findById(String id) {
    return _receiptRepository.findById(id);
  }

  Future<void> deleteReceipt(String id) {
    return _receiptRepository.deleteReceipt(id);
  }

  Future<PurchaseReceipt> createReceipt({
    String? supplierId,
    required DateTime paymentDate,
    required int amount,
    String? method,
    String? notes,
    List<PurchaseReceiptAllocationInput> allocations = const [],
  }) async {
    if (amount <= 0) {
      throw ArgumentError('amount must be greater than 0');
    }
    final receipt = PurchaseReceipt(
      id: _uuid.v4(),
      supplierId: supplierId,
      paymentDate: paymentDate,
      method: method,
      amount: amount,
      notes: notes,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return _saveReceipt(receipt: receipt, allocations: allocations);
  }

  Future<PurchaseReceipt> updateReceipt({
    required PurchaseReceipt receipt,
    List<PurchaseReceiptAllocationInput> allocations = const [],
  }) {
    final updated = receipt.copyWith(updatedAt: DateTime.now());
    return _saveReceipt(receipt: updated, allocations: allocations);
  }

  Future<PurchaseReceipt> _saveReceipt({
    required PurchaseReceipt receipt,
    required List<PurchaseReceiptAllocationInput> allocations,
  }) async {
    final entries = await _loadEntries(allocations.map((a) => a.purchaseEntryId));
    final allocatedTotals = await _receiptRepository.fetchAllocatedTotals(entries.keys);

    final links = <PurchaseReceiptLink>[];
    for (final allocation in allocations) {
      final entry = entries[allocation.purchaseEntryId];
      if (entry == null) {
        throw StateError('仕入伝票が見つかりません: ${allocation.purchaseEntryId}');
      }
      final currentAllocated = allocatedTotals[entry.id] ?? 0;
      final outstanding = entry.amountTaxIncl - currentAllocated;
      if (allocation.amount > outstanding) {
        throw StateError('割当額が支払残を超えています: ${entry.id}');
      }
      links.add(
        PurchaseReceiptLink(
          receiptId: receipt.id,
          purchaseEntryId: entry.id,
          allocatedAmount: allocation.amount,
        ),
      );
      allocatedTotals[entry.id] = currentAllocated + allocation.amount;
    }

    final totalAllocated = links.fold<int>(0, (sum, link) => sum + link.allocatedAmount);
    if (totalAllocated > receipt.amount) {
      throw StateError('割当総額が支払額を超えています');
    }

    await _receiptRepository.upsertReceipt(receipt, links);
    await _updateEntryStatuses(entries.values, allocatedTotals);
    return receipt;
  }

  Future<void> _updateEntryStatuses(Iterable<PurchaseEntry> entries, Map<String, int> allocatedTotals) async {
    for (final entry in entries) {
      final allocated = allocatedTotals[entry.id] ?? 0;
      PurchaseEntryStatus newStatus;
      if (allocated >= entry.amountTaxIncl) {
        newStatus = PurchaseEntryStatus.settled;
      } else if (allocated > 0) {
        newStatus = PurchaseEntryStatus.confirmed;
      } else {
        newStatus = entry.status;
      }
      if (newStatus != entry.status) {
        await _entryRepository.upsertEntry(entry.copyWith(status: newStatus, updatedAt: DateTime.now()));
      }
    }
  }

  Future<Map<String, PurchaseEntry>> _loadEntries(Iterable<String> entryIds) async {
    final map = <String, PurchaseEntry>{};
    for (final id in entryIds) {
      final entry = await _entryRepository.findById(id);
      if (entry != null) {
        map[id] = entry;
      }
    }
    return map;
  }
}
