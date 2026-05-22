import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/invoice_models.dart';
import '../models/customer_model.dart';
import '../models/customer_contact.dart';
import '../models/invoice_sync_payload.dart';
import '../models/receipt_model.dart';
import '../models/payment_schedule_model.dart' show PaymentStatus;
import 'database_helper.dart';
import 'activity_log_repository.dart';
import 'company_repository.dart';
import 'electronic_ledger_repository.dart';
import 'storage_monitor.dart';
import 'customer_repository.dart';

/// 在庫処理の除外対象とする商品カテゴリ名
/// サービスやサポート系の有形財でない品目は在庫引当/減算を行わない
const List<String> kNonStockCategories = <String>['サポート', 'サービス'];

/// ハッシュチェーン検証結果
class HashChainVerifyResult {
  /// 検証した伝票件数
  final int checked;
  /// 改ざんが検出された伝票IDのリスト（空なら健全）
  final List<String> brokenIds;
  /// 検証実行日時
  final DateTime verifiedAt;

  HashChainVerifyResult({
    required this.checked,
    required this.brokenIds,
    required this.verifiedAt,
  });

  bool get isHealthy => brokenIds.isEmpty;
  int get brokenCount => brokenIds.length;
}

class InvoiceRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ActivityLogRepository _logRepo = ActivityLogRepository();
  final CompanyRepository _companyRepo = CompanyRepository();
  final ElectronicLedgerRepository _ledgerRepo = ElectronicLedgerRepository();
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

    // ===== ハッシュチェーン保護 =====
    // 既存レコードを確認し、ロック済みの場合は絶対に上書き禁止
    // これによりロック済み伝票の content_hash/meta_hash/meta_json が壊れることを防ぐ
    final existing = await db.query(
      'invoices',
      columns: ['id', 'is_locked', 'meta_hash', 'content_hash'],
      where: 'id = ?',
      whereArgs: [invoice.id],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final existingIsLocked = (existing.first['is_locked'] as int? ?? 0) == 1;
      if (existingIsLocked) {
        throw Exception(
          'ハッシュチェーン保護: ロック済み伝票 ${invoice.id} は変更できません。'
          '\n複写または新規IDで保存してください。',
        );
      }
    }
    // ===============================

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

      // 領収書保存時に元請求書のisReceiptIssuedフラグを自動更新
      if (invoice.documentType == DocumentType.receipt && invoice.sourceDocumentId != null) {
        await txn.update(
          'invoices',
          {
            'is_receipt_issued': 1,
            'receipt_issued_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [invoice.sourceDocumentId],
        );
      }
    });

    await _logRepo.logAction(
      action: "SAVE_INVOICE",
      targetType: "INVOICE",
      targetId: invoice.id,
      details: "種別: ${invoice.documentTypeName}, 取引先: ${invoice.customerNameForDisplay}, 合計: ￥${invoice.totalAmount}",
    );

    // ===== 電子帳簿保存法: electronic_ledgersへ追記 =====
    // 正式発行時（下書きでない）に電子帳簿テーブルへ記録
    // saveElectronicLedger は追記INSERTのみ（更新禁止）
    if (!invoice.isDraft) {
      try {
        await _ledgerRepo.saveElectronicLedger(
          documentId: invoice.id,
          documentType: invoice.documentTypeName,
          documentData: invoice.toMap(),
          createdAt: invoice.date,
        );
      } catch (e) {
        // 重複INSERTはスキップ（2回目以降の呼び出し防止）
        // タイムスタンプ異常はログ記録してベストエフォート継続
        await _logRepo.logAction(
          action: 'ELECTRONIC_LEDGER_SAVE_ERROR',
          targetType: 'INVOICE',
          targetId: invoice.id,
          details: '電子帳簿保存エラー: $e',
        );
      }
    }
    // =================================================

    // ===== Tail-5 ハッシュチェーン検証 =====
    // ロック保存後、直近5件のハッシュチェーン整合性を軽量検証
    // SHA-256 × 5 ≈ 数ms でバッテリー消費極小
    if (!invoice.isDraft) {
      try {
        final result = await verifyTailN(n: 5);
        if (!result.isHealthy) {
          await _logRepo.logAction(
            action: "HASH_CHAIN_BROKEN",
            targetType: "INVOICE",
            targetId: result.brokenIds.join(','),
            details: "Tail-5検証で改ざん検出: ${result.brokenCount}件 / 検証${result.checked}件",
          );
        }
      } catch (_) {
        // 検証失敗は保存自体は成功させる（ベストエフォート）
      }
    }
    // =====================================
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

      PaymentStatus paymentStatus = PaymentStatus.unpaid;
      final psRaw = iMap['payment_status'];
      if (psRaw is String) {
        try {
          paymentStatus = PaymentStatus.values.firstWhere((e) => e.name == psRaw);
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
        paymentStatus: paymentStatus,
        receivedAmount: iMap['received_amount'] as int? ?? 0,
        priceAdjustmentType: iMap['price_adjustment_type'] as String?,
        priceAdjustmentUnit: iMap['price_adjustment_unit'] as int?,
        bankAccount: iMap['bank_account'] as String?,
        projectId: iMap['project_id'] as String?,
        includeTax: (iMap['include_tax'] ?? 1) == 1,
        isTaxInclusiveMode: (iMap['is_tax_inclusive_mode'] ?? 0) == 1,
        isTestDocument: (iMap['is_test_document'] ?? 0) == 1,
      ));
    }
    return invoices;
  }

  /// 指定したsourceDocumentIdに紐づく領収書を取得する（請求書→領収書の紐付け確認用）
  Future<Invoice?> getReceiptBySourceDocumentId(String sourceDocumentId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'invoices',
      where: 'source_document_id = ? AND document_type = ?',
      whereArgs: [sourceDocumentId, DocumentType.receipt.name],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final customerRepo = CustomerRepository();
    final customers = await customerRepo.getAllCustomers();
    final allInvoices = await getAllInvoices(customers);
    try {
      return allInvoices.firstWhere((i) => i.id == rows.first['id']);
    } catch (_) {
      return null;
    }
  }

  /// 全請求書の領収書発行状態を一括同期（既存DBの整合性修復用）
  Future<int> syncAllReceiptStatus() async {
    final db = await _dbHelper.database;
    int updatedCount = 0;

    // 領収書として保存されているsource_document_id一覧を取得
    final receiptRows = await db.query(
      'invoices',
      columns: ['source_document_id'],
      where: 'document_type = ? AND source_document_id IS NOT NULL',
      whereArgs: [DocumentType.receipt.name],
    );

    final Set<String> linkedInvoiceIds = receiptRows
        .map((r) => r['source_document_id'] as String?)
        .where((id) => id != null)
        .cast<String>()
        .toSet();

    // 各請求書のis_receipt_issuedを更新
    for (final invoiceId in linkedInvoiceIds) {
      final result = await db.update(
        'invoices',
        {
          'is_receipt_issued': 1,
          'receipt_issued_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND (is_receipt_issued = 0 OR is_receipt_issued IS NULL)',
        whereArgs: [invoiceId],
      );
      updatedCount += result;
    }

    return updatedCount;
  }

  /// 指定したprojectIdに紐づく伝票を取得する（案件管理用）
  Future<List<Invoice>> getInvoicesByProjectId(String projectId, List<Customer> customers) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'invoices',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'date DESC',
    );
    if (rows.isEmpty) return [];
    final allInvoices = await getAllInvoices(customers);
    return allInvoices.where((i) => rows.any((r) => r['id'] == i.id)).toList();
  }

  /// 指定したprojectIdに紐づく伝票の合計金額を集計（案件管理用）
  Future<int> getTotalAmountByProjectId(String projectId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT SUM(total_amount) as total FROM invoices WHERE project_id = ?',
      [projectId],
    );
    if (result.isEmpty || result.first['total'] == null) return 0;
    return (result.first['total'] as num).toInt();
  }

  Future<void> deleteInvoice(String id) async {
    final db = await _dbHelper.database;

    // ===== ハッシュチェーン保護: ロック済み伝票の物理削除禁止 =====
    final lockCheck = await db.query(
      'invoices',
      columns: ['is_locked'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (lockCheck.isNotEmpty && (lockCheck.first['is_locked'] as int? ?? 0) == 1) {
      throw Exception(
        'ハッシュチェーン保護: ロック済み伝票 $id は削除できません。'
        '\n訂正が必要な場合は赤伝（訂正伝票）を作成してください。',
      );
    }
    // ==========================================================

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

  // ===== 入金・売上リレーション =====

  /// 請求書IDに紐づく入金実績を取得
  Future<List<Receipt>> getReceiptsByInvoiceId(String invoiceId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'receipts',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
      orderBy: 'receipt_date DESC',
    );
    return rows.map((r) => Receipt.fromMap(r)).toList();
  }

  /// 入金実績を追加し、請求書の入金ステータスを自動更新
  Future<void> addReceipt(Receipt receipt) async {
    final db = await _dbHelper.database;

    // 1. 入金実績をINSERT
    await db.insert('receipts', receipt.toMap());

    // 2. 同じ請求書の全入金実績を集計
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM receipts WHERE invoice_id = ?',
      [receipt.invoiceId],
    );
    final totalReceived = (result.first['total'] as num?)?.toInt() ?? 0;

    // 3. 請求書金額を取得
    final invoiceResult = await db.query(
      'invoices',
      columns: ['total_amount'],
      where: 'id = ?',
      whereArgs: [receipt.invoiceId],
      limit: 1,
    );
    if (invoiceResult.isEmpty) return;
    final totalAmount = invoiceResult.first['total_amount'] as int? ?? 0;

    // 4. ステータス計算
    final String newStatus;
    if (totalReceived >= totalAmount) {
      newStatus = PaymentStatus.paid.name;
    } else if (totalReceived > 0) {
      newStatus = PaymentStatus.partial.name;
    } else {
      newStatus = PaymentStatus.unpaid.name;
    }

    // 5. 請求書をUPDATE
    await db.update(
      'invoices',
      {
        'payment_status': newStatus,
        'received_amount': totalReceived,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [receipt.invoiceId],
    );

    // 6. ログ記録
    await _logRepo.logAction(
      action: 'ADD_RECEIPT',
      targetType: 'INVOICE',
      targetId: receipt.invoiceId,
      details: '入金額: \u00a5$totalReceived / 請求額: \u00a5$totalAmount, ステータス: $newStatus',
    );
  }

  /// 請求書の入金ステータスを入金実績から再計算して更新
  Future<void> updatePaymentStatus(String invoiceId) async {
    final db = await _dbHelper.database;

    final receiptResult = await db.rawQuery(
      'SELECT SUM(amount) as total FROM receipts WHERE invoice_id = ?',
      [invoiceId],
    );
    final totalReceived = (receiptResult.first['total'] as num?)?.toInt() ?? 0;

    final invoiceResult = await db.query(
      'invoices',
      columns: ['total_amount'],
      where: 'id = ?',
      whereArgs: [invoiceId],
      limit: 1,
    );
    if (invoiceResult.isEmpty) return;
    final totalAmount = invoiceResult.first['total_amount'] as int? ?? 0;

    final String newStatus;
    if (totalReceived >= totalAmount) {
      newStatus = PaymentStatus.paid.name;
    } else if (totalReceived > 0) {
      newStatus = PaymentStatus.partial.name;
    } else {
      newStatus = PaymentStatus.unpaid.name;
    }

    await db.update(
      'invoices',
      {
        'payment_status': newStatus,
        'received_amount': totalReceived,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
  }

  /// 請求書IDに紐づく売上伝票を取得
  Future<List<Map<String, dynamic>>> getSalesByInvoiceId(String invoiceId) async {
    final db = await _dbHelper.database;
    return await db.query(
      'sales',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
      orderBy: 'date DESC',
    );
  }

  /// 請求書に紐づく売上伝票が存在するか
  Future<bool> hasSales(String invoiceId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM sales WHERE invoice_id = ?',
      [invoiceId],
    );
    return (result.first['count'] as int) > 0;
  }

  // ==================================

  /// 最新の N 件のロック済み伝票を遡ってハッシュチェーン整合性を検証する。
  /// 軽量（SHA-256 × N 件、通常数ms以下）でバッテリー消費極小。
  /// 改ざんが検出された伝票IDのリストと検証総数を返す。
  Future<HashChainVerifyResult> verifyTailN({int n = 5}) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'invoices',
      columns: ['id', 'meta_json', 'meta_hash', 'updated_at'],
      where: 'is_locked = 1 AND meta_hash IS NOT NULL',
      orderBy: 'updated_at DESC',
      limit: n,
    );
    final broken = <String>[];
    for (final row in rows) {
      final storedHash = row['meta_hash'] as String?;
      final metaJson = row['meta_json'] as String?;
      if (storedHash == null || metaJson == null) continue;
      final recomputed = sha256.convert(utf8.encode(metaJson)).toString();
      if (recomputed != storedHash) {
        broken.add(row['id'] as String);
      }
    }
    return HashChainVerifyResult(
      checked: rows.length,
      brokenIds: broken,
      verifiedAt: DateTime.now(),
    );
  }

  /// 全ロック済み伝票のハッシュチェーン整合性を検証する（手動実行向け）。
  /// 件数が多いと数百ms程度かかる可能性あり。
  Future<HashChainVerifyResult> verifyAllLocked() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'invoices',
      columns: ['id', 'meta_json', 'meta_hash'],
      where: 'is_locked = 1 AND meta_hash IS NOT NULL',
      orderBy: 'updated_at DESC',
    );
    final broken = <String>[];
    for (final row in rows) {
      final storedHash = row['meta_hash'] as String?;
      final metaJson = row['meta_json'] as String?;
      if (storedHash == null || metaJson == null) continue;
      final recomputed = sha256.convert(utf8.encode(metaJson)).toString();
      if (recomputed != storedHash) {
        broken.add(row['id'] as String);
      }
    }
    return HashChainVerifyResult(
      checked: rows.length,
      brokenIds: broken,
      verifiedAt: DateTime.now(),
    );
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

  /// 指定した元伝票IDに紐づく赤伝が存在するか確認（source_document_idが一致し、total_amount<0）
  Future<bool> hasRedInvoice(String sourceDocumentId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'invoices',
      where: 'source_document_id = ?',
      whereArgs: [sourceDocumentId],
    );
    if (rows.isEmpty) return false;
    // total_amountがマイナスのものが赤伝
    return rows.any((r) {
      final total = r['total_amount'];
      if (total is int) return total < 0;
      if (total is num) return total < 0;
      return false;
    });
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
        // ===== ハッシュチェーン保護: 同期時もロック済み伝票の上書き禁止 =====
        final isLocked = (existing.first['is_locked'] as int? ?? 0) == 1;
        if (isLocked) return;
        // ================================================================
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

  /// 未入金合計を取得（全顧客）
  Future<int> getTotalUnpaidAmount() async {
    final db = await _dbHelper.database;
    final results = await db.rawQuery('''
      SELECT COALESCE(SUM(total_amount - received_amount), 0) as total
      FROM invoices
      WHERE document_type = 'invoice' AND (payment_status = 'unpaid' OR payment_status = 'partial')
    ''');
    return (results.first['total'] as num).toInt();
  }

  /// 顧客別の未入金合計を取得
  Future<Map<String, int>> getUnpaidAmountByCustomer() async {
    final db = await _dbHelper.database;
    final results = await db.rawQuery('''
      SELECT customer_id, SUM(total_amount - received_amount) as unpaid
      FROM invoices
      WHERE document_type = 'invoice' AND (payment_status = 'unpaid' OR payment_status = 'partial')
      GROUP BY customer_id
      ORDER BY unpaid DESC
    ''');
    Map<String, int> map = {};
    for (var r in results) {
      map[r['customer_id'] as String] = (r['unpaid'] as num).toInt();
    }
    return map;
  }

  /// 指定顧客の未入金合計を取得
  Future<int> getUnpaidAmountByCustomerId(String customerId) async {
    final db = await _dbHelper.database;
    final results = await db.rawQuery('''
      SELECT COALESCE(SUM(total_amount - received_amount), 0) as unpaid
      FROM invoices
      WHERE document_type = 'invoice' AND customer_id = ? AND (payment_status = 'unpaid' OR payment_status = 'partial')
    ''', [customerId]);
    return (results.first['unpaid'] as num).toInt();
  }

  /// 未使用の請求書一覧を取得（売上に変換できていないもの）
  Future<List<Invoice>> getUnusedInvoices() async {
    final db = await _dbHelper.database;
    final customerRepo = CustomerRepository();
    final customers = await customerRepo.getAllCustomers();

    final invoiceMaps = await db.rawQuery('''
      SELECT i.*, c.display_name, c.formal_name
      FROM invoices i
      LEFT JOIN customers c ON i.customer_id = c.id
      WHERE i.document_type = 'invoice'
        AND (i.linked_invoice_id IS NULL OR i.linked_invoice_id = '')
      ORDER BY i.date DESC
    ''');

    List<Invoice> invoices = [];
    
    for (var iMap in invoiceMaps) {
      final customerId = iMap['customer_id'] as String?;
      Customer customer;
      if (customerId != null) {
        customer = customers.firstWhere(
          (c) => c.id == customerId,
          orElse: () => Customer(id: customerId, displayName: '不明な顧客', formalName: '不明な顧客'),
        );
      } else {
        customer = Customer(id: '', displayName: '不明な顧客', formalName: '不明な顧客');
      }

      final itemMaps = await db.query(
        'invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [iMap['id']],
      );

      final items = List.generate(itemMaps.length, (i) => InvoiceItem.fromMap(itemMaps[i]));

      PaymentStatus paymentStatus = PaymentStatus.unpaid;
      final psRaw = iMap['payment_status'];
      if (psRaw is String) {
        try {
          paymentStatus = PaymentStatus.values.firstWhere((e) => e.name == psRaw);
        } catch (_) {}
      }

      int receivedAmount = 0;
      final ra = iMap['received_amount'];
      if (ra != null) receivedAmount = (ra as num).toInt();

      invoices.add(Invoice(
         id: iMap['id'] as String,
         customer: customer,
         date: DateTime.parse(iMap['date'] as String),
         items: items,
         taxRate: (iMap['tax_rate'] as num?)?.toDouble() ?? 0.10,
         documentType: DocumentType.invoice,
         paymentStatus: paymentStatus,
         receivedAmount: receivedAmount,
         isTestDocument: (iMap['is_test_document'] ?? 0) == 1,
       ));
    }

    return invoices;
  }

  /// 請求書を売上に変換（排他的な1:1紐付け）
  Future<void> convertInvoiceToSales(String invoiceId) async {
    final db = await _dbHelper.database;
    
    // 既に売上に紐づいているか確認
    final existingSales = await db.query(
      'sales',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    );
    if (existingSales.isNotEmpty) {
      throw Exception('この請求書は既に売上に登録されています');
    }

    // 請求書の情報を取得
    final invoiceMaps = await db.query(
      'invoices',
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
    if (invoiceMaps.isEmpty) {
      throw Exception('請求書が見つかりません');
    }

    final invoiceMap = invoiceMaps.first;
    final items = await db.query(
      'invoice_items',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    );

    // 売上伝票を生成
    final salesId = const Uuid().v4();
    final now = DateTime.now();
    final prefix = 'S${now.year}${now.month.toString().padLeft(2, '0')}';
    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM sales WHERE document_number LIKE ?',
      ['$prefix%'],
    );
    final count = countResult.first['count'] as int;
    final documentNumber = '$prefix-${(count + 1).toString().padLeft(4, '0')}';

    final totalAmount = (invoiceMap['total_amount'] as num?)?.toInt() ?? 0;

    await db.insert('sales', {
      'id': salesId,
      'document_number': documentNumber,
      'date': now.toIso8601String(),
      'customer_id': invoiceMap['customer_id'],
      'subtotal': totalAmount,
      'tax_amount': 0,
      'total': totalAmount,
      'tax_rate': 0.10,
      'notes': null,
      'subject': null,
      'status': 'confirmed',
      'invoice_id': invoiceId,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });

    // 売上明細を生成（invoice_itemsからsales_itemsへ変換）
    for (final item in items) {
      final newItemId = const Uuid().v4();
      await db.insert('sales_items', {
        'id': newItemId,
        'sales_id': salesId,
        'product_id': item['product_id'],
        'product_name': item['product_name'] ?? item['description'],
        'quantity': item['quantity'],
        'unit_price': item['unit_price'],
        'subtotal': item['subtotal'],
        'tax_rate': item['tax_rate'] ?? 0.10,
      });
    }

    // 請求書の linked_invoice_id を更新（紐付け済みフラグ）
    await db.update(
      'invoices',
      {'linked_invoice_id': salesId},
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
  }
}
