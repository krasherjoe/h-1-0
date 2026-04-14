import 'dart:io';
import 'package:flutter/material.dart' show debugPrint;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/customer_model.dart';
import '../services/database_helper.dart';
import '../services/activity_log_repository.dart';
import '../models/customer_model.dart' show HonorificCode;
import '../models/customer_contact.dart';
import 'hash_utils.dart';

class CustomerRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ActivityLogRepository _logRepo = ActivityLogRepository();

  Future<List<Customer>> getAllCustomers({bool includeHidden = false}) async {
    final db = await _dbHelper.database;
    final filter = includeHidden
        ? ''
        : 'WHERE COALESCE(mh.is_hidden, c.is_hidden, 0) = 0';
    List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT c.*, cc.address AS contact_address, cc.tel AS contact_tel, cc.email AS contact_email,
             COALESCE(mh.is_hidden, c.is_hidden, 0) AS is_hidden
      FROM customers c
      LEFT JOIN customer_contacts cc ON cc.customer_id = c.id AND cc.is_active = 1
      LEFT JOIN master_hidden mh ON mh.master_type = 'customer' AND mh.master_id = c.id
      $filter
      ORDER BY ${includeHidden ? 'c.id DESC' : 'c.display_name ASC'}
    ''');
    return List.generate(maps.length, (i) => Customer.fromMap(maps[i]));
  }

  /// カラムの存在をチェックして安全に追加するヘルパーメソッド
  Future<void> _safeAddColumn(
    Database db,
    String table,
    String columnDefinition,
  ) async {
    try {
      // カラムが既に存在するか確認
      final columns = await db.query(table, limit: 1);
      final columnName = columnDefinition.split(' ')[0];
      if (!columns.first.containsKey(columnName)) {
        await db.execute('ALTER TABLE $table ADD COLUMN $columnDefinition');
      }
    } catch (_) {
      // カラムが存在する場合は何もしない
    }
  }

  Future<void> ensureCustomerColumns() async {
    final db = await _dbHelper.database;
    await _safeAddColumn(db, 'customers', 'contact_version_id INTEGER');
    await _safeAddColumn(db, 'customers', 'head_char1 TEXT');
    await _safeAddColumn(db, 'customers', 'head_char2 TEXT');
  }

  /// 重複チェック（電話番号・メール・社名）
  /// 削除フラグ（is_hidden = 1）のデータと履歴テーブル（is_current = 0）のデータは除外
  /// excludeIdを指定すると、そのIDの顧客を除外してチェックする（編集時用）
  Future<bool> checkDuplicate({
    String? tel,
    String? email,
    String? name,
    String? excludeId,
  }) async {
    final db = await _dbHelper.database;

    // 電話番号で検索（customers テーブルの tel のみ参照）
    if (tel != null && tel.isNotEmpty) {
      String where = 'tel = ? AND is_hidden = 0 AND is_current = 1';
      List<dynamic> whereArgs = [tel];
      if (excludeId != null) {
        where += ' AND id != ?';
        whereArgs.add(excludeId);
      }
      final result = await db.query(
        'customers',
        where: where,
        whereArgs: whereArgs,
      );
      if (result.isNotEmpty) return true;
    }

    // メールで検索（customers テーブルの email のみ参照）
    if (email != null && email.isNotEmpty) {
      String where = 'email = ? AND is_hidden = 0 AND is_current = 1';
      List<dynamic> whereArgs = [email];
      if (excludeId != null) {
        where += ' AND id != ?';
        whereArgs.add(excludeId);
      }
      final result = await db.query(
        'customers',
        where: where,
        whereArgs: whereArgs,
      );
      if (result.isNotEmpty) return true;
    }

    // 社名（表示名・正式名称）で検索
    if (name != null && name.isNotEmpty) {
      String where = '(display_name LIKE ? OR formal_name LIKE ?) AND is_hidden = 0 AND is_current = 1';
      List<dynamic> whereArgs = ['%$name%', '%$name%'];
      if (excludeId != null) {
        where += ' AND id != ?';
        whereArgs.add(excludeId);
      }
      final result = await db.query(
        'customers',
        where: where,
        whereArgs: whereArgs,
      );
      if (result.isNotEmpty) return true;
    }

    return false;
  }

  /// HASH チェーン計算用ヘルパーメソッド
  Future<String> _calculateContentHash(Customer customer) async {
    // SHA256 = ID + All Field Values + valid_from + previous_hash
    return HashUtils.calculateCustomerHash(
      id: customer.id!,
      displayName: customer.displayName,
      formalName: customer.formalName,
      title: customer.title,
      department: customer.department,
      address: customer.address,
      tel: customer.tel,
      email: customer.email,
      contactVersionId: customer.contactVersionId,
      odooId: customer.odooId,
      isLocked: customer.isLocked,
      isHidden: customer.isHidden,
      headChar1: customer.headChar1,
      headChar2: customer.headChar2,
      validFrom: customer.validFrom,
      previousHash: customer.previousHash,
    );
  }

  Future<void> saveCustomer(Customer customer, {bool force = false}) async {
    final db = await _dbHelper.database;

    // 重複チェック（force=false の場合）
    // 編集時は自分自身を除外してチェック
    if (!force) {
      final isDuplicate = await checkDuplicate(
        tel: customer.tel,
        email: customer.email,
        name: customer.displayName,
        excludeId: customer.id,
      );

      if (isDuplicate) {
        throw DuplicateCustomerException(customer);
      }
    }

    await db.transaction((txn) async {
      // 既存の現行レコードを非現行化（履歴化）
      final existing = await txn.query(
        'customers',
        where: 'id = ? AND is_current = 1',
        whereArgs: [customer.id],
      );

      if (existing.isNotEmpty) {
        // 既存レコードを非現行化
        await txn.update(
          'customers',
          {'is_current': 0, 'valid_to': DateTime.now().toIso8601String()},
          where: 'id = ? AND is_current = 1',
          whereArgs: [customer.id],
        );
      }

      // 新しいバージョンとして INSERT（HASH チェーン計算）
      final customerMap = customer.toMap();
      final previousHash = existing.isNotEmpty
          ? existing.first['content_hash']
          : null;

      // HASH 計算
      final contentHash = await _calculateContentHash(customer);

      customerMap['content_hash'] = contentHash;
      customerMap['previous_hash'] = previousHash ?? '';
      customerMap['is_current'] = 1;
      final currentVersion =
          (existing.isNotEmpty ? existing.first['version'] : 0) as int? ?? 0;
      customerMap['version'] = currentVersion + 1;
      customerMap['valid_from'] = DateTime.now().toIso8601String();
      customerMap['valid_to'] = null;

      await txn.insert(
        'customers',
        customerMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _upsertActiveContact(txn, customer);
    });

    await _logRepo.logAction(
      action: "SAVE_CUSTOMER",
      targetType: "CUSTOMER",
      targetId: customer.id,
      details: "名称：${customer.formalName}, 敬称：${HonorificCode.toName(customer.title)} (version up)",
    );
  }

  Future<void> deleteCustomer(String id) async {
    final db = await _dbHelper.database;
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);

    await _logRepo.logAction(
      action: "DELETE_CUSTOMER",
      targetType: "CUSTOMER",
      targetId: id,
      details: "顧客を削除しました",
    );
  }

  // GPS履歴の保存 (直近10件を自動管理)
  Future<void> addGpsHistory(
    String customerId,
    double latitude,
    double longitude,
  ) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      // 履歴を追加
      await txn.insert('customer_gps_history', {
        'customer_id': customerId,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': now,
      });

      // 10件を超えた古い履歴を削除
      await txn.execute(
        '''
        DELETE FROM customer_gps_history 
        WHERE id IN (
          SELECT id FROM customer_gps_history 
          WHERE customer_id = ? 
          ORDER BY timestamp DESC 
          LIMIT -1 OFFSET 10
        )
      ''',
        [customerId],
      );
    });
  }

  Future<List<Map<String, dynamic>>> getGpsHistory(String customerId) async {
    final db = await _dbHelper.database;
    return await db.query(
      'customer_gps_history',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'timestamp DESC',
    );
  }

  Future<List<Customer>> searchCustomers(
    String query, {
    bool includeHidden = false,
  }) async {
    final db = await _dbHelper.database;
    final where = includeHidden
        ? ''
        : 'AND COALESCE(mh.is_hidden, c.is_hidden, 0) = 0';
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT c.*, cc.address AS contact_address, cc.tel AS contact_tel, cc.email AS contact_email,
             COALESCE(mh.is_hidden, c.is_hidden, 0) AS is_hidden
      FROM customers c
      LEFT JOIN customer_contacts cc ON cc.customer_id = c.id AND cc.is_active = 1
      LEFT JOIN master_hidden mh ON mh.master_type = 'customer' AND mh.master_id = c.id
      WHERE (c.display_name LIKE ? OR c.formal_name LIKE ?) $where
      ORDER BY ${includeHidden ? 'c.id DESC' : 'c.display_name ASC'}
      LIMIT 50
    ''',
      ['%$query%', '%$query%'],
    );
    return List.generate(maps.length, (i) => Customer.fromMap(maps[i]));
  }

  Future<void> updateContact({
    required String customerId,
    String? email,
    String? tel,
    String? address,
  }) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final nextVersion = await _nextContactVersion(txn, customerId);
      await txn.update(
        'customer_contacts',
        {'is_active': 0},
        where: 'customer_id = ?',
        whereArgs: [customerId],
      );
      await txn.insert('customer_contacts', {
        'id': Uuid().v4(),
        'customer_id': customerId,
        'email': email,
        'tel': tel,
        'address': address,
        'version': nextVersion,
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
    });

    await _logRepo.logAction(
      action: "UPDATE_CUSTOMER_CONTACT",
      targetType: "CUSTOMER",
      targetId: customerId,
      details: "連絡先を更新 (version up)",
    );
  }

  Future<CustomerContact?> getActiveContact(String customerId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'customer_contacts',
      where: 'customer_id = ? AND is_active = 1',
      whereArgs: [customerId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CustomerContact.fromMap(rows.first);
  }

  Future<Customer?> getById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return Customer.fromMap(maps.first);
  }

  Future<void> setHidden(String id, bool hidden) async {
    final db = await _dbHelper.database;
    await db.insert('master_hidden', {
      'master_type': 'customer',
      'master_id': id,
      'is_hidden': hidden ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _logRepo.logAction(
      action: hidden ? "HIDE_CUSTOMER" : "UNHIDE_CUSTOMER",
      targetType: "CUSTOMER",
      targetId: id,
      details: hidden ? "顧客を非表示にしました" : "顧客を再表示しました",
    );
  }

  Future<int> _nextContactVersion(
    DatabaseExecutor txn,
    String customerId,
  ) async {
    final res = await txn.rawQuery(
      'SELECT MAX(version) as v FROM customer_contacts WHERE customer_id = ?',
      [customerId],
    );
    final current = res.first['v'] as int?;
    return (current ?? 0) + 1;
  }

  Future<void> _upsertActiveContact(
    DatabaseExecutor txn,
    Customer customer,
  ) async {
    final nextVersion = await _nextContactVersion(txn, customer.id);
    await txn.update(
      'customer_contacts',
      {'is_active': 0},
      where: 'customer_id = ?',
      whereArgs: [customer.id],
    );
    await txn.insert('customer_contacts', {
      'id': Uuid().v4(),
      'customer_id': customer.id,
      'email': customer.email,
      'tel': customer.tel,
      'address': customer.address,
      'version': nextVersion,
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
