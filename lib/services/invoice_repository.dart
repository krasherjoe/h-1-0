import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../models/invoice_models.dart';
import '../models/customer_model.dart';
import '../models/customer_contact.dart';
import '../models/invoice_sync_payload.dart';
import 'database_helper.dart';
import 'activity_log_repository.dart';
import 'company_repository.dart';
import 'storage_monitor.dart';

/// 在庫処理の除外対象とする商品カテゴリ名
/// サービスやサポート系の有形財でない品目は在庫引当/減算を行わない
const List<String> kNonStockCategories = <String>['サポート', 'サービス'];

class InvoiceRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ActivityLogRepository _logRepo = ActivityLogRepository();
  final CompanyRepository _companyRepo = CompanyRepository();
  final StorageMonitor _storageMonitor = StorageMonitor();
  final StreamController<List<Invoice>> _orderStreamController = StreamController.broadcast();

  /// 指定された商品が在庫処理除外カテゴリに属するか判定
  /// （カテゴリ名が「サポート」「サービス」の場合はtrue）
  Future<bool> _isNonStockProduct(DatabaseExecutor txn, String productId) async {
    final rows = await txn.query(
      'products',
      columns: ['category'],
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final category = (rows.first['category'] as String?)?.trim();
    if (category == null || category.isEmpty) return false;
    return kNonStockCategories.contains(category);
  }

  Future<void> saveInvoice(Invoice invoice) async {
    // 容量チェック
    if (!await _storageMonitor.canWrite()) {
      throw Exception('ストレージ容量不足のため保存できません');
    }

    final db = await _dbHelper.database;

    // 正式発行（下書きでない）場合はロックを掛ける
    final companyInfo = await _companyRepo.getCompanyInfo();
    String? sealHash;
    if (companyInfo.sealPath != null) {
      final file = File(companyInfo.sealPath!);
      if (await file.exists()) {
        sealHash = sha256.convert(await file.readAsBytes()).toString();
      }
    }
    final companySnapshot = jsonEncode({
      'name': companyInfo.name,
      'zipCode': companyInfo.zipCode,
      'address': companyInfo.address,
      'tel': companyInfo.tel,
      'fax': companyInfo.fax,
      'email': companyInfo.email,
      'url': companyInfo.url,
      'defaultTaxRate': companyInfo.defaultTaxRate,
      'taxDisplayMode': companyInfo.taxDisplayMode,
      'registrationNumber': companyInfo.registrationNumber,
    });

    final Invoice toSave = invoice.isDraft ? invoice : invoice.copyWith(isLocked: true);

    await db.transaction((txn) async {
      // 最新の連絡先をスナップショットする（なければ空）
      CustomerContact? activeContact;
      final contactRows = await txn.query('customer_contacts', where: 'customer_id = ? AND is_active = 1', whereArgs: [invoice.customer.id]);
      if (contactRows.isNotEmpty) {
        activeContact = CustomerContact.fromMap(contactRows.first);
      }
      final Invoice savingWithContact = toSave.copyWith(
        contactVersionId: activeContact?.version,
        contactEmailSnapshot: activeContact?.email,
        contactTelSnapshot: activeContact?.tel,
        contactAddressSnapshot: activeContact?.address,
        companySnapshot: companySnapshot,
        companySealHash: sealHash,
        metaJson: null,
        metaHash: null,
        isSynced: false,
        updatedAt: DateTime.now(),
      );

      final bool adjustStockOnSave =
          invoice.documentType != DocumentType.order || invoice.orderStatus != OrderStatus.draft;

      if (adjustStockOnSave) {
        // 在庫の調整（更新の場合、以前の数量を戻してから新しい数量を引く）
        final List<Map<String, dynamic>> oldItems = await txn.query(
          'invoice_items',
          where: 'invoice_id = ?',
          whereArgs: [invoice.id],
        );

        // 旧在庫を戻す（サポート/サービスカテゴリは在庫対象外のためスキップ）
        for (var item in oldItems) {
          final pid = item['product_id'] as String?;
          if (pid == null) continue;
          if (await _isNonStockProduct(txn, pid)) continue;
          await txn.execute(
            'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
            [item['quantity'], pid],
          );
        }
      }

      // 伝票ヘッダーの保存
      await txn.insert(
        'invoices',
        savingWithContact.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 既存の明細を一旦削除
      await txn.delete(
        'invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [invoice.id],
      );

      // 新しい明細の保存と在庫の減算（サポート/サービスカテゴリは在庫対象外）
      for (var item in invoice.items) {
        await txn.insert('invoice_items', item.toMap(invoice.id));
        if (adjustStockOnSave && item.productId != null) {
          final bool isNonStock = await _isNonStockProduct(txn, item.productId!);
          if (!isNonStock) {
            await txn.execute(
              'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
              [item.quantity, item.productId],
            );
          }
          if (!invoice.isDraft) {
            await txn.execute('UPDATE products SET is_locked = 1 WHERE id = ?', [item.productId]);
          }
        }
      }

      // 顧客をロック
      if (!invoice.isDraft) {
        await txn.execute('UPDATE customers SET is_locked = 1 WHERE id = ?', [invoice.customer.id]);
      }
    });

    await _logRepo.logAction(
      action: "SAVE_INVOICE",
      targetType: "INVOICE",
      targetId: invoice.id,
      details: "種別: ${invoice.documentTypeName}, 取引先: ${invoice.customerNameForDisplay}, 合計: ￥${invoice.totalAmount}",
    );
  }

  Future<void> updateInvoice(Invoice invoice) async {
    await saveInvoice(invoice);
  }

  Future<List<Invoice>> getOrders(List<Customer> customers, {OrderStatus? status}) async {
    final orders = await getAllInvoices(customers, documentTypeFilter: DocumentType.order);
    if (status == null) return orders;
    return orders.where((order) => order.orderStatus == status).toList();
  }

  Stream<List<Invoice>> watchOrders(List<Customer> customers, {OrderStatus? status}) {
    _refreshOrders(customers, status: status);
    return _orderStreamController.stream;
  }

  Future<void> _refreshOrders(List<Customer> customers, {OrderStatus? status}) async {
    final orders = await getOrders(customers, status: status);
    _orderStreamController.add(orders);
  }

  Future<void> updateOrderStatus(
    String id,
    OrderStatus status, {
    DateTime? fulfilledDate,
    String? linkedDeliveryId,
    String? linkedInvoiceId,
  }) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'invoices',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw Exception('order_not_found');
      }
      final row = rows.first;
      if (row['document_type'] != DocumentType.order.name) {
        throw Exception('not_order_document');
      }

      OrderStatus currentStatus = OrderStatus.draft;
      final statusRaw = row['order_status'];
      if (statusRaw is String) {
        currentStatus = OrderStatus.values.firstWhere(
          (e) => e.name == statusRaw,
          orElse: () => OrderStatus.draft,
        );
      }

      final bool leavingDraft = currentStatus == OrderStatus.draft && status != OrderStatus.draft;
      if (leavingDraft) {
        final itemRows = await txn.query('invoice_items', where: 'invoice_id = ?', whereArgs: [id]);
        for (final item in itemRows) {
          final productId = item['product_id'] as String?;
          if (productId == null) continue;
          final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
          if (quantity == 0) continue;
          // サポート/サービスカテゴリは在庫対象外のため減算しない
          if (!await _isNonStockProduct(txn, productId)) {
            await txn.execute(
              'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
              [quantity, productId],
            );
          }
          await txn.execute('UPDATE products SET is_locked = 1 WHERE id = ?', [productId]);
        }
        await txn.execute('UPDATE customers SET is_locked = 1 WHERE id = ?', [row['customer_id']]);
      }

      DateTime? fulfilledAt = fulfilledDate;
      if (status == OrderStatus.fulfilled && fulfilledAt == null) {
        fulfilledAt = DateTime.now();
      }

      final updateValues = <String, Object?>{
        'order_status': status.name,
        'fulfilled_date': fulfilledAt?.millisecondsSinceEpoch,
        'updated_at': DateTime.now().toIso8601String(),
        'is_locked': status == OrderStatus.draft ? row['is_locked'] : 1,
      };
      if (linkedDeliveryId != null) {
        updateValues['linked_delivery_id'] = linkedDeliveryId;
      }
      if (linkedInvoiceId != null) {
        updateValues['linked_invoice_id'] = linkedInvoiceId;
      }

      await txn.update('invoices', updateValues, where: 'id = ?', whereArgs: [id]);
    });

    await _logRepo.logAction(
      action: 'UPDATE_ORDER_STATUS',
      targetType: 'INVOICE',
      targetId: id,
      details: '受注ステータスを ${status.label} に更新',
    );
  }

  Future<List<Invoice>> getAllInvoices(List<Customer> customers, {DocumentType? documentTypeFilter}) async {
    final db = await _dbHelper.database;
    final where = documentTypeFilter != null ? 'document_type = ?' : null;
    final whereArgs = documentTypeFilter != null ? [documentTypeFilter.name] : null;
    final List<Map<String, dynamic>> invoiceMaps = await db.query(
      'invoices',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'date DESC',
    );

    List<Invoice> invoices = [];
    DateTime? _mapEpoch(dynamic value) {
      if (value == null) return null;
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      if (value is String) {
        final asInt = int.tryParse(value);
        if (asInt != null) {
          return DateTime.fromMillisecondsSinceEpoch(asInt);
        }
        return DateTime.tryParse(value);
      }
      return null;
    }

    for (var iMap in invoiceMaps) {
      final customer = customers.firstWhere(
        (c) => c.id == iMap['customer_id'],
        orElse: () => Customer(id: iMap['customer_id'], displayName: "不明", formalName: "不明"),
      );

      final List<Map<String, dynamic>> itemMaps = await db.query(
        'invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [iMap['id']],
      );

      final items = List.generate(itemMaps.length, (i) => InvoiceItem.fromMap(itemMaps[i]));

      // document_typeのパース
      DocumentType docType = DocumentType.invoice;
      final docTypeRaw = iMap['document_type'];
      if (docTypeRaw is String) {
        try {
          docType = DocumentType.values.firstWhere((e) => e.name == docTypeRaw);
        } catch (_) {}
      }

      OrderStatus orderStatus = OrderStatus.draft;
      final statusRaw = iMap['order_status'];
      if (statusRaw is String) {
        try {
          orderStatus = OrderStatus.values.firstWhere((e) => e.name == statusRaw);
        } catch (_) {}
      }

      invoices.add(Invoice(
        id: iMap['id'],
        customer: customer,
        date: DateTime.parse(iMap['date']),
        items: items,
        notes: iMap['notes'],
        filePath: iMap['file_path'],
        taxRate: iMap['tax_rate'] ?? 0.10,
        documentType: docType,
        orderStatus: orderStatus,
        promisedDate: _mapEpoch(iMap['promised_date']),
        fulfilledDate: _mapEpoch(iMap['fulfilled_date']),
        sourceDocumentId: iMap['source_document_id'],
        linkedDeliveryId: iMap['linked_delivery_id'],
        linkedInvoiceId: iMap['linked_invoice_id'],
        customerFormalNameSnapshot: iMap['customer_formal_name'],
        odooId: iMap['odoo_id'],
        isSynced: iMap['is_synced'] == 1,
        updatedAt: DateTime.parse(iMap['updated_at']),
        latitude: iMap['latitude'],
        longitude: iMap['longitude'],
        terminalId: iMap['terminal_id'] ?? "T1",
        isDraft: (iMap['is_draft'] ?? 0) == 1,
        subject: iMap['subject'],
        isLocked: (iMap['is_locked'] ?? 0) == 1,
        contactVersionId: iMap['contact_version_id'],
        contactEmailSnapshot: iMap['contact_email_snapshot'],
        contactTelSnapshot: iMap['contact_tel_snapshot'],
        contactAddressSnapshot: iMap['contact_address_snapshot'],
        companySnapshot: iMap['company_snapshot'],
        companySealHash: iMap['company_seal_hash'],
        metaJson: iMap['meta_json'],
        metaHash: iMap['meta_hash'],
        totalDiscountAmount: iMap['total_discount_amount'],
        totalDiscountRate: iMap['total_discount_rate'],
        isReceiptIssued: (iMap['is_receipt_issued'] ?? 0) == 1,
        receiptIssuedAt: iMap['receipt_issued_at'] != null ? DateTime.tryParse(iMap['receipt_issued_at']) : null,
        priceAdjustmentType: iMap['price_adjustment_type'] as String?,
        priceAdjustmentUnit: iMap['price_adjustment_unit'] as int?,
        includeTax: (iMap['include_tax'] ?? 1) == 1,
      ));
    }
    return invoices;
  }

  Future<void> deleteInvoice(String id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // 在庫の復元
      final List<Map<String, dynamic>> items = await txn.query(
        'invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [id],
      );

      for (var item in items) {
        final pid = item['product_id'] as String?;
        if (pid == null) continue;
        // サポート/サービスカテゴリは在庫対象外のため復元しない
        if (await _isNonStockProduct(txn, pid)) continue;
        await txn.execute(
          'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
          [item['quantity'], pid],
        );
      }

      // PDFパスの取得（削除用）
      final List<Map<String, dynamic>> maps = await txn.query(
        'invoices',
        columns: ['file_path'],
        where: 'id = ?',
        whereArgs: [id],
      );
      
      if (maps.isNotEmpty && maps.first['file_path'] != null) {
        final file = File(maps.first['file_path']);
        if (await file.exists()) {
          await file.delete();
        }
      }

      await txn.delete(
        'invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'invoices',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<int> cleanupOrphanedPdfs() async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) return 0;

      final files = directory.listSync().whereType<File>().toList();
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> results = await db.query('invoices', columns: ['file_path']);
      final activePaths = results.map((r) => r['file_path'] as String?).where((p) => p != null).toSet();

      int count = 0;
      for (var file in files) {
        if (file.path.endsWith('.pdf') && !activePaths.contains(file.path)) {
          await file.delete();
          count++;
        }
      }
      return count;
    } catch (e) {
      return 0;
    }
  }

  /// meta_json と meta_hash の整合性を検証する（trueなら一致）。
  bool verifyInvoiceMeta(Invoice invoice) {
    final metaJson = invoice.metaJson ?? invoice.metaJsonValue;
    final expected = sha256.convert(utf8.encode(metaJson)).toString();
    final stored = invoice.metaHash ?? expected;
    return expected == stored;
  }

  /// IDを指定してDBから取得し、メタデータ整合性を検証する。
  Future<bool> verifyInvoiceMetaById(String id, List<Customer> customers) async {
    final invoices = await getAllInvoices(customers);
    final target = invoices.firstWhere((i) => i.id == id, orElse: () => throw Exception('invoice not found'));
    return verifyInvoiceMeta(target);
  }

  Future<Map<String, int>> getMonthlySales(int year) async {
    final db = await _dbHelper.database;
    final String yearStr = year.toString();
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT strftime('%m', date) as month, SUM(total_amount) as total
      FROM invoices
      WHERE strftime('%Y', date) = ? AND document_type = 'invoice'
      GROUP BY month
      ORDER BY month ASC
    ''', [yearStr]);

    Map<String, int> monthlyTotal = {};
    for (var r in results) {
      monthlyTotal[r['month']] = (r['total'] as num).toInt();
    }
    return monthlyTotal;
  }

  Future<int> getYearlyTotal(int year) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT SUM(total_amount) as total
      FROM invoices
      WHERE strftime('%Y', date) = ? AND document_type = 'invoice'
    ''', [year.toString()]);

    if (results.isEmpty || results.first['total'] == null) return 0;
    return (results.first['total'] as num).toInt();
  }

  Future<List<InvoiceSyncSnapshot>> pendingSyncSnapshots({int limit = 10}) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'invoices',
      where: 'is_synced = 0',
      orderBy: 'updated_at ASC',
      limit: limit,
    );
    final snapshots = <InvoiceSyncSnapshot>[];
    for (final row in rows) {
      final items = await db.query(
        'invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [row['id']],
      );
      snapshots.add(InvoiceSyncSnapshot(invoiceRow: row, items: items));
    }
    return snapshots;
  }

  Future<void> markSynced(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await _dbHelper.database;
    await db.update(
      'invoices',
      {'is_synced': 1},
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
  }

  Future<void> applyInboundSnapshot(InvoiceSyncPayload payload) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      DateTime? currentUpdatedAt;
      final existing = await txn.query(
        'invoices',
        where: 'id = ?',
        whereArgs: [payload.recordId],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final existingUpdatedAt = existing.first['updated_at'];
        if (existingUpdatedAt is String) {
          currentUpdatedAt = DateTime.tryParse(existingUpdatedAt);
        }
      }
      final inboundUpdatedAt = DateTime.tryParse(payload.updatedAt);
      if (currentUpdatedAt != null && inboundUpdatedAt != null && !inboundUpdatedAt.isAfter(currentUpdatedAt)) {
        return;
      }

      final row = Map<String, dynamic>.from(payload.invoiceRow);
      row['id'] = payload.recordId;
      row['updated_at'] = payload.updatedAt;
      row['is_synced'] = 1;
      await txn.insert('invoices', row, conflictAlgorithm: ConflictAlgorithm.replace);

      await txn.delete('invoice_items', where: 'invoice_id = ?', whereArgs: [payload.recordId]);
      for (final item in payload.items) {
        final copy = Map<String, dynamic>.from(item);
        copy['invoice_id'] = payload.recordId;
        copy['id'] ??= DateTime.now().microsecondsSinceEpoch.toString();
        await txn.insert('invoice_items', copy, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
}
