import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import '../models/payment_schedule_model.dart';
import '../models/purchase_model.dart' as purchase;
import '../models/base_document.dart';
import '../widgets/document_card.dart';
import '../services/purchase_repository.dart';
import '../services/database_helper.dart';

/// 支払予定リポジトリ
class PaymentScheduleRepository {
  final DatabaseHelper _db = DatabaseHelper();
  final PurchaseRepository _purchaseRepo = PurchaseRepository();

  /// すべての支払予定を取得
  Future<List<PaymentSchedule>> getAllSchedules() async {
    final database = await _db.database;
    final purchases = await _purchaseRepo.getAllPurchases();
    
    final maps = await database.query(
      'payment_schedules',
      orderBy: 'due_date ASC',
    );

    return maps.map((map) {
      final purchaseId = map['purchase_id'] as String;
      final purchaseData = purchases.firstWhere(
        (p) => p.id == purchaseId,
        orElse: () => purchase.Purchase(
          id: purchaseId,
          documentNumber: '不明',
          date: DateTime.now(),
          items: [],
          subtotal: 0,
          taxAmount: 0,
          total: 0,
          taxRate: 0.1,
          status: DocumentStatus.draft,
          purchaseStatus: purchase.PurchaseStatus.draft,
          paymentStatus: purchase.PaymentStatus.unpaid,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      return PaymentSchedule.fromMap(map, purchaseData);
    }).toList();
  }

  /// 延滞中の支払予定を取得
  Future<List<PaymentSchedule>> getOverdueSchedules() async {
    final database = await _db.database;
    final now = DateTime.now().toIso8601String();
    final purchases = await _purchaseRepo.getAllPurchases();
    
    final maps = await database.query(
      'payment_schedules',
      where: 'due_date < ? AND status != ?',
      whereArgs: [now, 'paid'],
      orderBy: 'due_date ASC',
    );

    return maps.map((map) {
      final purchaseId = map['purchase_id'] as String;
      final purchaseData = purchases.firstWhere(
        (p) => p.id == purchaseId,
        orElse: () => purchase.Purchase(
          id: purchaseId,
          documentNumber: '不明',
          date: DateTime.now(),
          items: [],
          subtotal: 0,
          taxAmount: 0,
          total: 0,
          taxRate: 0.1,
          status: DocumentStatus.draft,
          purchaseStatus: purchase.PurchaseStatus.draft,
          paymentStatus: purchase.PaymentStatus.unpaid,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      return PaymentSchedule.fromMap(map, purchaseData);
    }).toList();
  }

  /// 今後の支払予定を取得
  Future<List<PaymentSchedule>> getUpcomingSchedules({int days = 30}) async {
    final database = await _db.database;
    final now = DateTime.now();
    final futureDate = now.add(Duration(days: days));
    final purchases = await _purchaseRepo.getAllPurchases();
    
    final maps = await database.query(
      'payment_schedules',
      where: 'due_date BETWEEN ? AND ? AND status != ?',
      whereArgs: [
        now.toIso8601String(),
        futureDate.toIso8601String(),
        'paid',
      ],
      orderBy: 'due_date ASC',
    );

    return maps.map((map) {
      final purchaseId = map['purchase_id'] as String;
      final purchaseData = purchases.firstWhere(
        (p) => p.id == purchaseId,
        orElse: () => purchase.Purchase(
          id: purchaseId,
          documentNumber: '不明',
          date: DateTime.now(),
          items: [],
          subtotal: 0,
          taxAmount: 0,
          total: 0,
          taxRate: 0.1,
          status: DocumentStatus.draft,
          purchaseStatus: purchase.PurchaseStatus.draft,
          paymentStatus: purchase.PaymentStatus.unpaid,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      return PaymentSchedule.fromMap(map, purchaseData);
    }).toList();
  }

  /// 支払予定を保存
  Future<void> saveSchedule(PaymentSchedule schedule) async {
    final database = await _db.database;
    await database.insert(
      'payment_schedules',
      schedule.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 支払予定ステータスを更新
  Future<void> updateScheduleStatus(String id, PaymentStatus status, {String? paymentId}) async {
    final database = await _db.database;
    final updateData = {
      'status': status.name,
      'updated_at': DateTime.now().toIso8601String(),
    };
    
    if (paymentId != null) {
      updateData['payment_id'] = paymentId;
    }
    
    if (status == PaymentStatus.paid) {
      updateData['paid_date'] = DateTime.now().toIso8601String();
    }
    
    await database.update(
      'payment_schedules',
      updateData,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 特定支払予定を取得
  Future<PaymentSchedule?> getSchedule(String id) async {
    final database = await _db.database;
    final maps = await database.query(
      'payment_schedules',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    
    final map = maps.first;
    final purchaseId = map['purchase_id'] as String;
    final purchaseData = await _purchaseRepo.getPurchase(purchaseId);
    
    if (purchaseData == null) return null;
    
    return PaymentSchedule.fromMap(map, purchaseData);
  }

  /// 仕入から支払予定を自動生成
  Future<void> generateScheduleFromPurchase(purchase.Purchase purchase) async {
    if (purchase.dueDate == null) return;
    
    final database = await _db.database;
    
    // 既存の支払予定を確認
    final existing = await database.query(
      'payment_schedules',
      where: 'purchase_id = ?',
      whereArgs: [purchase.id],
    );
    
    if (existing.isNotEmpty) return; // 既存の場合は生成しない
    
    final schedule = PaymentSchedule(
      id: const Uuid().v4(),
      purchase: purchase,
      dueDate: purchase.dueDate!,
      amount: purchase.total,
      status: PaymentStatus.unpaid,
    );
    
    await database.insert('payment_schedules', schedule.toMap());
  }

  /// 月次支払予定集計
  Future<Map<String, int>> getMonthlyScheduleTotals({int months = 12}) async {
    final database = await _db.database;
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month - months + 1, 1);
    
    final maps = await database.rawQuery('''
      SELECT 
        strftime('%Y-%m', due_date) as month,
        SUM(amount) as total
      FROM payment_schedules
      WHERE due_date >= ? AND status != ?
      GROUP BY strftime('%Y-%m', due_date)
      ORDER BY month
    ''', [startDate.toIso8601String(), 'paid']);

    final result = <String, int>{};
    for (final map in maps) {
      result[map['month'] as String] = map['total'] as int;
    }
    return result;
  }

  /// 仕入先別支払予定集計
  Future<Map<String, int>> getScheduleTotalsBySupplier() async {
    final database = await _db.database;
    final maps = await database.rawQuery('''
      SELECT 
        s.display_name as supplier_name,
        s.id as supplier_id,
        SUM(ps.amount) as total
      FROM payment_schedules ps
      JOIN purchases p ON ps.purchase_id = p.id
      JOIN suppliers s ON p.supplier_id = s.id
      WHERE ps.status != ?
      GROUP BY s.id, s.display_name
    ''', ['paid']);

    final result = <String, int>{};
    for (final map in maps) {
      result[map['supplier_id'] as String] = map['total'] as int;
    }
    return result;
  }

  /// サンプル支払予定データを生成
  Future<void> _generateSampleSchedules({int limit = 5}) async {
    final database = await _db.database;
    final purchases = await _purchaseRepo.getAllPurchases();
    
    if (purchases.isEmpty) return;
    
    final now = DateTime.now();
    final sampleSchedules = [
      PaymentSchedule(
        id: const Uuid().v4(),
        purchase: purchases[0],
        dueDate: now.add(const Duration(days: 5)),
        amount: purchases[0].total,
        status: PaymentStatus.unpaid,
      ),
      PaymentSchedule(
        id: const Uuid().v4(),
        purchase: purchases.length > 1 ? purchases[1] : purchases[0],
        dueDate: now.add(const Duration(days: 10)),
        amount: purchases.length > 1 ? purchases[1].total : purchases[0].total,
        status: PaymentStatus.unpaid,
      ),
      PaymentSchedule(
        id: const Uuid().v4(),
        purchase: purchases.length > 2 ? purchases[2] : purchases[0],
        dueDate: now.subtract(const Duration(days: 5)),
        amount: purchases.length > 2 ? purchases[2].total : purchases[0].total,
        status: PaymentStatus.overdue,
      ),
    ];

    for (final schedule in sampleSchedules.take(limit)) {
      await database.insert('payment_schedules', schedule.toMap());
    }
  }
}
