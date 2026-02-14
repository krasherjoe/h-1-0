// Version: 2026-02-15
/**
 * PDF Generation Service
 * Migrated and optimized from Flutter lib/services/pdf_generator.dart
 * 
 * Features:
 * - A4 size professional invoice PDF
 * - Japanese font support (IPA exGothic)
 * - Table layout with items
 * - Markdown parsing (bold, bullets)
 * - SHA256 hash for audit trail
 * - Tax display modes (normal, text_only, hidden)
 * 
 * Note: This uses expo-print for React Native compatibility
 * @react-pdf/renderer is primarily for web/server-side
 */

import * as FileSystem from 'expo-file-system';
import * as Print from 'expo-print';
import * as Crypto from 'expo-crypto';
import { format } from 'date-fns';
import { Invoice, getDocumentTypeName } from '../models';
import { getCompanyInfo } from './repositories/companyRepository';

/**
 * Format number with thousand separators (Japanese style)
 */
const formatNumber = (num: number): string => {
  return num.toLocaleString('ja-JP');
};

/**
 * Generate SHA256 hash for invoice content (audit trail)
 */
export const generateContentHash = async (invoice: Invoice): Promise<string> => {
  const content = JSON.stringify({
    id: invoice.id,
    invoiceNumber: invoice.invoiceNumber,
    date: invoice.date.getTime(),
    customerId: invoice.customerId,
    items: invoice.items,
    totalAmount: invoice.totalAmount,
  });

  const hash = await Crypto.digestStringAsync(
    Crypto.CryptoDigestAlgorithm.SHA256,
    content
  );

  return hash.substring(0, 8); // First 8 characters
};

/**
 * Parse simple markdown for PDF (bullets and bold)
 */
const parseMarkdownToHTML = (text: string): string => {
  const lines = text.split('\n');

  return lines.map(line => {
    let content = line;
    let prefix = '';
    let style = '';

    // Bullet points
    if (content.startsWith('* ') || content.startsWith('- ')) {
      content = content.substring(2);
      prefix = '• ';
    } else if (content.startsWith('  ')) {
      style = 'margin-left: 10px;';
    }

    // Bold text (**text**)
    content = content.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>');

    return `<div style="${style}">${prefix}${content}</div>`;
  }).join('');
};

/**
 * Generate invoice PDF using expo-print (HTML-based)
 * This is the recommended approach for React Native/Expo
 */
