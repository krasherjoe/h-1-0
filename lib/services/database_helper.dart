import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/warehouse_constants.dart';
import 'storage_permission_service.dart';

/// ローカルバックアップサービス
///
/// 機能：
/// - 自動ローカルバックアップ（毎日）
/// - バックアップ履歴管理（過去 3 件保持）
/// - リストア機能
class LocalBackupService {
  static const _backupPrefix = 'backup_';
  static const _maxBackups = 3;
  static const _lastBackupKey = 'last_backup_timestamp';
  static const _dailyBackupKey = 'backup_date_today';

  /// バックアップディレクトリパス（メイン DB と同じフォルダ）
  Future<String> _getBackupDirectory() async {
    // メイン DB と同じフォルダを使用し、バックアップも保護されるようにする
    final dbDir = await DatabaseHelper._getDatabaseDirectory();
    return path.join(dbDir, 'backups');
  }

  /// 今日のバックアップ済みフラグ取得
  Future<bool> _isTodayBackedUp() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T').first;
    final backedUpDate = prefs.getString(_dailyBackupKey);
    return backedUpDate == today;
  }

  /// 今日のバックアップ済みフラグ設定
  Future<void> _setTodayBackedUp() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T').first;
    await prefs.setString(_dailyBackupKey, today);
  }

  /// バックアップ作成（自動実行用）
  Future<String?> createAutoBackup(String databasePath) async {
    // 今日のバックアップ済みならスキップ
    if (await _isTodayBackedUp()) {
      print('今日のバックアップは既に完了しています');
      return null;
    }

    try {
      final backupDir = await _getBackupDirectory();
      final backupDirObj = Directory(backupDir);
      if (!await backupDirObj.exists()) {
        await backupDirObj.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupPath = path.join(backupDir, '$_backupPrefix$timestamp.db');

      final dbFile = File(databasePath);
      if (!await dbFile.exists()) {
        print('バックアップ対象のデータベースが見つかりません：$databasePath');
        return null;
      }

      await dbFile.copy(backupPath);
      print('ローカルバックアップ作成：$backupPath');

      // 過去バックアップを整理（最大 3 件）
      await _cleanupOldBackups(backupDir, max: _maxBackups);

      // 今日のバックアップ済みフラグ設定
      await _setTodayBackedUp();

      return backupPath;
    } catch (e) {
      print('ローカルバックアップ作成失敗：$e');
      return null;
    }
  }

  /// 古いバックアップを削除（最新 N 件保持）
  Future<void> _cleanupOldBackups(String backupDir, {int max = 3}) async {
    try {
      final backupDirObj = Directory(backupDir);
      if (!await backupDirObj.exists()) return;

      final files = await backupDirObj
          .list()
          .where((f) => f.path.endsWith('.db'))
          .toList();

      // 作成時間でソート（古い順）- ファイル名からタイムスタンプを抽出
      files.sort((a, b) {
        final aPath = (a as File).path;
        final bPath = (b as File).path;
        // backup_1234567890.db から数値部分を抽出
        final aNum =
            int.tryParse(
              aPath.replaceAll(_backupPrefix, '').replaceAll('.db', ''),
            ) ??
            0;
        final bNum =
            int.tryParse(
              bPath.replaceAll(_backupPrefix, '').replaceAll('.db', ''),
            ) ??
            0;
        return aNum.compareTo(bNum);
      });

      // 古いファイルから削除（max を超える分）
      while (files.length > max) {
        final oldest = files.removeAt(0);
        await (oldest as File).delete();
        print('古いバックアップを削除：${oldest.path}');
      }
    } catch (e) {
      print('バックアップ整理失敗：$e');
    }
  }

  /// バックアップ一覧取得
  Future<List<BackupFile>> getBackupList(String databasePath) async {
    try {
      final backupDir = await _getBackupDirectory();
      final backupDirObj = Directory(backupDir);
      if (!await backupDirObj.exists()) return [];

      final files = await backupDirObj
          .list()
          .where((f) => f.path.endsWith('.db'))
          .toList();

      // 作成時間でソート（新しい順）- ファイル名からタイムスタンプを抽出
      files.sort((a, b) {
        final aPath = (a as File).path;
        final bPath = (b as File).path;
        // backup_1234567890.db から数値部分を抽出
        final aNum =
            int.tryParse(
              aPath.replaceAll(_backupPrefix, '').replaceAll('.db', ''),
            ) ??
            0;
        final bNum =
            int.tryParse(
              bPath.replaceAll(_backupPrefix, '').replaceAll('.db', ''),
            ) ??
            0;
        return bNum.compareTo(aNum);
      });

      return files.map((f) {
        final file = f as File;
        final stat = file.statSync();
        final fileName = file.path.split('/').last;
        // backup_1234567890.db からタイムスタンプを抽出
        final timestampStr = fileName
            .replaceAll(_backupPrefix, '')
            .replaceAll('.db', '');
        final timestamp = int.tryParse(timestampStr) ?? 0;

        return BackupFile(
          path: file.path,
          size: stat.size,
          createdTime: DateTime.fromMillisecondsSinceEpoch(timestamp),
          isLatest: files.first == file,
        );
      }).toList();
    } catch (e) {
      print('バックアップ一覧取得失敗：$e');
      return [];
    }
  }

  /// 最終バックアップ時間を取得
  Future<DateTime?> getLastBackupTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_lastBackupKey);
      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      return null;
    } catch (e) {
      print('最終バックアップ時間取得失敗：$e');
      return null;
    }
  }

  /// バックアップからリストア
  Future<bool> restoreFromBackup(String backupPath, String databasePath) async {
    try {
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        print('バックアップファイルが見つかりません：$backupPath');
        return false;
      }

      // 現在のデータベースをクローズ
      final dbObj = await openDatabase(
        databasePath,
        version: 45,
        readOnly: true,
      );
      await dbObj.close();

      // 現在の DB をバックアップ（上書き前）
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final currentBackupPath = '$databasePath.restore-$timestamp';
      if (await File(databasePath).exists()) {
        await File(databasePath).copy(currentBackupPath);
        print('リストア前の DB をバックアップ：$currentBackupPath');
      }

      // 現在の DB を削除
      if (await File(databasePath).exists()) {
        await File(databasePath).delete();
      }

      // バックアップからコピー
      await backupFile.copy(databasePath);
      print('リストア完了：$backupPath -> $databasePath');

      return true;
    } catch (e) {
      print('リストア失敗：$e');
      return false;
    }
  }
}

/// バックアップファイル情報
class BackupFile {
  final String path;
  final int size;
  final DateTime createdTime;
  final bool isLatest;

  BackupFile({
    required this.path,
    required this.size,
    required this.createdTime,
    required this.isLatest,
  });

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024)
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get formattedDate {
    return '${createdTime.year}-${createdTime.month.toString().padLeft(2, '0')}-${createdTime.day.toString().padLeft(2, '0')} ${createdTime.hour.toString().padLeft(2, '0')}:${createdTime.minute.toString().padLeft(2, '0')}';
  }
}

class DatabaseHelper {
  static const _databaseVersion = 48;
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static Database? testDatabase; // For testing

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (testDatabase != null) return testDatabase!;
    if (kIsWeb) {
      throw UnsupportedError('WebプラットフォームではDatabaseは使用できません');
    }
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// データベースファイルパスを取得
  Future<String> getDatabasePath() async {
    final dbDir = await _getDatabaseDirectory();
    return path.join(dbDir, '販売アシスト 1 号.db');
  }

