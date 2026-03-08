import '../models/delivery_model.dart';
import '../models/customer_model.dart';
import 'database_helper.dart';
import 'customer_repository.dart';

class DeliveryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final CustomerRepository _customerRepo = CustomerRepository();

  Future<List<Delivery>> getAll() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'deliveries',
      orderBy: 'date DESC',
    );

    final List<Delivery> deliveries = [];
    for (var map in maps) {
      Customer? customer;
      if (map['customer_id'] != null) {
        customer = await _customerRepo.getById(map['customer_id'] as String);
      }
      deliveries.add(Delivery.fromMap(map, customer));
    }
    return deliveries;
  }

  Future<Delivery?> getById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'deliveries',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;

    Customer? customer;
    if (maps.first['customer_id'] != null) {
      customer = await _customerRepo.getById(maps.first['customer_id'] as String);
    }

    return Delivery.fromMap(maps.first, customer);
  }

  Future<void> insert(Delivery delivery) async {
    final db = await _dbHelper.database;
    await db.insert('deliveries', delivery.toMap());
  }

  Future<void> update(Delivery delivery) async {
    final db = await _dbHelper.database;
    await db.update(
      'deliveries',
      delivery.toMap(),
      where: 'id = ?',
      whereArgs: [delivery.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'deliveries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
