// Version: 2026-02-15
/**
 * Company Repository
 * Migrated from Flutter lib/services/company_repository.dart
 */

import { CompanyInfo, createDefaultCompanyInfo } from '../../models';
import { executeQuery, executeCommand } from '../database';

/**
 * Get company information
 */
export const getCompanyInfo = async (): Promise<CompanyInfo> => {
    const rows = await executeQuery('SELECT * FROM company_info WHERE id = 1');

    if (rows.length === 0) {
        return createDefaultCompanyInfo();
    }

    const row = rows[0];
    return {
        name: row.name,
        postalCode: row.postal_code,
        address: row.address,
        tel: row.tel,
        fax: row.fax,
        email: row.email,
        representativeName: row.representative_name,
        taxRate: row.tax_rate,
        taxDisplayMode: row.tax_display_mode,
    };
};

/**
 * Save company information
 */
export const saveCompanyInfo = async (info: CompanyInfo): Promise<void> => {
    await executeCommand(
        `INSERT OR REPLACE INTO company_info (
      id, name, postal_code, address, tel, fax, email,
      representative_name, tax_rate, tax_display_mode
    ) VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
            info.name,
            info.postalCode || null,
            info.address || null,
            info.tel || null,
            info.fax || null,
            info.email || null,
            info.representativeName || null,
            info.taxRate,
            info.taxDisplayMode,
        ]
    );
};
