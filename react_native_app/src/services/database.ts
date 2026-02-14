// Version: 2026-02-15
/**
 * SQLite Database Service
 * Migrated from Flutter lib/services/database_helper.dart
 */

import * as SQLite from 'expo-sqlite';

const DATABASE_NAME = 'gemi_invoice.db';
const DATABASE_VERSION = 1;

let db: SQLite.SQLiteDatabase | null = null;

/**
 * Initialize database connection
 */
export const initDatabase = async (): Promise<SQLite.SQLiteDatabase> => {
    if (db) return db;

    db = await SQLite.openDatabaseAsync(DATABASE_NAME);

    // Enable foreign keys
    await db.execAsync('PRAGMA foreign_keys = ON;');

    await createTables();

    return db;
};

/**
 * Get database instance
 */
export const getDatabase = async (): Promise<SQLite.SQLiteDatabase> => {
    if (!db) {
        return await initDatabase();
    }
    return db;
};

/**
 * Create all database tables
 */
const createTables = async () => {
    if (!db) throw new Error('Database not initialized');

    // Company info table
    await db.execAsync(`
    CREATE TABLE IF NOT EXISTS company_info (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      name TEXT NOT NULL,
      postal_code TEXT,
      address TEXT,
      tel TEXT,
      fax TEXT,
      email TEXT,
      representative_name TEXT,
      tax_rate REAL NOT NULL DEFAULT 0.1,
      tax_display_mode TEXT NOT NULL DEFAULT 'normal'
    );
  `);

    // Customers table
    await db.execAsync(`
    CREATE TABLE IF NOT EXISTS customers (
      id TEXT PRIMARY KEY,
      display_name TEXT NOT NULL,
      formal_name TEXT NOT NULL,
      title TEXT NOT NULL DEFAULT '様',
      department TEXT,
      address TEXT,
      tel TEXT,
      odoo_id INTEGER,
      is_synced INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    );
  `);

    // Products table
    await db.execAsync(`
    CREATE TABLE IF NOT EXISTS products (
      id TEXT PRIMARY KEY,
      code TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      unit_price REAL NOT NULL,
      description TEXT,
      barcode TEXT,
      category TEXT,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    );
  `);

    // Invoices table
    await db.execAsync(`
    CREATE TABLE IF NOT EXISTS invoices (
      id TEXT PRIMARY KEY,
      invoice_number TEXT NOT NULL UNIQUE,
      date INTEGER NOT NULL,
      customer_id TEXT NOT NULL,
      document_type TEXT NOT NULL,
      subtotal REAL NOT NULL,
      tax REAL NOT NULL,
      total_amount REAL NOT NULL,
      tax_rate REAL NOT NULL,
      is_draft INTEGER NOT NULL DEFAULT 1,
      notes TEXT,
      subject TEXT,
      pdf_path TEXT,
      signature_data TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      FOREIGN KEY (customer_id) REFERENCES customers(id)
    );
  `);

    // Invoice items table
    await db.execAsync(`
    CREATE TABLE IF NOT EXISTS invoice_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_id TEXT NOT NULL,
      description TEXT NOT NULL,
      quantity REAL NOT NULL,
      unit_price REAL NOT NULL,
      subtotal REAL NOT NULL,
      item_order INTEGER NOT NULL,
      FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
    );
  `);

    // GPS history table
    await db.execAsync(`
    CREATE TABLE IF NOT EXISTS gps_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      customer_id TEXT NOT NULL,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      recorded_at INTEGER NOT NULL,
      FOREIGN KEY (customer_id) REFERENCES customers(id)
    );
  `);

    // Activity log table
    await db.execAsync(`
    CREATE TABLE IF NOT EXISTS activity_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      action TEXT NOT NULL,
      description TEXT,
      timestamp INTEGER NOT NULL,
      metadata TEXT
    );
  `);

    // Create indexes
    await db.execAsync(`
    CREATE INDEX IF NOT EXISTS idx_invoices_date ON invoices(date DESC);
    CREATE INDEX IF NOT EXISTS idx_invoices_customer ON invoices(customer_id);
    CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice ON invoice_items(invoice_id);
    CREATE INDEX IF NOT EXISTS idx_products_code ON products(code);
    CREATE INDEX IF NOT EXISTS idx_gps_history_customer ON gps_history(customer_id);
    CREATE INDEX IF NOT EXISTS idx_activity_logs_entity ON activity_logs(entity_type, entity_id);
  `);
};

/**
 * Close database connection
 */
export const closeDatabase = async () => {
    if (db) {
        await db.closeAsync();
        db = null;
    }
};

/**
 * Execute a raw SQL query
 */
export const executeQuery = async (
    sql: string,
    params: any[] = []
): Promise<any[]> => {
    const database = await getDatabase();
    const result = await database.getAllAsync(sql, params);
    return result;
};

/**
 * Execute a raw SQL command (INSERT, UPDATE, DELETE)
 */
export const executeCommand = async (
    sql: string,
    params: any[] = []
): Promise<SQLite.SQLiteRunResult> => {
    const database = await getDatabase();
    const result = await database.runAsync(sql, params);
    return result;
};
