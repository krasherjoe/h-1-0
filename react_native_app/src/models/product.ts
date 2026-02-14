// Version: 2026-02-15
/**
 * Product data model
 * Migrated from Flutter lib/models/product_model.dart
 */

export interface Product {
    id: string;
    code: string;              // 商品コード
    name: string;              // 商品名
    unitPrice: number;         // 単価
    description?: string;      // 説明
    barcode?: string;          // JANコード等
    category?: string;         // カテゴリー
    isActive: boolean;         // 有効フラグ
    createdAt: Date;
    updatedAt: Date;
}

/**
 * Create a new product with default values
 */
export const createProduct = (
    id: string,
    code: string = '',
    name: string = '',
    unitPrice: number = 0
): Product => ({
    id,
    code,
    name,
    unitPrice,
    isActive: true,
    createdAt: new Date(),
    updatedAt: new Date(),
});
