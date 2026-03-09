import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../constants/warehouse_constants.dart';

class DatabaseHelper {
  static const _databaseVersion = 40;
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static Database? testDatabase; // For testing

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (testDatabase != null) return testDatabase!;
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
      await db.execute('CREATE INDEX idx_customer_contacts_cust ON customer_contacts(customer_id)');

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
      await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_head1 ON customers(head_char1)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_head2 ON customers(head_char2)');
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
      await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_hidden ON customers(is_hidden)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_products_hidden ON products(is_hidden)');
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
      await db.execute('CREATE INDEX IF NOT EXISTS idx_master_hidden_type ON master_hidden(master_type)');
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
      await db.execute('CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON chat_messages(created_at)');
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
      await db.execute('CREATE INDEX IF NOT EXISTS idx_payments_date ON payments(payment_date)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_payments_supplier ON payments(supplier_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_payment_purchases_payment ON payment_purchases(payment_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_payment_purchases_purchase ON payment_purchases(purchase_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_payment_schedules_purchase ON payment_schedules(purchase_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_payment_schedules_due_date ON payment_schedules(due_date)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_payment_schedules_status ON payment_schedules(status)');
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
      await db.execute('CREATE INDEX IF NOT EXISTS idx_mothership_locations_host ON mothership_locations(host)');
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
      await db.execute('CREATE INDEX IF NOT EXISTS idx_suppliers_name ON suppliers(name)');
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
      await db.execute('CREATE INDEX IF NOT EXISTS idx_warehouses_name ON warehouses(name)');
      
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
      await db.execute('CREATE INDEX IF NOT EXISTS idx_staff_name ON staff(name)');
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
      await db.execute('CREATE INDEX IF NOT EXISTS idx_warehouse_stock_product ON warehouse_stock(product_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_warehouse_stock_warehouse ON warehouse_stock(warehouse_id)');

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
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_stock_transfers_document_no ON stock_transfers(document_no)');

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
      await db.execute('CREATE INDEX IF NOT EXISTS idx_stock_transfer_items_transfer ON stock_transfer_items(transfer_id)');

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
      await db.execute('CREATE INDEX IF NOT EXISTS idx_quotations_date ON quotations(date)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_quotations_customer ON quotations(customer_id)');
      
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
      await db.execute('CREATE INDEX IF NOT EXISTS idx_quotation_items_quotation ON quotation_items(quotation_id)');
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
      await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_date ON sales(date)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_customer ON sales(customer_id)');
      
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
      await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_items_sales ON sales_items(sales_id)');
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

      await db.execute('CREATE INDEX idx_purchase_orders_supplier ON purchase_orders(supplier_id)');
      await db.execute('CREATE INDEX idx_purchase_orders_status ON purchase_orders(status)');
      await db.execute('CREATE INDEX idx_purchase_returns_supplier ON purchase_returns(supplier_id)');
      await db.execute('CREATE INDEX idx_purchase_returns_status ON purchase_returns(status)');
      await db.execute('CREATE INDEX idx_purchase_payments_supplier ON purchase_payments(supplier_id)');
      await db.execute('CREATE INDEX idx_purchase_payments_order ON purchase_payments(purchase_order_id)');
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
      await db.execute('CREATE INDEX IF NOT EXISTS idx_business_profiles_type ON business_profiles(business_type)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_business_profiles_updated ON business_profiles(updated_at)');

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
      await db.execute('CREATE INDEX IF NOT EXISTS idx_inventory_locations_warehouse ON inventory_locations(warehouse_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_inventory_locations_active ON inventory_locations(is_active)');

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
      await db.execute('CREATE INDEX IF NOT EXISTS idx_inventory_movements_product ON inventory_movements(product_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_inventory_movements_warehouse ON inventory_movements(warehouse_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_inventory_movements_location ON inventory_movements(location_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_inventory_movements_type ON inventory_movements(movement_type)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_inventory_movements_date ON inventory_movements(movement_date)');

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
      await db.execute('CREATE INDEX idx_electronic_ledgers_type ON electronic_ledgers(document_type)');
      await db.execute('CREATE INDEX idx_electronic_ledgers_created ON electronic_ledgers(created_at)');
      await db.execute('CREATE INDEX idx_electronic_ledgers_profile ON electronic_ledgers(business_profile_id)');
      await db.execute('CREATE INDEX idx_electronic_ledgers_active ON electronic_ledgers(is_active)');
      
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
      await db.execute('CREATE INDEX idx_electronic_ledger_history_ledger ON electronic_ledger_history(ledger_id)');
      await db.execute('CREATE INDEX idx_electronic_ledger_history_created ON electronic_ledger_history(created_at)');
      
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
      await db.execute('CREATE INDEX idx_electronic_ledger_archive_type ON electronic_ledger_archive(document_type)');
      await db.execute('CREATE INDEX idx_electronic_ledger_archive_created ON electronic_ledger_archive(created_at)');
      await db.execute('CREATE INDEX idx_electronic_ledger_archive_archived ON electronic_ledger_archive(archived_at)');
      
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
      await db.execute('CREATE INDEX idx_electronic_ledger_settings_profile ON electronic_ledger_settings(business_profile_id)');
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
    await db.execute('CREATE INDEX idx_customer_contacts_cust ON customer_contacts(customer_id)');

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
        is_hidden INTEGER DEFAULT 0,
        odoo_id TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_products_name ON products(name)');
    await db.execute('CREATE INDEX idx_products_barcode ON products(barcode)');

