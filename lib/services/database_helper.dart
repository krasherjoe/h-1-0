import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'gemi_invoice.db');
    return await openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE invoices ADD COLUMN tax_rate REAL DEFAULT 0.10');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE company_info (
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          zip_code TEXT,
          address TEXT,
          tel TEXT,
          default_tax_rate REAL DEFAULT 0.10,
          seal_path TEXT
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE products ADD COLUMN barcode TEXT');
    }
    if (oldVersion < 5) {
      // 顧客情報のスナップショット
      await db.execute('ALTER TABLE invoices ADD COLUMN customer_formal_name TEXT');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // 顧客マスター
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        formal_name TEXT NOT NULL,
        title TEXT DEFAULT '様',
        department TEXT,
        address TEXT,
        tel TEXT,
        odoo_id TEXT,
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    // GPS履歴 (直近10件想定だがDB上は保持)
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

    // 商品マスター
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        default_unit_price INTEGER,
        barcode TEXT,
        odoo_id TEXT
      )
    ''');

    // 伝票マスター
    await db.execute('''
      CREATE TABLE invoices (
        id TEXT PRIMARY KEY,
        customer_id TEXT NOT NULL,
        date TEXT NOT NULL,
        notes TEXT,
        file_path TEXT,
        total_amount INTEGER,
        tax_rate REAL DEFAULT 0.10,
        customer_formal_name TEXT,
        odoo_id TEXT,
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers (id)
      )
    ''');

    // 伝票明細
    await db.execute('''
      CREATE TABLE invoice_items (
        id TEXT PRIMARY KEY,
        invoice_id TEXT NOT NULL,
        description TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price INTEGER NOT NULL,
        FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE
      )
    ''');

    // 自社情報
    await db.execute('''
      CREATE TABLE company_info (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        zip_code TEXT,
        address TEXT,
        tel TEXT,
        default_tax_rate REAL DEFAULT 0.10,
        seal_path TEXT
      )
    ''');
  }
}
