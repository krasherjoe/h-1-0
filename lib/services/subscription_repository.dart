import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/customer_model.dart';
import '../models/invoice_models.dart';
import '../models/subscription_model.dart';
import 'database_helper.dart';
import 'invoice_repository.dart';

/// 定期請求リポジトリ
class SubscriptionRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<Subscription>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('subscriptions', orderBy: 'next_billing_date ASC');
    return rows.map(Subscription.fromMap).toList();
  }

  Future<List<Subscription>> getActive() async {
    final db = await _db.database;
    final rows = await db.query('subscriptions', where: 'is_active = 1', orderBy: 'next_billing_date ASC');
    return rows.map(Subscription.fromMap).toList();
  }

  Future<void> save(Subscription sub) async {
    final db = await _db.database;
    await db.insert('subscriptions', sub.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('subscriptions', where: 'id = ?', whereArgs: [id]);
  }

  /// 定期請求から請求書を生成
  Future<Invoice?> generateInvoice(Subscription sub, {DateTime? billingDate}) async {
    final date = billingDate ?? DateTime.now();
    final invoiceRepo = InvoiceRepository();

    // 明細テンプレートがあれば使用、なければ金額1行
    final items = sub.lineItems.isNotEmpty
        ? sub.lineItems.map((l) => InvoiceItem(
            description: l.description,
            quantity: l.quantity,
            unitPrice: l.unitPrice,
          )).toList()
        : [InvoiceItem(
            description: sub.description ?? '定期: ${sub.customerName}',
            quantity: 1,
            unitPrice: sub.amount,
          )];

    final invoice = Invoice(
      id: const Uuid().v4(),
      customer: Customer(id: sub.customerId, displayName: sub.customerName, formalName: sub.customerName),
      date: date,
      items: items,
      taxRate: 0.10,
      documentType: DocumentType.invoice,
      isDraft: true,
      subject: '定期請求 ${sub.customerName} #${sub.completedCycles + 1}',
    );
    await invoiceRepo.saveInvoice(invoice);

    // 完了回数を更新
    final updated = sub.copyWith(
      completedCycles: sub.completedCycles + 1,
      nextBillingDate: date.add(Duration(days: sub.cycleDays)),
      isActive: sub.totalCycles > 0 && sub.completedCycles + 1 >= sub.totalCycles ? false : true,
    );
    await save(updated);

    return invoice;
  }
}
