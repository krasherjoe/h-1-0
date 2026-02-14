// Version: 2026-02-15
/**
 * Customer Repository
 * Migrated from Flutter lib/services/customer_repository.dart
 */

import { Customer } from '../../models';
import { executeQuery, executeCommand } from '../database';

/**
 * Get all customers
 */
export const getAllCustomers = async (): Promise<Customer[]> => {
    const rows = await executeQuery(
        `SELECT * FROM customers ORDER BY display_name ASC`
    );

    return rows.map(row => ({
        id: row.id,
        displayName: row.display_name,
        formalName: row.formal_name,
        title: row.title,
        department: row.department,
        address: row.address,
        tel: row.tel,
        odooId: row.odoo_id,
        isSynced: row.is_synced === 1,
    }));
};

/**
 * Save a customer
 */
export const saveCustomer = async (customer: Customer): Promise<void> => {
    const now = Date.now();

    await executeCommand(
        `INSERT OR REPLACE INTO customers (
      id, display_name, formal_name, title, department, address, tel,
      odoo_id, is_synced, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
            customer.id,
            customer.displayName,
            customer.formalName,
            customer.title,
            customer.department || null,
            customer.address || null,
            customer.tel || null,
            customer.odooId || null,
            customer.isSynced ? 1 : 0,
            now,
            now,
        ]
    );
};

/**
 * Delete a customer
 */
export const deleteCustomer = async (id: string): Promise<void> => {
    await executeCommand('DELETE FROM customers WHERE id = ?', [id]);
};

/**
 * Search customers by name
 */
export const searchCustomers = async (query: string): Promise<Customer[]> => {
    const rows = await executeQuery(
        `SELECT * FROM customers 
     WHERE display_name LIKE ? OR formal_name LIKE ?
     ORDER BY display_name ASC`,
        [`%${query}%`, `%${query}%`]
    );

    return rows.map(row => ({
        id: row.id,
        displayName: row.display_name,
        formalName: row.formal_name,
        title: row.title,
        department: row.department,
        address: row.address,
        tel: row.tel,
        odooId: row.odoo_id,
        isSynced: row.is_synced === 1,
    }));
};
