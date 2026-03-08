import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';

import '../models/customer_model.dart';
import '../models/quotation_model.dart';
import '../widgets/document_card.dart';
import 'customer_repository.dart';
import 'database_helper.dart';

/// 見積リポジトリ
class QuotationRepository {
  final DatabaseHelper _db = DatabaseHelper();
  final CustomerRepository _customerRepo = CustomerRepository();

  /// すべての見積を取得
  Future<List<Quotation>> getAllQuotations() async {
    final database = await _db.database;
    final customers = await _customerRepo.getAllCustomers();
    
    final maps = await database.query(
      'quotations',
      orderBy: 'date DESC',
    );

    return maps.map((map) {
      final customerId = map['customer_id'] as String?;
      final customer = customerId != null
          ? customers.firstWhere(
              (c) => c.id == customerId,
              orElse: () => Customer(
                id: customerId,
                displayName: '不明な顧客',
                formalName: '不明な顧客',
              ),
            )
          : null;

      return Quotation.fromMap(map, customer);
    }).toList();
  }

  /// 見積を保存
  Future<void> saveQuotation(Quotation quotation) async {
    final database = await _db.database;
    await database.insert(
      'quotations',
      quotation.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // 明細を保存
    await database.delete(
      'quotation_items',
      where: 'quotation_id = ?',
      whereArgs: [quotation.id],
    );

    for (final item in quotation.items) {
      await database.insert(
        'quotation_items',
        {
          ...item.toMap(),
          'quotation_id': quotation.id,
        },
      );
    }
  }

  /// 見積を削除
  Future<void> deleteQuotation(String id) async {
    final database = await _db.database;
    await database.delete(
      'quotations',
      where: 'id = ?',
      whereArgs: [id],
    );
    await database.delete(
      'quotation_items',
      where: 'quotation_id = ?',
      whereArgs: [id],
    );
  }

  /// 見積をコピー
  Future<Quotation> copyQuotation(Quotation original) async {
    final newQuotation = original.copyWith(
      id: const Uuid().v4(),
      documentNumber: await _generateDocumentNumber(),
      date: DateTime.now(),
      status: DocumentStatus.draft,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await saveQuotation(newQuotation);
    return newQuotation;
  }

  /// 見積を受注に変換
  Future<void> convertToOrder(Quotation quotation) async {
    // TODO: 受注モデルを実装後に実装
    throw UnimplementedError('受注変換機能は今後実装予定です');
  }

  /// 伝票番号を生成
  Future<String> _generateDocumentNumber() async {
    final database = await _db.database;
    final now = DateTime.now();
    final prefix = 'Q${now.year}${now.month.toString().padLeft(2, '0')}';
    
    final result = await database.rawQuery(
      'SELECT COUNT(*) as count FROM quotations WHERE document_number LIKE ?',
      ['$prefix%'],
    );
    
    final count = result.first['count'] as int;
    return '$prefix-${(count + 1).toString().padLeft(4, '0')}';
  }
}
