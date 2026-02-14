// Version: 2026-02-15
/**
 * Product Repository
 * Migrated from Flutter lib/services/product_repository.dart
 */

import { Product } from '../../models';
import { executeQuery, executeCommand } from '../database';

/**
 * Get all products
 */
export const getAllProducts = async (): Promise<Product[]> => {
    const rows = await executeQuery(
        `SELECT * FROM products WHERE is_active = 1 ORDER BY code ASC`
    );

    return rows.map(row => ({
        id: row.id,
        code: row.code,
        name: row.name,
        unitPrice: row.unit_price,
        description: row.description,
        barcode: row.barcode,
        category: row.category,
        isActive: row.is_active === 1,
        createdAt: new Date(row.created_at),
        updatedAt: new Date(row.updated_at),
    }));
};

/**
 * Save a product
 */
export const saveProduct = async (product: Product): Promise<void> => {
    const now = Date.now();

    await executeCommand(
        `INSERT OR REPLACE INTO products (
      id, code, name, unit_price, description, barcode, category,
      is_active, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
            product.id,
            product.code,
            product.name,
            product.unitPrice,
            product.description || null,
            product.barcode || null,
            product.category || null,
            product.isActive ? 1 : 0,
            now,
            now,
        ]
    );
};

/**
 * Delete a product
 */
export const deleteProduct = async (id: string): Promise<void> => {
    await executeCommand('UPDATE products SET is_active = 0 WHERE id = ?', [id]);
};

/**
 * Search products
 */
export const searchProducts = async (query: string): Promise<Product[]> => {
    const rows = await executeQuery(
        `SELECT * FROM products 
     WHERE is_active = 1 AND (code LIKE ? OR name LIKE ?)
     ORDER BY code ASC`,
        [`%${query}%`, `%${query}%`]
    );

    return rows.map(row => ({
        id: row.id,
        code: row.code,
        name: row.name,
        unitPrice: row.unit_price,
        description: row.description,
        barcode: row.barcode,
        category: row.category,
        isActive: row.is_active === 1,
        createdAt: new Date(row.created_at),
        updatedAt: new Date(row.updated_at),
    }));
};