  /// データベース保存ディレクトリを取得（販売アシスト 1 号専用フォルダ）
  /// 再インストール時にもデータを保護するために、システム固有のフォルダを使用
  /// Android: /storage/emulated/0/販売アシスト 1 号/
  /// iOS: Documents フォルダ
  static Future<String> _getDatabaseDirectory() async {
    if (Platform.isAndroid) {
      try {
        // 権限を確認・取得し、バックアップディレクトリを作成
        final storageService = StoragePermissionService();
        await storageService.ensureBackupDirectory();

        // 販売アシスト 1 号専用フォルダ（日本語名）
        final dir = Directory('/storage/emulated/0/販売アシスト 1 号');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir.path;
      } catch (e) {
        debugPrint('販売アシスト 1 号フォルダへのアクセスエラー：$e');
        // エラー時はフォールバックとして内部ストレージを使用
      }
    } else if (Platform.isIOS) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        return dir.path;
      } catch (e) {
        debugPrint('iOS ドキュメントフォルダ取得エラー：$e');
      }
    }

    // フォールバック：内部ストレージ
    return await getDatabasesPath();
  }

  Future<Database> _initDatabase() async {
    final dbDir = await _getDatabaseDirectory();
    String dbPath = path.join(dbDir, '販売アシスト 1 号.db');

    // 既存のデータベースを新しいフォルダへ移行（初回のみ）
    await _migrateDatabaseIfNeeded();

    // フォークされたレコードをクリーンアップ
    final prefs = await SharedPreferences.getInstance();
    final shouldCleanup = prefs.getBool('force_cleanup_forked_records') ?? false;
    if (shouldCleanup) {
      debugPrint('フォークされたレコードをクリーンアップします');
      try {
        final db = await openDatabase(dbPath);
        // 同じdisplay_nameで複数のIDが存在する場合、古いバージョンに新しいIDを設定
        final customers = await db.query('customers', where: 'is_current = 1');
        final Map<String, List<Map<String, dynamic>>> grouped = {};
        
        for (final customer in customers) {
          final displayName = customer['display_name'] as String;
          if (!grouped.containsKey(displayName)) {
            grouped[displayName] = [];
          }
          grouped[displayName]!.add(customer);
        }
        
        // 複数のIDが存在する場合、古いバージョンに新しいIDを設定
        for (final entry in grouped.entries) {
          if (entry.value.length > 1) {
            // バージョン番号でソート（古い順）
            entry.value.sort((a, b) {
              final versionA = (a['version'] as int?) ?? 1;
              final versionB = (b['version'] as int?) ?? 1;
              return versionA.compareTo(versionB);
            });
            
            // 最新バージョン以外に次の世代のIDを設定
            for (int i = 0; i < entry.value.length - 1; i++) {
              final oldRecord = entry.value[i];
              final newRecord = entry.value[i + 1];
              await db.update(
                'customers',
                {'next_version_id': newRecord['id'], 'is_hidden': 1},
                where: 'id = ?',
                whereArgs: [oldRecord['id']],
              );
            }
          }
        }
        await db.close();
        await prefs.setBool('force_cleanup_forked_records', false);
        debugPrint('フォークされたレコードのクリーンアップが完了しました');
      } catch (e) {
        debugPrint('クリーンアップエラー：$e');
      }
    }

    try {
      return await openDatabase(
        dbPath,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      print('DB 初期化エラー：$e');
      // データ消失を防ぐため、破損ファイルは削除せずバックアップのみ作成
      try {
        final dbFile = File(dbPath);
        if (await dbFile.exists()) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final backupPath = '$dbPath.corrupt-$timestamp';

          // 破損 DB をバックアップ（ファイルは削除せず保持）
          await dbFile.copy(backupPath);
          print('破損 DB をバックアップしました：$backupPath');
          print('データ保存のため、既存 DB ファイルを保持します');

          // バックアップ作成後、再度オープン試行（破損ファイルはスキップされる可能性あり）
          return await openDatabase(
            dbPath,
            version: _databaseVersion,
            onCreate: _onCreate,
            onUpgrade: _onUpgrade,
            singleInstance: true, // 重複オープン防止
          );
        } else {
          print('DB ファイルが存在しないため、新規作成します');
          return await openDatabase(
            dbPath,
            version: _databaseVersion,
            onCreate: _onCreate,
            onUpgrade: _onUpgrade,
          );
        }
      } catch (recoveryError) {
        print('DB リカバリエラー：$recoveryError');
        // データ消失を防ぐため、既存ファイルを削除せず再試行
        rethrow;
      }
    }
  }

  /// 既存データベースの移行処理（初回起動時のみ）
  /// gemi_invoice.db → 販売アシスト 1 号.db へリネームし、適切なフォルダへ移動
  Future<void> _migrateDatabaseIfNeeded() async {
    try {
      // 新しい DB フォルダの取得
      final newDbDir = await _getDatabaseDirectory();
      final newDbPath = path.join(newDbDir, '販売アシスト 1 号.db');

      // 新しい DB が既に存在すれば移行不要
      if (await File(newDbPath).exists()) {
        debugPrint('新しい形式の DB が既に存在します：$newDbPath');
        return;
      }

      // 古い形式の DB 位置の調査
      final oldLocations = [
        // 1. Download フォルダ（旧実装）
        path.join('/storage/emulated/0/Download', 'gemi_invoice.db'),
        // 2. アプリ内部ストレージ（初期実装）
        path.join(await getDatabasesPath(), 'gemi_invoice.db'),
      ];

      File? oldDbFile;
      String? oldLocation;

      // 古い DB ファイルを探す
      for (final loc in oldLocations) {
        final testFile = File(loc);
        if (await testFile.exists()) {
          oldDbFile = testFile;
          oldLocation = loc;
          debugPrint('既存の DB を発見：$loc');
          break;
        }
      }

      // 古い DB がなければ移行不要
      if (oldDbFile == null) {
        debugPrint('既存のデータベースは見つかりませんでした。新規作成します。');
        return;
      }

      // 1. 新しいフォルダを作成
      final newDir = Directory(newDbDir);
      if (!await newDir.exists()) {
        await newDir.create(recursive: true);
        debugPrint('新しい DB フォルダを作成：${newDir.path}');
      }

      // 2. データベースを新しい場所へコピー（リネーム付き）
      await oldDbFile.copy(newDbPath);
      debugPrint('データベースを移行：$oldLocation → $newDbPath');

      // 3. 元のファイルをバックアップ（念のため）
      final backupPath =
          '${oldDbFile.path}.migrate-${DateTime.now().millisecondsSinceEpoch}';
      await oldDbFile.copy(backupPath);
      debugPrint('元ファイルをバックアップ：$backupPath');

      // 4. 古いファイルを削除（安全のため 3 日後まで残すロジックは後日実装）
      try {
        await oldDbFile.delete();
        debugPrint('元の DB ファイルを削除：${oldDbFile.path}');
      } catch (e) {
        debugPrint('元ファイルの削除に失敗しましたが、移行は完了しています：$e');
      }

      // 5. バージョン情報を SharedPreferences に記録
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('db_version', _databaseVersion);
      await prefs.setString('db_location', 'new_format');
      debugPrint('データベース移行完了！バージョン：$_databaseVersion');
    } catch (e) {
      debugPrint('データベース移行エラー：$e');
      // エラー時は既存の DB をそのまま使用（データ消失防止）
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE invoices ADD COLUMN tax_rate REAL DEFAULT 0.10',
      );
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE company_info (
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          zip_code TEXT,
          address TEXT,
          tel TEXT,
          fax TEXT,
          email TEXT,
          url TEXT,
          default_tax_rate REAL DEFAULT 0.10,
          seal_path TEXT
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE products ADD COLUMN barcode TEXT');
    }
    if (oldVersion < 5) {
      await db.execute(
        'ALTER TABLE invoices ADD COLUMN customer_formal_name TEXT',
      );
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE products ADD COLUMN category TEXT');
      await db.execute('CREATE INDEX idx_products_name ON products(name)');
      await db.execute(
        'CREATE INDEX idx_products_barcode ON products(barcode)',
      );
      await db.execute('''
        CREATE TABLE activity_logs (
          id TEXT PRIMARY KEY,
          action TEXT NOT NULL,
          target_type TEXT NOT NULL,
          target_id TEXT,
          details TEXT,
          timestamp TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 7) {
      await db.execute(
        'ALTER TABLE products ADD COLUMN stock_quantity INTEGER DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE invoices ADD COLUMN document_type TEXT DEFAULT "invoice"',
      );
      await db.execute('ALTER TABLE invoice_items ADD COLUMN product_id TEXT');
    }
    if (oldVersion < 8) {
      await db.execute('ALTER TABLE invoices ADD COLUMN latitude REAL');
      await db.execute('ALTER TABLE invoices ADD COLUMN longitude REAL');
      await db.execute('''
        CREATE TABLE app_gps_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          timestamp TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 9) {
      await db.execute(
        'ALTER TABLE company_info ADD COLUMN tax_display_mode TEXT DEFAULT "normal"',
      );
    }
    if (oldVersion < 10) {
      await db.execute(
        'ALTER TABLE invoices ADD COLUMN terminal_id TEXT DEFAULT "T1"',
      );
      await db.execute('ALTER TABLE invoices ADD COLUMN content_hash TEXT');
    }
    if (oldVersion < 11) {
      await db.execute(
        'ALTER TABLE invoices ADD COLUMN is_draft INTEGER DEFAULT 0',
      );
    }
    if (oldVersion < 12) {
      await db.execute('ALTER TABLE invoices ADD COLUMN subject TEXT');
    }
    if (oldVersion < 13) {
      await db.execute(
        'ALTER TABLE company_info ADD COLUMN registration_number TEXT',
      );
    }
    if (oldVersion < 14) {
      await _safeAddColumn(db, 'invoices', 'subject TEXT');
    }
    if (oldVersion < 15) {
      await _safeAddColumn(db, 'invoices', 'is_locked INTEGER DEFAULT 0');
      await _safeAddColumn(db, 'customers', 'is_locked INTEGER DEFAULT 0');
      await _safeAddColumn(db, 'products', 'is_locked INTEGER DEFAULT 0');
    }
    if (oldVersion < 16) {
      await db.execute('''
        CREATE TABLE customer_contacts (
          id TEXT PRIMARY KEY,
          customer_id TEXT NOT NULL,
          email TEXT,
          tel TEXT,
          address TEXT,
          version INTEGER NOT NULL,
          is_active INTEGER DEFAULT 1,
          created_at TEXT NOT NULL,
          FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE CASCADE
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_customer_contacts_cust ON customer_contacts(customer_id)',
      );

      // 既存顧客の連絡先を初期バージョンとしてコピー
      final existing = await db.query('customers');
      final now = DateTime.now().toIso8601String();
      for (final row in existing) {
        final contactId = "${row['id']}_v1";
        await db.insert('customer_contacts', {
          'id': contactId,
          'customer_id': row['id'],
          'email': null,
          'tel': row['tel'],
          'address': row['address'],
          'version': 1,
          'is_active': 1,
          'created_at': now,
        });
      }
    }
    if (oldVersion < 17) {
      await _safeAddColumn(db, 'invoices', 'contact_version_id INTEGER');
      await _safeAddColumn(db, 'invoices', 'contact_email_snapshot TEXT');
      await _safeAddColumn(db, 'invoices', 'contact_tel_snapshot TEXT');
      await _safeAddColumn(db, 'invoices', 'contact_address_snapshot TEXT');
    }
    if (oldVersion < 20) {
      await _safeAddColumn(db, 'company_info', 'fax TEXT');
      await _safeAddColumn(db, 'company_info', 'email TEXT');
      await _safeAddColumn(db, 'company_info', 'url TEXT');
    }
    if (oldVersion < 18) {
      await _safeAddColumn(db, 'customers', 'contact_version_id INTEGER');
    }
    if (oldVersion < 19) {
      await _safeAddColumn(db, 'customers', 'head_char1 TEXT');
      await _safeAddColumn(db, 'customers', 'head_char2 TEXT');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_customers_head1 ON customers(head_char1)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_customers_head2 ON customers(head_char2)',
      );
    }
    if (oldVersion < 20) {
      await _safeAddColumn(db, 'customers', 'email TEXT');
    }
    if (oldVersion < 22) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_settings (
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');
    }
    if (oldVersion < 23) {
      await _safeAddColumn(db, 'customers', 'is_hidden INTEGER DEFAULT 0');
      await _safeAddColumn(db, 'products', 'is_hidden INTEGER DEFAULT 0');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_customers_hidden ON customers(is_hidden)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_hidden ON products(is_hidden)',
      );
    }
    if (oldVersion < 24) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS master_hidden (
          master_type TEXT NOT NULL,
          master_id TEXT NOT NULL,
          is_hidden INTEGER DEFAULT 0,
          PRIMARY KEY(master_type, master_id)
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_master_hidden_type ON master_hidden(master_type)',
      );
    }
    if (oldVersion < 25) {
      await _safeAddColumn(db, 'invoices', 'company_snapshot TEXT');
      await _safeAddColumn(db, 'invoices', 'company_seal_hash TEXT');
      await _safeAddColumn(db, 'invoices', 'meta_json TEXT');
      await _safeAddColumn(db, 'invoices', 'meta_hash TEXT');
    }
    if (oldVersion < 26) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS chat_messages (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          message_id TEXT UNIQUE NOT NULL,
          client_id TEXT NOT NULL,
          direction TEXT NOT NULL,
          body TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          synced INTEGER DEFAULT 0,
          delivered_at INTEGER
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON chat_messages(created_at)',
      );
    }
    if (oldVersion < 37) {
      // 支払実績テーブル
      await db.execute('''
        CREATE TABLE IF NOT EXISTS payments (
          id TEXT PRIMARY KEY,
          payment_number TEXT NOT NULL,
          payment_date TEXT NOT NULL,
          supplier_id TEXT NOT NULL,
          amount INTEGER NOT NULL,
          payment_method TEXT NOT NULL,
          bank_account TEXT,
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
        )
      ''');

      // 支払・仕入紐付けテーブル
      await db.execute('''
        CREATE TABLE IF NOT EXISTS payment_purchases (
          id TEXT PRIMARY KEY,
          payment_id TEXT NOT NULL,
          purchase_id TEXT NOT NULL,
          amount INTEGER NOT NULL,
          FOREIGN KEY (payment_id) REFERENCES payments (id),
          FOREIGN KEY (purchase_id) REFERENCES purchases (id)
        )
      ''');

      // 支払予定テーブル
      await db.execute('''
        CREATE TABLE IF NOT EXISTS payment_schedules (
          id TEXT PRIMARY KEY,
          purchase_id TEXT NOT NULL,
          due_date TEXT NOT NULL,
          amount INTEGER NOT NULL,
          status TEXT NOT NULL DEFAULT 'unpaid',
          paid_date TEXT,
          payment_id TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (purchase_id) REFERENCES purchases (id),
          FOREIGN KEY (payment_id) REFERENCES payments (id)
        )
      ''');

      // インデックス作成
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_payments_date ON payments(payment_date)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_payments_supplier ON payments(supplier_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_payment_purchases_payment ON payment_purchases(payment_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_payment_purchases_purchase ON payment_purchases(purchase_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_payment_schedules_purchase ON payment_schedules(purchase_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_payment_schedules_due_date ON payment_schedules(due_date)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_payment_schedules_status ON payment_schedules(status)',
      );
    }
    if (oldVersion < 27) {
      await _safeAddColumn(db, 'chat_messages', 'sequence INTEGER');
      await _safeAddColumn(db, 'chat_messages', 'payload_type TEXT');
      await _safeAddColumn(db, 'chat_messages', 'signature TEXT');
    }
    if (oldVersion < 28) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS mothership_locations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          host TEXT NOT NULL,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          last_seen TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_mothership_locations_host ON mothership_locations(host)',
      );
    }
    if (oldVersion < 29) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS suppliers (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          contact_person TEXT,
          email TEXT,
          tel TEXT,
          address TEXT,
          closing_day INTEGER,
          payment_site_days INTEGER DEFAULT 30,
          notes TEXT,
          is_hidden INTEGER DEFAULT 0,
          updated_at TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_suppliers_name ON suppliers(name)',
      );
    }
    if (oldVersion < 30) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS warehouses (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          location TEXT,
          notes TEXT,
          is_hidden INTEGER DEFAULT 0,
          updated_at TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_warehouses_name ON warehouses(name)',
      );

      await db.execute('''
        CREATE TABLE IF NOT EXISTS staff (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          email TEXT,
          tel TEXT,
          department TEXT,
          position TEXT,
          notes TEXT,
          is_hidden INTEGER DEFAULT 0,
          updated_at TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_staff_name ON staff(name)',
      );
    }
    if (oldVersion < 31) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS warehouse_stock (
          product_id TEXT NOT NULL,
          warehouse_id TEXT NOT NULL,
          quantity INTEGER NOT NULL DEFAULT 0,
          updated_at TEXT NOT NULL,
          PRIMARY KEY(product_id, warehouse_id),
          FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE CASCADE,
          FOREIGN KEY(warehouse_id) REFERENCES warehouses(id) ON DELETE CASCADE
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_warehouse_stock_product ON warehouse_stock(product_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_warehouse_stock_warehouse ON warehouse_stock(warehouse_id)',
      );

      await db.execute('''
        CREATE TABLE IF NOT EXISTS stock_transfers (
          id TEXT PRIMARY KEY,
          document_no TEXT NOT NULL,
          from_warehouse_id TEXT NOT NULL,
          to_warehouse_id TEXT NOT NULL,
          memo TEXT,
          transfer_date TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          created_by_device TEXT,
          FOREIGN KEY(from_warehouse_id) REFERENCES warehouses(id),
          FOREIGN KEY(to_warehouse_id) REFERENCES warehouses(id)
        )
      ''');
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_stock_transfers_document_no ON stock_transfers(document_no)',
      );

      await db.execute('''
        CREATE TABLE IF NOT EXISTS stock_transfer_items (
          id TEXT PRIMARY KEY,
          transfer_id TEXT NOT NULL,
          product_id TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          notes TEXT,
          FOREIGN KEY(transfer_id) REFERENCES stock_transfers(id) ON DELETE CASCADE,
          FOREIGN KEY(product_id) REFERENCES products(id)
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_stock_transfer_items_transfer ON stock_transfer_items(transfer_id)',
      );

      await _seedDefaultWarehouse(db);
      await _migrateExistingStockIntoDefaultWarehouse(db);
    }
    if (oldVersion < 32) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS quotations (
          id TEXT PRIMARY KEY,
          document_number TEXT NOT NULL,
          date TEXT NOT NULL,
          customer_id TEXT,
          subtotal INTEGER NOT NULL,
          tax_amount INTEGER NOT NULL,
          total INTEGER NOT NULL,
          tax_rate REAL NOT NULL,
          notes TEXT,
          subject TEXT,
          status TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY(customer_id) REFERENCES customers(id)
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_quotations_date ON quotations(date)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_quotations_customer ON quotations(customer_id)',
      );

      await db.execute('''
        CREATE TABLE IF NOT EXISTS quotation_items (
          id TEXT PRIMARY KEY,
          quotation_id TEXT NOT NULL,
          product_id TEXT NOT NULL,
          product_name TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          unit_price INTEGER NOT NULL,
          subtotal INTEGER NOT NULL,
          tax_rate REAL NOT NULL,
          notes TEXT,
          FOREIGN KEY(quotation_id) REFERENCES quotations(id) ON DELETE CASCADE,
          FOREIGN KEY(product_id) REFERENCES products(id)
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_quotation_items_quotation ON quotation_items(quotation_id)',
      );
    }
    if (oldVersion < 33) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sales (
          id TEXT PRIMARY KEY,
          document_number TEXT NOT NULL,
          date TEXT NOT NULL,
          customer_id TEXT,
          subtotal INTEGER NOT NULL,
          tax_amount INTEGER NOT NULL,
          total INTEGER NOT NULL,
          tax_rate REAL NOT NULL,
          notes TEXT,
          subject TEXT,
          status TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY(customer_id) REFERENCES customers(id)
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sales_date ON sales(date)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sales_customer ON sales(customer_id)',
      );

      await db.execute('''
        CREATE TABLE IF NOT EXISTS sales_items (
          id TEXT PRIMARY KEY,
          sales_id TEXT NOT NULL,
          product_id TEXT NOT NULL,
          product_name TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          unit_price INTEGER NOT NULL,
          subtotal INTEGER NOT NULL,
          tax_rate REAL NOT NULL,
          notes TEXT,
          FOREIGN KEY(sales_id) REFERENCES sales(id) ON DELETE CASCADE,
          FOREIGN KEY(product_id) REFERENCES products(id)
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sales_items_sales ON sales_items(sales_id)',
      );
    }
    if (oldVersion < 34) {
      await db.execute('''
        CREATE TABLE deliveries (
          id TEXT PRIMARY KEY,
          document_number TEXT NOT NULL,
          date TEXT NOT NULL,
          customer_id TEXT,
          delivery_address TEXT NOT NULL,
          delivery_note TEXT,
          subtotal INTEGER NOT NULL,
          tax_amount INTEGER NOT NULL,
          total INTEGER NOT NULL,
          tax_rate REAL NOT NULL,
          notes TEXT,
          subject TEXT,
          status TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (customer_id) REFERENCES customers (id)
        )
      ''');

      await db.execute('''
        CREATE INDEX idx_deliveries_date ON deliveries(date)
      ''');

      await db.execute('''
        CREATE INDEX idx_deliveries_customer ON deliveries(customer_id)
      ''');

      await db.execute('''
        CREATE INDEX idx_deliveries_status ON deliveries(status)
      ''');
    }
    if (oldVersion < 35) {
      await db.execute('''
        CREATE TABLE delivery_routes (
          id TEXT PRIMARY KEY,
          route_name TEXT NOT NULL,
          start_location TEXT,
          end_location TEXT,
          distance REAL,
          estimated_time INTEGER,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE INDEX idx_delivery_routes_name ON delivery_routes(route_name)
      ''');

      await db.execute('''
        CREATE INDEX idx_delivery_routes_start ON delivery_routes(start_location)
      ''');

      await db.execute('''
        CREATE INDEX idx_delivery_routes_end ON delivery_routes(end_location)
      ''');
    }
    if (oldVersion < 36) {
      await db.execute('''
        CREATE TABLE purchase_orders (
          id TEXT PRIMARY KEY,
          document_number TEXT NOT NULL,
          supplier_id TEXT,
          supplier_snapshot TEXT,
          order_date TEXT NOT NULL,
          expected_date TEXT,
          status TEXT NOT NULL,
          subtotal INTEGER NOT NULL,
          tax_amount INTEGER NOT NULL,
          total INTEGER NOT NULL,
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY(supplier_id) REFERENCES suppliers(id)
        )
      ''');

      await db.execute('''
        CREATE TABLE purchase_order_items (
          id TEXT PRIMARY KEY,
          order_id TEXT NOT NULL,
          product_id TEXT,
          description TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          unit_price INTEGER NOT NULL,
          tax_rate REAL NOT NULL,
          line_total INTEGER NOT NULL,
          FOREIGN KEY(order_id) REFERENCES purchase_orders(id) ON DELETE CASCADE,
          FOREIGN KEY(product_id) REFERENCES products(id)
        )
      ''');

      await db.execute('''
        CREATE TABLE purchase_returns (
          id TEXT PRIMARY KEY,
          document_number TEXT NOT NULL,
          supplier_id TEXT,
          supplier_snapshot TEXT,
          return_date TEXT NOT NULL,
          status TEXT NOT NULL,
          subtotal INTEGER NOT NULL,
          tax_amount INTEGER NOT NULL,
          total INTEGER NOT NULL,
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY(supplier_id) REFERENCES suppliers(id)
        )
      ''');

      await db.execute('''
        CREATE TABLE purchase_return_items (
          id TEXT PRIMARY KEY,
          return_id TEXT NOT NULL,
          product_id TEXT,
          description TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          unit_price INTEGER NOT NULL,
          tax_rate REAL NOT NULL,
          line_total INTEGER NOT NULL,
          FOREIGN KEY(return_id) REFERENCES purchase_returns(id) ON DELETE CASCADE,
          FOREIGN KEY(product_id) REFERENCES products(id)
        )
      ''');

      await db.execute('''
        CREATE TABLE purchase_payments (
          id TEXT PRIMARY KEY,
          purchase_order_id TEXT,
          supplier_id TEXT,
          payment_date TEXT NOT NULL,
          amount INTEGER NOT NULL,
          method TEXT,
          status TEXT NOT NULL,
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY(purchase_order_id) REFERENCES purchase_orders(id),
          FOREIGN KEY(supplier_id) REFERENCES suppliers(id)
        )
      ''');

      await db.execute(
        'CREATE INDEX idx_purchase_orders_supplier ON purchase_orders(supplier_id)',
      );
      await db.execute(
        'CREATE INDEX idx_purchase_orders_status ON purchase_orders(status)',
      );
      await db.execute(
        'CREATE INDEX idx_purchase_returns_supplier ON purchase_returns(supplier_id)',
      );
      await db.execute(
        'CREATE INDEX idx_purchase_returns_status ON purchase_returns(status)',
      );
      await db.execute(
        'CREATE INDEX idx_purchase_payments_supplier ON purchase_payments(supplier_id)',
      );
      await db.execute(
        'CREATE INDEX idx_purchase_payments_order ON purchase_payments(purchase_order_id)',
      );
    }
    if (oldVersion < 38) {
      // BusinessProfileテーブル
      await db.execute('''
        CREATE TABLE IF NOT EXISTS business_profiles (
          id TEXT PRIMARY KEY,
          business_type TEXT NOT NULL,
          product_units TEXT NOT NULL,
          needs_inventory INTEGER NOT NULL DEFAULT 1,
          needs_gps INTEGER NOT NULL DEFAULT 0,
          needs_photos INTEGER NOT NULL DEFAULT 0,
          workflow TEXT NOT NULL,
          pricing TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_business_profiles_type ON business_profiles(business_type)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_business_profiles_updated ON business_profiles(updated_at)',
      );

      // 在庫ロケーションテーブル
      await db.execute('''
        CREATE TABLE IF NOT EXISTS inventory_locations (
          id TEXT PRIMARY KEY,
          warehouse_id TEXT NOT NULL,
          location_code TEXT NOT NULL,
          location_name TEXT NOT NULL,
          description TEXT,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY(warehouse_id) REFERENCES warehouses(id),
          UNIQUE(warehouse_id, location_code)
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_inventory_locations_warehouse ON inventory_locations(warehouse_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_inventory_locations_active ON inventory_locations(is_active)',
      );

      // 在庫移動履歴テーブル
      await db.execute('''
        CREATE TABLE IF NOT EXISTS inventory_movements (
          id TEXT PRIMARY KEY,
          product_id TEXT NOT NULL,
          warehouse_id TEXT NOT NULL,
          location_id TEXT,
          movement_type TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          reference_id TEXT,
          reference_type TEXT,
          notes TEXT,
          movement_date TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY(product_id) REFERENCES products(id),
          FOREIGN KEY(warehouse_id) REFERENCES warehouses(id),
          FOREIGN KEY(location_id) REFERENCES inventory_locations(id)
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_inventory_movements_product ON inventory_movements(product_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_inventory_movements_warehouse ON inventory_movements(warehouse_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_inventory_movements_location ON inventory_movements(location_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_inventory_movements_type ON inventory_movements(movement_type)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_inventory_movements_date ON inventory_movements(movement_date)',
      );

      // デフォルトの業種プロファイルを初期化
      await _initializeDefaultBusinessProfile(db);
    }
    if (oldVersion < 40) {
      // バージョン40: 電子帳簿保存法対応テーブル追加
      await db.execute('''
        CREATE TABLE electronic_ledgers (
          id TEXT PRIMARY KEY,
          document_type TEXT NOT NULL,
          document_data TEXT NOT NULL,
          document_hash TEXT NOT NULL,
          metadata TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          business_profile_id TEXT,
          is_active INTEGER DEFAULT 1
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_electronic_ledgers_type ON electronic_ledgers(document_type)',
      );
      await db.execute(
        'CREATE INDEX idx_electronic_ledgers_created ON electronic_ledgers(created_at)',
      );
      await db.execute(
        'CREATE INDEX idx_electronic_ledgers_profile ON electronic_ledgers(business_profile_id)',
      );
      await db.execute(
        'CREATE INDEX idx_electronic_ledgers_active ON electronic_ledgers(is_active)',
      );

      await db.execute('''
        CREATE TABLE electronic_ledger_history (
          id TEXT PRIMARY KEY,
          ledger_id TEXT NOT NULL,
          document_data TEXT NOT NULL,
          document_hash TEXT NOT NULL,
          metadata TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY(ledger_id) REFERENCES electronic_ledgers(id) ON DELETE CASCADE
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_electronic_ledger_history_ledger ON electronic_ledger_history(ledger_id)',
      );
      await db.execute(
        'CREATE INDEX idx_electronic_ledger_history_created ON electronic_ledger_history(created_at)',
      );

      await db.execute('''
        CREATE TABLE electronic_ledger_archive (
          id TEXT PRIMARY KEY,
          document_type TEXT NOT NULL,
          document_data TEXT NOT NULL,
          document_hash TEXT NOT NULL,
          metadata TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          business_profile_id TEXT,
          archived_at TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_electronic_ledger_archive_type ON electronic_ledger_archive(document_type)',
      );
      await db.execute(
        'CREATE INDEX idx_electronic_ledger_archive_created ON electronic_ledger_archive(created_at)',
      );
      await db.execute(
        'CREATE INDEX idx_electronic_ledger_archive_archived ON electronic_ledger_archive(archived_at)',
      );

      await db.execute('''
        CREATE TABLE electronic_ledger_settings (
          id TEXT PRIMARY KEY,
          business_profile_id TEXT NOT NULL,
          retention_period TEXT NOT NULL,
          enable_compression INTEGER DEFAULT 1,
          enable_encryption INTEGER DEFAULT 0,
          enable_versioning INTEGER DEFAULT 1,
          custom_settings TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY(business_profile_id) REFERENCES business_profiles(id) ON DELETE CASCADE
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_electronic_ledger_settings_profile ON electronic_ledger_settings(business_profile_id)',
      );
    }

    if (oldVersion < 41) {
      await _safeAddColumn(db, 'suppliers', "display_name TEXT");
      await _safeAddColumn(db, 'suppliers', "formal_name TEXT");
      await _safeAddColumn(db, 'suppliers', "title TEXT DEFAULT '様'");
      await _safeAddColumn(db, 'suppliers', 'department TEXT');
      await _safeAddColumn(db, 'suppliers', 'payment_terms TEXT');
      await _safeAddColumn(db, 'suppliers', 'bank_account TEXT');
      await _safeAddColumn(db, 'suppliers', 'is_locked INTEGER DEFAULT 0');
      await _safeAddColumn(db, 'suppliers', 'head_char1 TEXT');
      await _safeAddColumn(db, 'suppliers', 'head_char2 TEXT');

      await db.execute('''
        UPDATE suppliers
        SET display_name = COALESCE(display_name, name),
            formal_name = COALESCE(formal_name, name)
        WHERE display_name IS NULL OR formal_name IS NULL
      ''');

      await db.execute('''
        UPDATE suppliers
        SET title = COALESCE(title, '様'),
            payment_terms = COALESCE(payment_terms, ''),
            bank_account = COALESCE(bank_account, '')
      ''');
    }

    if (oldVersion < 42) {
      await _safeAddColumn(db, 'products', 'wholesale_price INTEGER DEFAULT 0');
    }

    if (oldVersion < 43) {
      await _safeAddColumn(db, 'invoices', "order_status TEXT DEFAULT 'draft'");
      await _safeAddColumn(db, 'invoices', 'promised_date INTEGER');
      await _safeAddColumn(db, 'invoices', 'fulfilled_date INTEGER');
      await _safeAddColumn(db, 'invoices', 'source_document_id TEXT');
      await _safeAddColumn(db, 'invoices', 'linked_delivery_id TEXT');
      await _safeAddColumn(db, 'invoices', 'linked_invoice_id TEXT');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_invoices_order_status ON invoices(order_status)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_invoices_promised_date ON invoices(promised_date)',
      );
    }

    // v44: 電子帳簿保存法対応 - バージョン管理と HASH チェーン追加
    if (oldVersion < 44) {
      // customers テーブルにバージョン管理カラムを追加
      await _safeAddColumn(db, 'customers', 'valid_from TEXT');
      await _safeAddColumn(db, 'customers', 'valid_to TEXT');
      await _safeAddColumn(db, 'customers', 'is_current INTEGER DEFAULT 1');
      await _safeAddColumn(db, 'customers', 'version INTEGER DEFAULT 1');
      await _safeAddColumn(db, 'customers', 'content_hash TEXT');
      await _safeAddColumn(db, 'customers', 'previous_hash TEXT');

      // products テーブルにも同様に追加
      await _safeAddColumn(db, 'products', 'valid_from TEXT');
      await _safeAddColumn(db, 'products', 'valid_to TEXT');
      await _safeAddColumn(db, 'products', 'is_current INTEGER DEFAULT 1');
      await _safeAddColumn(db, 'products', 'version INTEGER DEFAULT 1');
      await _safeAddColumn(db, 'products', 'content_hash TEXT');
      await _safeAddColumn(db, 'products', 'previous_hash TEXT');

      // 既存レコードをカレントとしてマーク（全フィールド NULL で初期化）
      await db.execute('''
        UPDATE customers 
        SET is_current = 1, version = 1, valid_from = updated_at, valid_to = NULL
        WHERE is_current IS NULL
      ''');

      // products テーブルに updated_at カラムが存在する場合のみ実行
      final columns = await db.rawQuery("PRAGMA table_info(products)");
      final hasUpdatedAt = columns.any((col) => col['name'] == 'updated_at');
      if (hasUpdatedAt) {
        await db.execute('''
          UPDATE products 
          SET is_current = 1, version = 1, valid_from = updated_at, valid_to = NULL
          WHERE is_current IS NULL
        ''');
      }

      // パフォーマンス最適化：インデックス追加（最新データのみ高速検索）
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_customers_current ON customers(is_current, valid_to)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_current ON products(is_current, valid_to)',
      );

      // v44.1: customer_contacts の email を customers.email から同期（migration v16 でコピーされなかったため）
      await db.execute('''
        UPDATE customer_contacts
        SET email = (
          SELECT c.email 
          FROM customers c 
          WHERE c.id = customer_contacts.customer_id
        )
        WHERE is_active = 1 AND email IS NULL
      ''');
    }
    if (oldVersion < 45) {
      // v45: v44 カラムが未適用の場合に備えた修復マイグレーション
      await _safeAddColumn(db, 'customers', 'valid_from TEXT');
      await _safeAddColumn(db, 'customers', 'valid_to TEXT');
      await _safeAddColumn(db, 'customers', 'is_current INTEGER DEFAULT 1');
      await _safeAddColumn(db, 'customers', 'version INTEGER DEFAULT 1');
      await _safeAddColumn(db, 'customers', 'content_hash TEXT');
      await _safeAddColumn(db, 'customers', 'previous_hash TEXT');
      await _safeAddColumn(db, 'products', 'valid_from TEXT');
      await _safeAddColumn(db, 'products', 'valid_to TEXT');
      await _safeAddColumn(db, 'products', 'is_current INTEGER DEFAULT 1');
      await _safeAddColumn(db, 'products', 'version INTEGER DEFAULT 1');
      await _safeAddColumn(db, 'products', 'content_hash TEXT');
      await _safeAddColumn(db, 'products', 'previous_hash TEXT');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_customers_current ON customers(is_current, valid_to)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_current ON products(is_current, valid_to)',
      );
      await db.execute('''
        UPDATE customers 
        SET is_current = 1, version = 1, valid_from = updated_at, valid_to = NULL
        WHERE is_current IS NULL
      ''');
      await db.execute('''
        UPDATE products 
        SET is_current = 1, version = 1, valid_from = datetime('now'), valid_to = NULL
        WHERE is_current IS NULL
      ''');
    }
    if (oldVersion < 46) {
      // v46: フォーク追跡用に次の世代のレコード番号を記録するカラムを追加
      await _safeAddColumn(db, 'customers', 'next_version_id TEXT');
      
      // 既存のフォークされたレコードを検出して、next_version_idを設定
      // 同じdisplay_nameで複数のIDが存在する場合、古いバージョンに新しいIDを設定
      final customers = await db.query('customers', where: 'is_current = 1');
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      
      for (final customer in customers) {
        final displayName = customer['display_name'] as String;
        if (!grouped.containsKey(displayName)) {
          grouped[displayName] = [];
        }
        grouped[displayName]!.add(customer);
      }
      
      // 複数のIDが存在する場合、古いバージョンに新しいIDを設定
      for (final entry in grouped.entries) {
        if (entry.value.length > 1) {
          // バージョン番号でソート（古い順）
          entry.value.sort((a, b) {
            final versionA = (a['version'] as int?) ?? 1;
            final versionB = (b['version'] as int?) ?? 1;
            return versionA.compareTo(versionB);
          });
          
          // 最新バージョン以外に次の世代のIDを設定
          for (int i = 0; i < entry.value.length - 1; i++) {
            final oldRecord = entry.value[i];
            final newRecord = entry.value[i + 1];
            await db.update(
              'customers',
              {'next_version_id': newRecord['id'], 'is_hidden': 1},
              where: 'id = ?',
              whereArgs: [oldRecord['id']],
            );
          }
        }
      }
    }

    // v47: 値引き機能追加 - invoice_itemsテーブルにdiscount_amountとdiscount_rateカラムを追加
    if (oldVersion < 47) {
      await _safeAddColumn(db, 'invoice_items', 'discount_amount INTEGER DEFAULT 0');
      await _safeAddColumn(db, 'invoice_items', 'discount_rate REAL DEFAULT 0');
    }

    // v48: 値引き機能追加 - invoicesテーブルにtotal_discount_amountとtotal_discount_rateカラムを追加
    if (oldVersion < 48) {
      await _safeAddColumn(db, 'invoices', 'total_discount_amount INTEGER DEFAULT 0');
      await _safeAddColumn(db, 'invoices', 'total_discount_rate REAL DEFAULT 0');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        formal_name TEXT NOT NULL,
        title TEXT DEFAULT '様',
        department TEXT,
        address TEXT,
        tel TEXT,
        email TEXT,
        contact_version_id INTEGER,
        odoo_id TEXT,
        head_char1 TEXT,
        head_char2 TEXT,
        is_locked INTEGER DEFAULT 0,
        is_hidden INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE customer_gps_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE customer_contacts (
        id TEXT PRIMARY KEY,
        customer_id TEXT NOT NULL,
        email TEXT,
        tel TEXT,
        address TEXT,
        version INTEGER NOT NULL,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_customer_contacts_cust ON customer_contacts(customer_id)',
    );

    // 商品カテゴリーマスター
    await db.execute('''
      CREATE TABLE product_categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_product_categories_name ON product_categories(name)',
    );

    // 商品マスター
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        default_unit_price INTEGER,
        wholesale_price INTEGER DEFAULT 0,
        barcode TEXT,
        category TEXT,
        category_id TEXT,
        stock_quantity INTEGER,
        is_locked INTEGER DEFAULT 0,
        is_hidden INTEGER DEFAULT 0,
        odoo_id TEXT,
        FOREIGN KEY(category_id) REFERENCES product_categories(id)
      )
    ''');
    await db.execute('CREATE INDEX idx_products_name ON products(name)');
    await db.execute('CREATE INDEX idx_products_barcode ON products(barcode)');
    await db.execute(
      'CREATE INDEX idx_products_category_id ON products(category_id)',
    );

    await db.execute('''
      CREATE TABLE master_hidden (
        master_type TEXT NOT NULL,
        master_id TEXT NOT NULL,
        is_hidden INTEGER DEFAULT 0,
        PRIMARY KEY(master_type, master_id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_master_hidden_type ON master_hidden(master_type)',
    );

    // 伝票マスター
    await db.execute('''
      CREATE TABLE invoices (
        id TEXT PRIMARY KEY,
        customer_id TEXT NOT NULL,
        date TEXT NOT NULL,
        notes TEXT,
        subject TEXT,
        file_path TEXT,
        total_amount INTEGER,
        tax_rate REAL DEFAULT 0.10,
        document_type TEXT DEFAULT "invoice",
        order_status TEXT DEFAULT 'draft',
        promised_date INTEGER,
        fulfilled_date INTEGER,
        source_document_id TEXT,
        linked_delivery_id TEXT,
        linked_invoice_id TEXT,
        customer_formal_name TEXT,
        odoo_id TEXT,
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        terminal_id TEXT DEFAULT "T1",
        content_hash TEXT,
        is_draft INTEGER DEFAULT 0,
        is_locked INTEGER DEFAULT 0,
        contact_version_id INTEGER,
        contact_email_snapshot TEXT,
        contact_tel_snapshot TEXT,
        contact_address_snapshot TEXT,
        company_snapshot TEXT,
        company_seal_hash TEXT,
        meta_json TEXT,
        meta_hash TEXT,
        FOREIGN KEY (customer_id) REFERENCES customers (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE app_gps_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

    // 伝票明細
    await db.execute('''
      CREATE TABLE invoice_items (
        id TEXT PRIMARY KEY,
        invoice_id TEXT NOT NULL,
        product_id TEXT,
        description TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price INTEGER NOT NULL,
        FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE company_info (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        zip_code TEXT,
        address TEXT,
        tel TEXT,
        default_tax_rate REAL DEFAULT 0.10,
        seal_path TEXT,
        tax_display_mode TEXT DEFAULT "normal",
        registration_number TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE activity_logs (
        id TEXT PRIMARY KEY,
        action TEXT NOT NULL,
        target_type TEXT NOT NULL,
        target_id TEXT,
        details TEXT,
        timestamp TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        message_id TEXT UNIQUE NOT NULL,
        client_id TEXT NOT NULL,
        direction TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        synced INTEGER DEFAULT 0,
        delivered_at INTEGER,
        sequence INTEGER,
        payload_type TEXT,
        signature TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_chat_messages_created_at ON chat_messages(created_at)',
    );

    await db.execute('''
      CREATE TABLE mothership_locations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        host TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        last_seen TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_mothership_locations_host ON mothership_locations(host)',
    );

    await db.execute('''
      CREATE TABLE suppliers (
        id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        formal_name TEXT NOT NULL,
        title TEXT DEFAULT '様',
        department TEXT,
        address TEXT,
        tel TEXT,
        email TEXT,
        contact_person TEXT,
        payment_terms TEXT,
        bank_account TEXT,
        closing_day INTEGER,
        payment_site_days INTEGER DEFAULT 30,
        notes TEXT,
        is_locked INTEGER DEFAULT 0,
        is_hidden INTEGER DEFAULT 0,
        head_char1 TEXT,
        head_char2 TEXT,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_suppliers_display_name ON suppliers(display_name)',
    );

    await db.execute('''
      CREATE TABLE warehouses (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        location TEXT,
        notes TEXT,
        is_hidden INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_warehouses_name ON warehouses(name)');

    await db.execute('''
      CREATE TABLE warehouse_stock (
        product_id TEXT NOT NULL,
        warehouse_id TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        PRIMARY KEY(product_id, warehouse_id),
        FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE CASCADE,
        FOREIGN KEY(warehouse_id) REFERENCES warehouses(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_warehouse_stock_product ON warehouse_stock(product_id)',
    );
    await db.execute(
      'CREATE INDEX idx_warehouse_stock_warehouse ON warehouse_stock(warehouse_id)',
    );

    await db.execute('''
      CREATE TABLE stock_transfers (
        id TEXT PRIMARY KEY,
        document_no TEXT NOT NULL,
        from_warehouse_id TEXT NOT NULL,
        to_warehouse_id TEXT NOT NULL,
        memo TEXT,
        transfer_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        created_by_device TEXT,
        FOREIGN KEY(from_warehouse_id) REFERENCES warehouses(id),
        FOREIGN KEY(to_warehouse_id) REFERENCES warehouses(id)
      )
    ''');

    // 認証関連テーブル
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE NOT NULL,
        email TEXT UNIQUE NOT NULL,
        full_name TEXT NOT NULL,
        phone_number TEXT,
        department TEXT NOT NULL,
        position TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        last_login_at TEXT,
        role_ids TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_users_username ON users(username)');
    await db.execute('CREATE INDEX idx_users_email ON users(email)');
    await db.execute('CREATE INDEX idx_users_active ON users(is_active)');

    await db.execute('''
      CREATE TABLE roles (
        id TEXT PRIMARY KEY,
        name TEXT UNIQUE NOT NULL,
        description TEXT,
        permissions TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_roles_name ON roles(name)');
    await db.execute('CREATE INDEX idx_roles_active ON roles(is_active)');

    await db.execute('''
      CREATE TABLE user_roles (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        role_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY(role_id) REFERENCES roles(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_user_roles_user ON user_roles(user_id)');
    await db.execute('CREATE INDEX idx_user_roles_role ON user_roles(role_id)');

    await db.execute('''
      CREATE TABLE audit_logs (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        username TEXT NOT NULL,
        action TEXT NOT NULL,
        resource_type TEXT NOT NULL,
        resource_id TEXT,
        old_value TEXT,
        new_value TEXT,
        ip_address TEXT,
        user_agent TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(id)
      )
    ''');
    await db.execute('CREATE INDEX idx_audit_logs_user ON audit_logs(user_id)');
    await db.execute(
      'CREATE INDEX idx_audit_logs_resource ON audit_logs(resource_type, resource_id)',
    );
    await db.execute(
      'CREATE INDEX idx_audit_logs_created ON audit_logs(created_at)',
    );

    await db.execute('''
      CREATE TABLE user_sessions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        username TEXT NOT NULL,
        ip_address TEXT,
        user_agent TEXT,
        created_at TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_user_sessions_user ON user_sessions(user_id)',
    );
    await db.execute(
      'CREATE INDEX idx_user_sessions_active ON user_sessions(is_active)',
    );
    await db.execute(
      'CREATE INDEX idx_user_sessions_expires ON user_sessions(expires_at)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX idx_stock_transfers_document_no ON stock_transfers(document_no)',
    );

    // 販売フロー関連テーブル
    await db.execute('''
      CREATE TABLE stock_allocations (
        id TEXT PRIMARY KEY,
        order_id TEXT,
        sales_id TEXT,
        product_id TEXT NOT NULL,
        warehouse_id TEXT NOT NULL,
        allocated_quantity INTEGER NOT NULL,
        required_quantity INTEGER,
        available_quantity INTEGER,
        status TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        created_by TEXT,
        released_at TEXT,
        released_by TEXT,
        FOREIGN KEY(order_id) REFERENCES orders(id),
        FOREIGN KEY(sales_id) REFERENCES sales(id),
        FOREIGN KEY(product_id) REFERENCES products(id),
        FOREIGN KEY(warehouse_id) REFERENCES warehouses(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_stock_allocations_order ON stock_allocations(order_id)',
    );
    await db.execute(
      'CREATE INDEX idx_stock_allocations_sales ON stock_allocations(sales_id)',
    );
    await db.execute(
      'CREATE INDEX idx_stock_allocations_product ON stock_allocations(product_id)',
    );

    await db.execute('''
      CREATE TABLE flow_status_logs (
        id TEXT PRIMARY KEY,
        document_id TEXT NOT NULL,
        document_type TEXT NOT NULL,
        status TEXT NOT NULL,
        user_id TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_flow_status_logs_document ON flow_status_logs(document_id)',
    );
    await db.execute(
      'CREATE INDEX idx_flow_status_logs_type ON flow_status_logs(document_type)',
    );
    await db.execute(
      'CREATE INDEX idx_flow_status_logs_created ON flow_status_logs(created_at)',
    );

    await db.execute('''
      CREATE TABLE deliveries (
        id TEXT PRIMARY KEY,
        delivery_no TEXT UNIQUE NOT NULL,
        sales_id TEXT NOT NULL,
        status TEXT NOT NULL,
        delivery_address TEXT,
        delivery_date TEXT,
        tracking_number TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        created_by TEXT,
        delivered_at TEXT,
        FOREIGN KEY(sales_id) REFERENCES sales(id),
        FOREIGN KEY(created_by) REFERENCES users(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_deliveries_sales ON deliveries(sales_id)',
    );
    await db.execute(
      'CREATE INDEX idx_deliveries_status ON deliveries(status)',
    );

    // 顧客訪問記録テーブル
    await db.execute('''
      CREATE TABLE client_visits (
        id TEXT PRIMARY KEY,
        client_id TEXT NOT NULL,
        client_name TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        accuracy REAL,
        visit_time TEXT NOT NULL,
        notes TEXT,
        is_manual INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY(client_id) REFERENCES clients(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_client_visits_client ON client_visits(client_id)',
    );
    await db.execute(
      'CREATE INDEX idx_client_visits_time ON client_visits(visit_time)',
    );
    await db.execute(
      'CREATE INDEX idx_client_visits_manual ON client_visits(is_manual)',
    );

    // 配送写真テーブル
    await db.execute('''
      CREATE TABLE delivery_photos (
        id TEXT PRIMARY KEY,
        file_path TEXT NOT NULL,
        original_size INTEGER NOT NULL,
        compressed_size INTEGER NOT NULL,
        compression_ratio REAL NOT NULL,
        delivery_id TEXT,
        order_id TEXT,
        client_id TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY(delivery_id) REFERENCES deliveries(id),
        FOREIGN KEY(order_id) REFERENCES orders(id),
        FOREIGN KEY(client_id) REFERENCES clients(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_delivery_photos_delivery ON delivery_photos(delivery_id)',
    );
    await db.execute(
      'CREATE INDEX idx_delivery_photos_order ON delivery_photos(order_id)',
    );
    await db.execute(
      'CREATE INDEX idx_delivery_photos_client ON delivery_photos(client_id)',
    );
    await db.execute(
      'CREATE INDEX idx_delivery_photos_created ON delivery_photos(created_at)',
    );

    // FTS（全文検索）テーブル - FTS5が利用できない環境ではスキップ
    try {
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS products_fts USING fts5(
          id UNINDEXED,
          name,
          description,
          barcode,
          category,
          tags,
          content='products',
          content_rowid='rowid'
        )
      ''');

      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS clients_fts USING fts5(
          id UNINDEXED,
          name,
          kana,
          address,
          phone,
          email,
          notes,
          content='clients',
          content_rowid='rowid'
        )
      ''');

      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS suppliers_fts USING fts5(
          id UNINDEXED,
          name,
          kana,
          address,
          phone,
          email,
          notes,
          content='suppliers',
          content_rowid='rowid'
        )
      ''');

      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS quotes_fts USING fts5(
          id UNINDEXED,
          quote_no,
          title,
          notes,
          client_name,
          content='quotes',
          content_rowid='rowid'
        )
      ''');

      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS orders_fts USING fts5(
          id UNINDEXED,
          order_no,
          title,
          notes,
          client_name,
          content='orders',
          content_rowid='rowid'
      )
    ''');

      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS sales_fts USING fts5(
          id UNINDEXED,
          sales_no,
          title,
          notes,
          client_name,
          content='sales',
          content_rowid='rowid'
        )
      ''');

      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS inventory_fts USING fts5(
          id UNINDEXED,
          product_name,
          warehouse_name,
          notes,
          content='warehouse_stock',
          content_rowid='rowid'
        )
      ''');

      print('FTS5テーブルを作成しました');
    } catch (e) {
      print('FTS5が利用できないため、全文検索機能は無効化されます: $e');
    }

    await db.execute('''
      CREATE TABLE stock_transfer_items (
        id TEXT PRIMARY KEY,
        transfer_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        notes TEXT,
        FOREIGN KEY(transfer_id) REFERENCES stock_transfers(id) ON DELETE CASCADE,
        FOREIGN KEY(product_id) REFERENCES products(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_stock_transfer_items_transfer ON stock_transfer_items(transfer_id)',
    );

    await _seedDefaultWarehouse(db);
    await db.execute('''
      CREATE TABLE staff (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT,
        tel TEXT,
        department TEXT,
        position TEXT,
        notes TEXT,
        is_hidden INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_staff_name ON staff(name)');

    // バージョン38: BusinessProfileテーブル
    await db.execute('''
      CREATE TABLE business_profiles (
        id TEXT PRIMARY KEY,
        business_type TEXT NOT NULL,
        product_units TEXT NOT NULL,
        needs_inventory INTEGER DEFAULT 1,
        needs_gps INTEGER DEFAULT 0,
        needs_photos INTEGER DEFAULT 0,
        workflow TEXT NOT NULL,
        pricing TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_business_profiles_type ON business_profiles(business_type)',
    );
    await db.execute(
      'CREATE INDEX idx_business_profiles_updated ON business_profiles(updated_at)',
    );

    // デフォルトの業種プロファイルを初期化
    await _initializeDefaultBusinessProfile(db);

    // バージョン39: カスタムフィールドテーブル追加
    await db.execute('''
      CREATE TABLE custom_fields (
        id TEXT PRIMARY KEY,
        business_profile_id TEXT NOT NULL,
        field_name TEXT NOT NULL,
        field_label TEXT NOT NULL,
        field_type TEXT NOT NULL,
        validation TEXT NOT NULL,
        display_order INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        description TEXT,
        default_value TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(business_profile_id) REFERENCES business_profiles(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_custom_fields_profile ON custom_fields(business_profile_id)',
    );
    await db.execute(
      'CREATE INDEX idx_custom_fields_name ON custom_fields(field_name)',
    );

    await db.execute('''
      CREATE TABLE custom_field_values (
        id TEXT PRIMARY KEY,
        custom_field_id TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        value TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(custom_field_id) REFERENCES custom_fields(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_custom_field_values_field ON custom_field_values(custom_field_id)',
    );
    await db.execute(
      'CREATE INDEX idx_custom_field_values_entity ON custom_field_values(entity_id, entity_type)',
    );

    // バージョン40: 電子帳簿保存法対応テーブル追加
    await db.execute('''
      CREATE TABLE electronic_ledgers (
        id TEXT PRIMARY KEY,
        document_type TEXT NOT NULL,
        document_data TEXT NOT NULL,
        document_hash TEXT NOT NULL,
        metadata TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        business_profile_id TEXT,
        is_active INTEGER DEFAULT 1
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_electronic_ledgers_type ON electronic_ledgers(document_type)',
    );
    await db.execute(
      'CREATE INDEX idx_electronic_ledgers_created ON electronic_ledgers(created_at)',
    );
    await db.execute(
      'CREATE INDEX idx_electronic_ledgers_profile ON electronic_ledgers(business_profile_id)',
    );
    await db.execute(
      'CREATE INDEX idx_electronic_ledgers_active ON electronic_ledgers(is_active)',
    );

    await db.execute('''
      CREATE TABLE electronic_ledger_history (
        id TEXT PRIMARY KEY,
        ledger_id TEXT NOT NULL,
        document_data TEXT NOT NULL,
        document_hash TEXT NOT NULL,
        metadata TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(ledger_id) REFERENCES electronic_ledgers(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_electronic_ledger_history_ledger ON electronic_ledger_history(ledger_id)',
    );
    await db.execute(
      'CREATE INDEX idx_electronic_ledger_history_created ON electronic_ledger_history(created_at)',
    );

    await db.execute('''
      CREATE TABLE electronic_ledger_archive (
        id TEXT PRIMARY KEY,
        document_type TEXT NOT NULL,
        document_data TEXT NOT NULL,
        document_hash TEXT NOT NULL,
        metadata TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        business_profile_id TEXT,
        archived_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_electronic_ledger_archive_type ON electronic_ledger_archive(document_type)',
    );
    await db.execute(
      'CREATE INDEX idx_electronic_ledger_archive_created ON electronic_ledger_archive(created_at)',
    );
    await db.execute(
      'CREATE INDEX idx_electronic_ledger_archive_archived ON electronic_ledger_archive(archived_at)',
    );

    await db.execute('''
      CREATE TABLE electronic_ledger_settings (
        id TEXT PRIMARY KEY,
        business_profile_id TEXT NOT NULL,
        retention_period TEXT NOT NULL,
        enable_compression INTEGER DEFAULT 1,
        enable_encryption INTEGER DEFAULT 0,
        enable_versioning INTEGER DEFAULT 1,
        custom_settings TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(business_profile_id) REFERENCES business_profiles(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_electronic_ledger_settings_profile ON electronic_ledger_settings(business_profile_id)',
    );
  }

  Future<void> _safeAddColumn(
    Database db,
    String table,
    String columnDef,
  ) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnDef');
    } catch (_) {
      // Ignore if the column already exists.
    }
  }

  Future<void> _seedDefaultWarehouse(Database db) async {
    const defaultId = kDefaultWarehouseId;
    final existing = await db.query(
      'warehouses',
      where: 'id = ?',
      whereArgs: [defaultId],
    );
    if (existing.isNotEmpty) return;
    await db.insert('warehouses', {
      'id': defaultId,
      'name': kDefaultWarehouseName,
      'location': null,
      'notes': '既存在庫の初期配置用',
      'is_hidden': 0,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _migrateExistingStockIntoDefaultWarehouse(Database db) async {
    const defaultId = kDefaultWarehouseId;
    final products = await db.query('products');
    final now = DateTime.now().toIso8601String();
    for (final product in products) {
      final quantity = product['stock_quantity'] as int? ?? 0;
      await db.insert('warehouse_stock', {
        'product_id': product['id'],
        'warehouse_id': defaultId,
        'quantity': quantity,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> _initializeDefaultBusinessProfile(Database db) async {
    final existing = await db.query('business_profiles', limit: 1);
    if (existing.isNotEmpty) return;

    final now = DateTime.now().toIso8601String();
    await db.insert('business_profiles', {
      'id': 'default',
      'business_type': 'retail',
      'product_units': '個，式',
      'needs_inventory': 1,
      'needs_gps': 0,
      'needs_photos': 0,
      'workflow': 'both',
      'pricing': 'standard',
      'created_at': now,
      'updated_at': now,
    });
  }

  /// ローカルバックアップ管理ダイアログを表示（static メソッド）
  static Widget showLocalBackupManagement({
    required String databasePath,
    Function(String)? onRestore,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        return FutureBuilder<List<BackupInfo>>(
          future: _getLocalBackups(databasePath),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('バックアップ一覧を読み込んでいます...'),
                  ],
                ),
              );
            }

            if (snapshot.hasError) {
              return AlertDialog(
                title: const Text('エラー'),
                content: Text('読み込みエラー：${snapshot.error}'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('閉じる'),
                  ),
                ],
              );
            }

            final backups = snapshot.data ?? [];

            return AlertDialog(
              title: const Text('ローカルバックアップ管理'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '過去 3 件のバックアップが保持されます。',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    if (backups.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('バックアップファイルがありません'),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        itemCount: backups.length,
                        itemBuilder: (context, index) {
                          final backup = backups[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(
                                backup.isLatest
                                    ? Icons.file_present
                                    : Icons.history,
                                color: backup.isLatest ? Colors.green : null,
                              ),
                              title: Text(
                                backup.createdTime
                                    .toIso8601String()
                                    .split('T')
                                    .first,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('サイズ：${backup.formattedSize}'),
                                  if (backup.isLatest)
                                    Text(
                                      '（最新）',
                                      style: TextStyle(
                                        color: Colors.green.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.restore),
                                tooltip: 'リストア',
                                onPressed: () async {
                                  if (onRestore != null) {
                                    onRestore(backup.path);
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('閉じる'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// ローカルバックアップ一覧取得（static メソッド）
  static Future<List<BackupInfo>> _getLocalBackups(String databasePath) async {
    final backupDir = await _getBackupDirectory(databasePath);
    final backupDirObj = Directory(backupDir);

    if (!await backupDirObj.exists()) {
      return [];
    }

    final files = await backupDirObj
        .list()
        .where((f) => f.path.endsWith('.db'))
        .map((e) => e as File)
        .toList();

    // ファイル名からタイムスタンプを抽出してソート（新しい順）
    files.sort((a, b) {
      final aName = path.basename(a.path);
      final bName = path.basename(b.path);
      final aNum = int.tryParse(aName.replaceAll(RegExp(r'^backup_'), '')) ?? 0;
      final bNum = int.tryParse(bName.replaceAll(RegExp(r'^backup_'), '')) ?? 0;
      return bNum.compareTo(aNum);
    });

    // 最新ファイルは最新バックアップとみなす
    final latestFile = File(databasePath);
    final latestModified = await latestFile.stat();

    final backups = files.map((file) async {
      final stat = await file.stat();
      final createdTime = DateTime.fromMillisecondsSinceEpoch(
        stat.modified.millisecondsSinceEpoch,
      );
      final size = await file.length();
      final isLatest = file.path == databasePath; // DB ファイル自身は最新とみなさない

      return BackupInfo(
        path: file.path,
        createdTime: createdTime,
        formattedDate: createdTime.toString().split(' ').first,
        formattedSize: _formatFileSize(size),
        isLatest: false,
      );
    }).toList();

    return Future.wait(backups);
  }

  /// ローカルバックアップディレクトリ取得（static メソッド）
  static Future<String> _getBackupDirectory(String databasePath) async {
    final dbPath = databasePath;
    final dbDir = path.dirname(dbPath);
    return path.join(dbDir, 'backups');
  }

  /// ファイルサイズフォーマット（static メソッド）
  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

/// バックアップ処理用ウィジェット（プログレス表示）

/// バックアップ実行中のダイアログ表示
class BackupProgressDialog extends StatefulWidget {
  final String title;
  final String message;
  final Future<String?> Function() onBackup;
  final VoidCallback? onComplete;
  final Function(String)? onError;

  const BackupProgressDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onBackup,
    this.onComplete,
    this.onError,
  });

  @override
  State<BackupProgressDialog> createState() => _BackupProgressDialogState();
}

class _BackupProgressDialogState extends State<BackupProgressDialog> {
  bool _isComplete = false;
  String? _errorMessage;
  String? _statusMessage;

  Future<void> _executeBackup() async {
    setState(() {
      _statusMessage = 'バックアップを開始します...';
    });

    try {
      final result = await widget.onBackup();
      if (!mounted) return;

      setState(() {
        _isComplete = true;
        _statusMessage = result != null ? 'バックアップ完了！' : 'バックアップできませんでした';
      });

      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.of(context).pop();
        widget.onComplete?.call(); // LSP は警告するが、null チェック済みのため問題なし
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'エラー：$e';
      });

      widget.onError?.call(e.toString());
    }
  }

  @override
  void initState() {
    super.initState();
    // ダイアログ表示後にバックアップ実行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _executeBackup();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 16.0),
            child: CircularProgressIndicator(),
          ),
          Text(widget.message, style: Theme.of(context).textTheme.bodyMedium),
          if (_statusMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _statusMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (_isComplete)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
      ],
    );
  }
}

/// バックアップ一覧表示用ダイアログ
class BackupListDialog extends StatelessWidget {
  final List<BackupFile> backups;
  final String databasePath;
  final Function(String)? onRestore;

  const BackupListDialog({
    super.key,
    required this.backups,
    required this.databasePath,
    this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('バックアップ一覧'),
      content: SizedBox(
        width: double.maxFinite,
        child: backups.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('バックアップファイルがありません'),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: backups.length,
                itemBuilder: (context, index) {
                  final backup = backups[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        backup.isLatest ? Icons.file_present : Icons.history,
                        color: backup.isLatest ? Colors.green : null,
                      ),
                      title: Text(
                        backup.createdTime.toIso8601String().split('T').first,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('サイズ：${backup.formattedSize}'),
                          if (backup.isLatest)
                            Text(
                              '（最新）',
                              style: TextStyle(
                                color: Colors.green.shade600,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.restore),
                        tooltip: 'リストア',
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('リストア確認'),
                              content: Text(
                                'このバックアップからデータを復元します。\n現在のデータは上書きされます。\n\n${backup.formattedDate}\nサイズ：${backup.formattedSize}',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('キャンセル'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  child: const Text('リストアする'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true) {
                            onRestore?.call(backup.path);
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    );
  }

  /// ローカルバックアップ一覧取得（static メソッド）
  static Future<List<BackupInfo>> _getLocalBackups(String databasePath) async {
    final backupDir = await _getBackupDirectory(databasePath);
    final backupDirObj = Directory(backupDir);

    if (!await backupDirObj.exists()) {
      return [];
    }

    final files = await backupDirObj
        .list()
        .where((f) => f.path.endsWith('.db'))
        .map((e) => e as File)
        .toList();

    // ファイル名からタイムスタンプを抽出してソート（新しい順）
    files.sort((a, b) {
      final aName = path.basename(a.path);
      final bName = path.basename(b.path);
      final aNum = int.tryParse(aName.replaceAll(RegExp(r'^backup_'), '')) ?? 0;
      final bNum = int.tryParse(bName.replaceAll(RegExp(r'^backup_'), '')) ?? 0;
      return bNum.compareTo(aNum);
    });

    // 最新ファイルは最新バックアップとみなす
    final latestFile = File(databasePath);
    final latestModified = await latestFile.stat();

    final backups = files.map((file) async {
      final stat = await file.stat();
      final createdTime = DateTime.fromMillisecondsSinceEpoch(
        stat.modified.millisecondsSinceEpoch,
      );
      final size = await file.length();
      final isLatest = file.path == databasePath; // DB ファイル自身は最新とみなさない

      return BackupInfo(
        path: file.path,
        createdTime: createdTime,
        formattedDate: createdTime.toString().split(' ').first,
        formattedSize: _formatFileSize(size),
        isLatest: false,
      );
    }).toList();

    return Future.wait(backups);
  }

  /// ローカルバックアップディレクトリ取得（static メソッド）
  static Future<String> _getBackupDirectory(String databasePath) async {
    final dbPath = databasePath;
    final dbDir = path.dirname(dbPath);
    return path.join(dbDir, 'backups');
  }

  /// ファイルサイズフォーマット（static メソッド）
  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

/// バックアップ情報クラス
class BackupInfo {
  final String path;
  final DateTime createdTime;
  final String formattedDate;
  final String formattedSize;
  final bool isLatest;

  BackupInfo({
    required this.path,
    required this.createdTime,
    required this.formattedDate,
    required this.formattedSize,
    required this.isLatest,
  });
}
