import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import '../models/purchase_model.dart';
import '../models/supplier_model.dart';
import '../models/base_document.dart';
import '../widgets/document_card.dart';
import '../services/supplier_repository.dart';
import '../services/database_helper.dart';
import '../services/activity_log_repository.dart';

/// 仕入リポジトリ
class PurchaseRepository {
  final DatabaseHelper _db = DatabaseHelper();
  final SupplierRepository _supplierRepo = SupplierRepository();

  /// すべての仕入を取得
  Future<List<Purchase>> getAllPurchases() async {
    final database = await _db.database;
    final suppliers = await _supplierRepo.getAllSuppliers();
    
    final maps = await database.query(
      'purchases',
      orderBy: 'date DESC',
    );

    return maps.map((map) {
      final supplierId = map['supplier_id'] as String?;
      final supplier = supplierId != null
          ? suppliers.firstWhere(
              (s) => s.id == supplierId,
              orElse: () => Supplier(
                id: supplierId,
                displayName: '不明な仕入先',
                formalName: '不明な仕入先',
                updatedAt: DateTime.now(),
              ),
            )
          : null;

      return Purchase.fromMap(map, supplier);
    }).toList();
  }

  /// 仕入を保存
  Future<void> savePurchase(Purchase purchase) async {
    final database = await _db.database;
    await database.insert(
      'purchases',
      purchase.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 仕入を削除
  Future<void> deletePurchase(String id) async {
    final database = await _db.database;
    await database.delete('purchases', where: 'id = ?', whereArgs: [id]);
  }

  /// 仕入をコピー
  Future<void> copyPurchase(Purchase purchase) async {
    final copiedPurchase = purchase.copyWith(
      id: const Uuid().v4(),
      documentNumber: _generateDocumentNumber(),
      status: DocumentStatus.draft,
      purchaseStatus: PurchaseStatus.draft,
      paymentStatus: PaymentStatus.unpaid,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    await savePurchase(copiedPurchase);
  }

  /// 特定仕入を取得
  Future<Purchase?> getPurchase(String id) async {
    final database = await _db.database;
    final maps = await database.query(
      'purchases',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    
    final map = maps.first;
    final supplierId = map['supplier_id'] as String?;
    Supplier? supplier;
    
    if (supplierId != null) {
      supplier = await _supplierRepo.getSupplier(supplierId);
    }
    
    return Purchase.fromMap(map, supplier);
  }

  /// 伝票番号を生成
  String _generateDocumentNumber() {
    final now = DateTime.now();
    final year = now.year % 100; // 下2桁
    final month = now.month.toString().padLeft(2, '0');
    return 'P$year$month-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
  }
}
