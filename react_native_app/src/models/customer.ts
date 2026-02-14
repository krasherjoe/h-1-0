// Version: 2026-02-15
/**
 * Customer data model
 * Migrated from Flutter lib/models/customer_model.dart
 */

export interface Customer {
    id: string;
    displayName: string;      // 略称
    formalName: string;        // 正式名称
    title: string;             // 敬称（様、御中、殿、貴社）
    department?: string;       // 部署名
    address?: string;          // 住所
    tel?: string;              // 電話番号
    odooId?: number;           // Odoo連携用ID
    isSynced: boolean;         // 同期済みフラグ
}

/**
 * Get full display name with title
 */
export const getCustomerFullName = (customer: Customer): string => {
    return `${customer.formalName} ${customer.title}`;
};

/**
 * Create a new customer with default values
 */
export const createCustomer = (
    id: string,
    displayName: string = '',
    formalName: string = ''
): Customer => ({
    id,
    displayName,
    formalName,
    title: '様',
    isSynced: false,
});
