// Version: 2026-02-15
/**
 * Invoice Repository
 * Migrated from Flutter lib/services/invoice_repository.dart
 */

import { v4 as uuidv4 } from 'uuid';
import { Invoice, InvoiceItem, Customer } from '../../models';
import { executeQuery, executeCommand } from '../database';

/**
 * Save an invoice to the database
 */
export const saveInvoice = async (invoice: Invoice): Promise<void> => {
    // Insert/Update invoice
    await executeCommand(
        `INSERT OR REPLACE INTO invoices (
      id, invoice_number, date, customer_id, document_type,
      subtotal, tax, total_amount, tax_rate, is_draft,
      notes, subject, pdf_path, signature_data, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
            invoice.id,
            invoice.invoiceNumber,
            invoice.date.getTime(),
            invoice.customerId,
            invoice.documentType,
            invoice.subtotal,
            invoice.tax,
            invoice.totalAmount,
            invoice.taxRate,
            invoice.isDraft ? 1 : 0,
            invoice.notes || null,
            invoice.subject || null,
            invoice.pdfPath || null,
            invoice.signatureData || null,
            invoice.createdAt.getTime(),
            invoice.updatedAt.getTime(),
        ]
    );

    // Delete existing items
    await executeCommand('DELETE FROM invoice_items WHERE invoice_id = ?', [invoice.id]);

    // Insert items
    for (let i = 0; i < invoice.items.length; i++) {
        const item = invoice.items[i];
        await executeCommand(
            `INSERT INTO invoice_items (invoice_id, description, quantity, unit_price, subtotal, item_order)
       VALUES (?, ?, ?, ?, ?, ?)`,
            [invoice.id, item.description, item.quantity, item.unitPrice, item.subtotal, i]
        );
    }
};

/**
 * Get all invoices
 */
export const getAllInvoices = async (customers: Customer[]): Promise<Invoice[]> => {
    const rows = await executeQuery(
        `SELECT * FROM invoices ORDER BY date DESC`
    );

    const customerMap = new Map(customers.map(c => [c.id, c]));

    const invoices: Invoice[] = [];
    for (const row of rows) {
        const items = await getInvoiceItems(row.id);

        invoices.push({
            id: row.id,
            invoiceNumber: row.invoice_number,
            date: new Date(row.date),
            customerId: row.customer_id,
            documentType: row.document_type,
            items,
            subtotal: row.subtotal,
            tax: row.tax,
            totalAmount: row.total_amount,
            taxRate: row.tax_rate,
            isDraft: row.is_draft === 1,
            notes: row.notes,
            subject: row.subject,
            pdfPath: row.pdf_path,
            signatureData: row.signature_data,
            createdAt: new Date(row.created_at),
            updatedAt: new Date(row.updated_at),
        });
    }

    return invoices;
};

/**
 * Get invoice items by invoice ID
 */
const getInvoiceItems = async (invoiceId: string): Promise<InvoiceItem[]> => {
    const rows = await executeQuery(
        `SELECT * FROM invoice_items WHERE invoice_id = ? ORDER BY item_order`,
        [invoiceId]
    );

    return rows.map(row => ({
        description: row.description,
        quantity: row.quantity,
        unitPrice: row.unit_price,
        subtotal: row.subtotal,
    }));
};

/**
 * Get invoice by ID
 */
export const getInvoiceById = async (id: string): Promise<Invoice | null> => {
    const rows = await executeQuery('SELECT * FROM invoices WHERE id = ?', [id]);
    if (rows.length === 0) return null;

    const row = rows[0];
    const items = await getInvoiceItems(id);

    return {
        id: row.id,
        invoiceNumber: row.invoice_number,
        date: new Date(row.date),
        customerId: row.customer_id,
        documentType: row.document_type,
        items,
        subtotal: row.subtotal,
        tax: row.tax,
        totalAmount: row.total_amount,
        taxRate: row.tax_rate,
        isDraft: row.is_draft === 1,
        notes: row.notes,
        subject: row.subject,
        pdfPath: row.pdf_path,
        signatureData: row.signature_data,
        createdAt: new Date(row.created_at),
        updatedAt: new Date(row.updated_at),
    };
};

/**
 * Delete an invoice
 */
export const deleteInvoice = async (id: string): Promise<void> => {
    await executeCommand('DELETE FROM invoices WHERE id = ?', [id]);
};

/**
 * Generate next invoice number
 */
export const generateInvoiceNumber = async (documentType: string): Promise<string> => {
    const prefix = documentType.substring(0, 3).toUpperCase();
    const rows = await executeQuery(
        `SELECT invoice_number FROM invoices WHERE invoice_number LIKE ? ORDER BY invoice_number DESC LIMIT 1`,
        [`${prefix}%`]
    );

    if (rows.length === 0) {
        return `${prefix}-0001`;
    }

    const lastNumber = rows[0].invoice_number;
    const match = lastNumber.match(/-(\d+)$/);
    if (!match) {
        return `${prefix}-0001`;
    }

    const nextNumber = parseInt(match[1], 10) + 1;
    return `${prefix}-${nextNumber.toString().padStart(4, '0')}`;
};
