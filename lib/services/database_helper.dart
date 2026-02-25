import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static const _databaseVersion = 15;
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
      version: _databaseVersion,
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
      await db.execute('ALTER TABLE invoices ADD COLUMN customer_formal_name TEXT');
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE products ADD COLUMN category TEXT');
      await db.execute('CREATE INDEX idx_products_name ON products(name)');
      await db.execute('CREATE INDEX idx_products_barcode ON products(barcode)');
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
      await db.execute('ALTER TABLE products ADD COLUMN stock_quantity INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE invoices ADD COLUMN document_type TEXT DEFAULT "invoice"');
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
      await db.execute('ALTER TABLE company_info ADD COLUMN tax_display_mode TEXT DEFAULT "normal"');
    }
    if (oldVersion < 10) {
      await db.execute('ALTER TABLE invoices ADD COLUMN terminal_id TEXT DEFAULT "T1"');
      await db.execute('ALTER TABLE invoices ADD COLUMN content_hash TEXT');
    }
    if (oldVersion < 11) {
      await db.execute('ALTER TABLE invoices ADD COLUMN is_draft INTEGER DEFAULT 0');
    }
    if (oldVersion < 12) {
      await db.execute('ALTER TABLE invoices ADD COLUMN subject TEXT');
    }
    if (oldVersion < 13) {
      await db.execute('ALTER TABLE company_info ADD COLUMN registration_number TEXT');
    }
    if (oldVersion < 14) {
      await _safeAddColumn(db, 'invoices', 'subject TEXT');
    }
    if (oldVersion < 15) {
      await _safeAddColumn(db, 'invoices', 'is_locked INTEGER DEFAULT 0');
      await _safeAddColumn(db, 'customers', 'is_locked INTEGER DEFAULT 0');
      await _safeAddColumn(db, 'products', 'is_locked INTEGER DEFAULT 0');
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
        odoo_id TEXT,
        is_locked INTEGER DEFAULT 0,
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

    // 商品マスター
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        default_unit_price INTEGER,
        barcode TEXT,
        category TEXT,
        stock_quantity INTEGER DEFAULT 0,
        is_locked INTEGER DEFAULT 0,
        odoo_id TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_products_name ON products(name)');
    await db.execute('CREATE INDEX idx_products_barcode ON products(barcode)');

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
  }

  Future<void> _safeAddColumn(Database db, String table, String columnDef) async {
    try {
      await db.execute('ALTER TABLE ' + table + ' ADD COLUMN ' + columnDef);
    } catch (_) {
      // Ignore if the column already exists.
    }
  }
}
