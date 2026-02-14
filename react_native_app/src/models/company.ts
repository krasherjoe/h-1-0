// Version: 2026-02-15
/**
 * Company information model
 * Migrated from Flutter lib/models/company_model.dart
 */

import { TaxDisplayMode } from './invoice';

export interface CompanyInfo {
    name: string;
    postalCode?: string;
    address?: string;
    tel?: string;
    fax?: string;
    email?: string;
    representativeName?: string;
    taxRate: number;
    taxDisplayMode: TaxDisplayMode;
}

/**
 * Default company info
 */
export const createDefaultCompanyInfo = (): CompanyInfo => ({
    name: '',
    taxRate: 0.1, // 10%
    taxDisplayMode: 'normal',
});