export const generateInvoicePDF = async (
  invoice: Invoice,
  customerDisplayName: string
): Promise<string | null> => {
  try {
    // Get company info
    const companyInfo = await getCompanyInfo();

    // Generate content hash
    const contentHash = await generateContentHash(invoice);

    // Format date
    const dateStr = format(invoice.date, 'yyyy年MM月dd日');
    const documentTypeName = getDocumentTypeName(invoice.documentType);

    // Determine greeting text
    let greeting = '下記の通り、ご請求申し上げます。';
    if (invoice.documentType === 'receipt') {
      greeting = '上記の金額を正に領収いたしました。';
    } else if (invoice.documentType === 'quotation') {
      greeting = '下記の通り、お見積り申し上げます。';
    }

    // Total amount label
    let totalLabel = '合計金額 (税込)';
    if (invoice.documentType === 'receipt') {
      totalLabel = companyInfo.taxDisplayMode === 'hidden' ? '領収金額' : '領収金額 (税込)';
    } else {
      totalLabel = companyInfo.taxDisplayMode === 'hidden' ? '合計金額' : '合計金額 (税込)';
    }

    // Generate HTML template
    const html = `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          @page {
            size: A4;
            margin: 32px;
          }
          body {
            font-family: 'Hiragino Kaku Gothic ProN', 'Hiragino Sans', 'Meiryo', sans-serif;
            font-size: 10pt;
            line-height: 1.4;
            color: #000;
          }
          .header {
            display: flex;
            justify-content: space-between;
            margin-bottom: 20px;
          }
          .title {
            font-size: 28pt;
            font-weight: bold;
          }
          .header-right {
            text-align: right;
            font-size: 10pt;
          }
          .address-section {
            display: flex;
            justify-content: space-between;
            margin-bottom: 30px;
          }
          .customer-info {
            flex: 1;
            padding-right: 20px;
          }
          .customer-name {
            font-size: 18pt;
            border-bottom: 1px solid black;
            padding-bottom: 4px;
            margin-bottom: 10px;
          }
          .company-info {
            flex: 1;
            text-align: right;
            font-size: 10pt;
          }
          .company-name {
            font-size: 14pt;
            font-weight: bold;
            margin-bottom: 4px;
          }
          .total-box {
            background-color: #e0e0e0;
            padding: 8px;
            margin-bottom: 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
          }
          .total-label {
            font-size: 16pt;
          }
          .total-value {
            font-size: 20pt;
            font-weight: bold;
          }
          table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 20px;
          }
          th, td {
            border: 1px solid #ccc;
            padding: 4px;
          }
          th {
            background-color: #d0d0d0;
            font-weight: bold;
            text-align: left;
          }
          td.right {
            text-align: right;
          }
          .summary {
            width: 200px;
            margin-left: auto;
          }
          .summary-row {
            display: flex;
            justify-content: space-between;
            padding: 2px 0;
          }
          .summary-divider {
            border-top: 1px solid black;
            margin: 4px 0;
          }
          .summary-bold {
            font-weight: bold;
            font-size: 12pt;
          }
          .notes-section {
            margin: 10px 0 20px 0;
          }
          .notes-title {
            font-weight: bold;
            margin-bottom: 4px;
          }
          .notes-box {
            border: 1px solid #999;
            padding: 8px;
          }
          .footer {
            margin-top: 20px;
            display: flex;
            justify-content: space-between;
            align-items: flex-end;
          }
          .hash-section {
            font-size: 8pt;
            color: #666;
          }
          .hash-value {
            font-size: 10pt;
            font-weight: bold;
            color: #666;
          }
          .qr-placeholder {
            width: 50px;
            height: 50px;
            border: 1px solid #ccc;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 6pt;
          }
        </style>
      </head>
      <body>
        <!-- Header -->
        <div class="header">
          <div class="title">${documentTypeName}</div>
          <div class="header-right">
            <div>番号: ${invoice.invoiceNumber}</div>
            <div>発行日: ${dateStr}</div>
          </div>
        </div>

        <!-- Customer and Company Info -->
        <div class="address-section">
          <div class="customer-info">
            <div class="customer-name">${customerDisplayName}</div>
            <div>${greeting}</div>
          </div>
          
          <div class="company-info">
            <div class="company-name">${companyInfo.name}</div>
            ${companyInfo.postalCode ? `<div>〒${companyInfo.postalCode}</div>` : ''}
            ${companyInfo.address ? `<div>${companyInfo.address}</div>` : ''}
            ${companyInfo.tel ? `<div>TEL: ${companyInfo.tel}</div>` : ''}
            ${companyInfo.representativeName ? `<div style="font-size: 8pt; margin-top: 4px;">代表: ${companyInfo.representativeName}</div>` : ''}
          </div>
        </div>

        <!-- Total Amount Box -->
        <div class="total-box">
          <span class="total-label">${totalLabel}</span>
          <span class="total-value">￥${formatNumber(invoice.totalAmount)} -</span>
        </div>

        <!-- Items Table -->
        <table>
          <thead>
            <tr>
              <th style="width: 50%;">品名 / 項目</th>
              <th style="width: 15%; text-align: right;">数量</th>
              <th style="width: 17.5%; text-align: right;">単価</th>
              <th style="width: 17.5%; text-align: right;">金額</th>
            </tr>
          </thead>
          <tbody>
            ${invoice.items.map(item => `
              <tr>
                <td>${parseMarkdownToHTML(item.description)}</td>
                <td class="right">${item.quantity}</td>
                <td class="right">${formatNumber(item.unitPrice)}</td>
                <td class="right">${formatNumber(item.subtotal)}</td>
              </tr>
            `).join('')}
          </tbody>
        </table>

        <!-- Summary -->
        <div class="summary">
          <div class="summary-row">
            <span>小計 (税抜)</span>
            <span>${formatNumber(invoice.subtotal)}</span>
          </div>
          
          ${companyInfo.taxDisplayMode === 'normal' ? `
          <div class="summary-row">
            <span>消費税 (${Math.round(invoice.taxRate * 100)}%)</span>
            <span>${formatNumber(invoice.tax)}</span>
          </div>
          ` : ''}
          
          ${companyInfo.taxDisplayMode === 'text_only' ? `
          <div class="summary-row">
            <span>消費税</span>
            <span>（税別）</span>
          </div>
          ` : ''}
          
          <div class="summary-divider"></div>
          
          <div class="summary-row summary-bold">
            <span>合計</span>
            <span>￥${formatNumber(invoice.totalAmount)}</span>
          </div>
        </div>

        <!-- Notes -->
        ${invoice.notes && invoice.notes.trim() !== '' ? `
        <div class="notes-section">
          <div class="notes-title">備考:</div>
          <div class="notes-box">${invoice.notes}</div>
        </div>
        ` : ''}

        <!-- Footer with Hash -->
        <div class="footer">
          <div class="hash-section">
            <div>Verification Hash (SHA256):</div>
            <div class="hash-value">${contentHash}</div>
          </div>
          
          <div class="qr-placeholder">
            QR: ${contentHash}
          </div>
        </div>
      </body>
      </html>
    `;

    // Generate PDF using expo-print
    const { uri } = await Print.printToFileAsync({ html });

    // Generate filename (same format as Flutter version)
    const fileDateStr = format(invoice.date, 'yyyyMMdd');
    const amountStr = formatNumber(invoice.totalAmount);

    // Clean customer name (remove company suffixes)
    const safeCustomerName = customerDisplayName
      .replace(/株式会社|（株）|\(株\)|有限会社|（有）|\(有\)|合同会社|（同）|\(同\)/g, '')
      .trim();

    const subjectStr = invoice.subject ? `_${invoice.subject}` : '';
    const fileName = `${fileDateStr}(${documentTypeName})${safeCustomerName}${subjectStr}_${amountStr}円_${contentHash}.pdf`;

    // expo-print saves to cache directory by default
    console.log('✅ PDF generated successfully:', fileName);
    console.log('📄 Path:', uri);
    console.log('🔒 Hash:', contentHash);

    return uri;

  } catch (error) {
    console.error('❌ PDF Generation Error:', error);
    return null;
  }
};

/**
 * Share generated PDF
 */
export const sharePDF = async (pdfPath: string): Promise<void> => {
  try {
    await Print.printAsync({ uri: pdfPath });
  } catch (error) {
    console.error('Share PDF Error:', error);
  }
};