    await db.execute('''
      CREATE TABLE master_hidden (
        master_type TEXT NOT NULL,
        master_id TEXT NOT NULL,
        is_hidden INTEGER DEFAULT 0,
        PRIMARY KEY(master_type, master_id)
      )
    ''');
    await db.execute('CREATE INDEX idx_master_hidden_type ON master_hidden(master_type)');

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
    await db.execute('CREATE INDEX idx_chat_messages_created_at ON chat_messages(created_at)');

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
    await db.execute('CREATE INDEX idx_mothership_locations_host ON mothership_locations(host)');

    await db.execute('''
      CREATE TABLE suppliers (
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
    await db.execute('CREATE INDEX idx_suppliers_name ON suppliers(name)');

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
    await db.execute('CREATE INDEX idx_warehouse_stock_product ON warehouse_stock(product_id)');
    await db.execute('CREATE INDEX idx_warehouse_stock_warehouse ON warehouse_stock(warehouse_id)');

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
    await db.execute('CREATE INDEX idx_audit_logs_resource ON audit_logs(resource_type, resource_id)');
    await db.execute('CREATE INDEX idx_audit_logs_created ON audit_logs(created_at)');

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
    await db.execute('CREATE INDEX idx_user_sessions_user ON user_sessions(user_id)');
    await db.execute('CREATE INDEX idx_user_sessions_active ON user_sessions(is_active)');
    await db.execute('CREATE INDEX idx_user_sessions_expires ON user_sessions(expires_at)');
    await db.execute('CREATE UNIQUE INDEX idx_stock_transfers_document_no ON stock_transfers(document_no)');

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
    await db.execute('CREATE INDEX idx_stock_transfer_items_transfer ON stock_transfer_items(transfer_id)');

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
    await db.execute('CREATE INDEX idx_custom_fields_profile ON custom_fields(business_profile_id)');
    await db.execute('CREATE INDEX idx_custom_fields_name ON custom_fields(field_name)');
    
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
    await db.execute('CREATE INDEX idx_custom_field_values_field ON custom_field_values(custom_field_id)');
    await db.execute('CREATE INDEX idx_custom_field_values_entity ON custom_field_values(entity_id, entity_type)');
    
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
    await db.execute('CREATE INDEX idx_electronic_ledgers_type ON electronic_ledgers(document_type)');
    await db.execute('CREATE INDEX idx_electronic_ledgers_created ON electronic_ledgers(created_at)');
    await db.execute('CREATE INDEX idx_electronic_ledgers_profile ON electronic_ledgers(business_profile_id)');
    await db.execute('CREATE INDEX idx_electronic_ledgers_active ON electronic_ledgers(is_active)');
    
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
    await db.execute('CREATE INDEX idx_electronic_ledger_history_ledger ON electronic_ledger_history(ledger_id)');
    await db.execute('CREATE INDEX idx_electronic_ledger_history_created ON electronic_ledger_history(created_at)');
    
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
    await db.execute('CREATE INDEX idx_electronic_ledger_archive_type ON electronic_ledger_archive(document_type)');
    await db.execute('CREATE INDEX idx_electronic_ledger_archive_created ON electronic_ledger_archive(created_at)');
    await db.execute('CREATE INDEX idx_electronic_ledger_archive_archived ON electronic_ledger_archive(archived_at)');
    
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
    await db.execute('CREATE INDEX idx_electronic_ledger_settings_profile ON electronic_ledger_settings(business_profile_id)');
  }

  Future<void> _safeAddColumn(Database db, String table, String columnDef) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnDef');
    } catch (_) {
      // Ignore if the column already exists.
    }
  }

  Future<void> _seedDefaultWarehouse(Database db) async {
    const defaultId = kDefaultWarehouseId;
    final existing = await db.query('warehouses', where: 'id = ?', whereArgs: [defaultId]);
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
      await db.insert(
        'warehouse_stock',
        {
          'product_id': product['id'],
          'warehouse_id': defaultId,
          'quantity': quantity,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> _initializeDefaultBusinessProfile(Database db) async {
    final existing = await db.query('business_profiles', limit: 1);
    if (existing.isNotEmpty) return;

    final now = DateTime.now().toIso8601String();
    await db.insert('business_profiles', {
      'id': 'default',
      'business_type': 'retail',
      'product_units': '個,式',
      'needs_inventory': 1,
      'needs_gps': 0,
      'needs_photos': 0,
      'workflow': 'both',
      'pricing': 'standard',
      'created_at': now,
      'updated_at': now,
    });
  }
}
