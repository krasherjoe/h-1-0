// Version: 2026-02-15
/**
 * Invoice data models
 * Migrated from Flutter lib/models/invoice_models.dart
 */

export interface InvoiceItem {
    description: string;
    quantity: number;
    unitPrice: number;
    subtotal: number;
}

export type DocumentType =
    | 'invoice'      // 請求書
    | 'quotation'    // 見積書
    | 'delivery'     // 納品書
    | 'receipt'      // 領収書
    | 'statement';   // 取引明細書

export type TaxDisplayMode = 'normal' | 'text_only' | 'hidden';

export interface Invoice {
    id: string;
    invoiceNumber: string;
    date: Date;
    customerId: string;
    documentType: DocumentType;
    items: InvoiceItem[];
    subtotal: number;
    tax: number;
    totalAmount: number;
    taxRate: number;
    isDraft: boolean;
    notes?: string;
    subject?: string;
    pdfPath?: string;
    createdAt: Date;
    updatedAt: Date;
    signatureData?: string; // Base64 encoded signature image
}

/**
 * Create a new invoice item with calculated subtotal
 */
export const createInvoiceItem = (
    description: string = '',
    quantity: number = 1,
    unitPrice: number = 0
): InvoiceItem => ({
    description,
    quantity,
    unitPrice,
    subtotal: quantity * unitPrice,
});

/**
 * Calculate invoice totals
 */
export const calculateInvoiceTotals = (
    items: InvoiceItem[],
    taxRate: number
): { subtotal: number; tax: number; totalAmount: number } => {
    const subtotal = items.reduce((sum, item) => sum + item.subtotal, 0);
    const tax = Math.floor(subtotal * taxRate);
    const totalAmount = subtotal + tax;

    return { subtotal, tax, totalAmount };
};

/**
 * Get display name for document type
 */
export const getDocumentTypeName = (type: DocumentType): string => {
    const names: Record<DocumentType, string> = {
        invoice: '請求書',
        quotation: '見積書',
        delivery: '納品書',
        receipt: '領収書',
        statement: '取引明細書',
    };
    return names[type];
};
