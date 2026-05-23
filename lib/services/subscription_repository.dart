import 'package:sqflite/sqflite.dart';
import '../models/subscription_model.dart';
import 'database_helper.dart';

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
}
