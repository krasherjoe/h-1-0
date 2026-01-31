// app/src/main/java/com/example/mobilepos/util/PdfGenerator.kt

package com.example.mobilepos.util

import android.content.Context
import android.graphics.pdf.PdfDocument
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Color
import android.graphics.Typeface
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.*
import com.example.mobilepos.data.models.*
import com.google.gson.Gson

object PdfGenerator {
    
    private const val PAGE_WIDTH = 595  // A4幅（ポイント）
    private const val PAGE_HEIGHT = 842  // A4高さ（ポイント）
    private const val MARGIN = 40
    private const val CONTENT_WIDTH = PAGE_WIDTH - (MARGIN * 2)

    fun generateQuotationPdf(
        context: Context,
        document: DocumentEntity,
        customer: CustomerEntity,
        fileName: String = "quotation_${document.id}.pdf"
    ): File? {
        return try {
            val pdfDocument = PdfDocument()
            var pageHeight = PAGE_HEIGHT
            var yPosition = MARGIN
            
            val pageInfo = PdfDocument.PageInfo.Builder(PAGE_WIDTH, pageHeight, 1).create()
            var page = pdfDocument.startPage(pageInfo)
            var canvas = page.canvas
            
            // ヘッダー
            yPosition = drawHeader(canvas, yPosition, "見積書")
            yPosition += 20
            
            // 会社情報（左上）
            yPosition = drawCompanyInfo(canvas, yPosition)
            yPosition += 20
            
            // 見積情報
            canvas.drawText("見積日：${formatDate(document.documentDate)}", MARGIN.toFloat(), yPosition.toFloat(), getPaint())
            yPosition += 20
            canvas.drawText("見積番号：QT-${document.id.toString().padStart(6, '0')}", MARGIN.toFloat(), yPosition.toFloat(), getPaint())
            yPosition += 30
            
            // 顧客情報
            yPosition = drawCustomerInfo(canvas, yPosition, customer)
            yPosition += 20
            
            // 区切り線
            canvas.drawLine(MARGIN.toFloat(), yPosition.toFloat(), (PAGE_WIDTH - MARGIN).toFloat(), yPosition.toFloat(), getPaint())
            yPosition += 10
            
            // 商品テーブルヘッダー
            yPosition = drawTableHeader(canvas, yPosition)
            yPosition += 5
            
            // 商品行
            val items = parseDocumentItems(document.items)
            for (item in items) {
                if (yPosition > PAGE_HEIGHT - 100) {
                    // 新しいページ
                    pdfDocument.finishPage(page)
                    val newPageInfo = PdfDocument.PageInfo.Builder(PAGE_WIDTH, pageHeight, pdfDocument.pages.size + 1).create()
                    page = pdfDocument.startPage(newPageInfo)
                    canvas = page.canvas
                    yPosition = MARGIN
                }
                yPosition = drawTableRow(canvas, yPosition, item)
            }
            
            yPosition += 10
            canvas.drawLine(MARGIN.toFloat(), yPosition.toFloat(), (PAGE_WIDTH - MARGIN).toFloat(), yPosition.toFloat(), getPaint())
            yPosition += 15
            
            // 合計
            yPosition = drawTotals(canvas, yPosition, document)
            yPosition += 20
            
            // 支払期限
            val dueDate = formatDate(document.paymentDueDate)
            canvas.drawText("お支払い期限：$dueDate", MARGIN.toFloat(), yPosition.toFloat(), getPaint(bold = true))
            yPosition += 20
            canvas.drawText("お支払い方法：${document.paymentMethod ?: "銀行振込"}", MARGIN.toFloat(), yPosition.toFloat(), getPaint())
            
            // 備考
            if (!document.notes.isNullOrEmpty()) {
                yPosition += 20
                canvas.drawText("備考：", MARGIN.toFloat(), yPosition.toFloat(), getPaint(bold = true))
                yPosition += 15
                val noteLines = document.notes!!.split("\n")
                for (line in noteLines) {
                    canvas.drawText(line, MARGIN.toFloat(), yPosition.toFloat(), getPaint())
                    yPosition += 15
                }
            }
            
            pdfDocument.finishPage(page)
            
            // ファイル保存
            val outputFile = File(context.getExternalFilesDir(null), fileName)
            val fos = FileOutputStream(outputFile)
            pdfDocument.writeTo(fos)
            fos.close()
            pdfDocument.close()
            
            outputFile
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    fun generateInvoicePdf(
        context: Context,
        document: DocumentEntity,
        customer: CustomerEntity,
        fileName: String = "invoice_${document.id}.pdf"
    ): File? {
        return try {
            val pdfDocument = PdfDocument()
            var pageHeight = PAGE_HEIGHT
            var yPosition = MARGIN
            
            val pageInfo = PdfDocument.PageInfo.Builder(PAGE_WIDTH, pageHeight, 1).create()
            var page = pdfDocument.startPage(pageInfo)
            var canvas = page.canvas
            
            // ヘッダー
            yPosition = drawHeader(canvas, yPosition, "請求書")
            yPosition += 20
            
            // 会社情報
            yPosition = drawCompanyInfo(canvas, yPosition)
            yPosition += 20
            
            // 請求情報
            canvas.drawText("請求日：${formatDate(document.documentDate)}", MARGIN.toFloat(), yPosition.toFloat(), getPaint())
            yPosition += 20
            canvas.drawText("請求番号：INV-${document.id.toString().padStart(6, '0')}", MARGIN.toFloat(), yPosition.toFloat(), getPaint())
            yPosition += 30
            
            // 顧客情報
            yPosition = drawCustomerInfo(canvas, yPosition, customer)
            yPosition += 20
            
            // 区切り線
            canvas.drawLine(MARGIN.toFloat(), yPosition.toFloat(), (PAGE_WIDTH - MARGIN).toFloat(), yPosition.toFloat(), getPaint())
            yPosition += 10
            
            // 商品テーブル
            yPosition = drawTableHeader(canvas, yPosition)
            yPosition += 5
            
            val items = parseDocumentItems(document.items)
            for (item in items) {
                if (yPosition > PAGE_HEIGHT - 150) {
                    pdfDocument.finishPage(page)
                    val newPageInfo = PdfDocument.PageInfo.Builder(PAGE_WIDTH, pageHeight, pdfDocument.pages.size + 1).create()
                    page = pdfDocument.startPage(newPageInfo)
                    canvas = page.canvas
                    yPosition = MARGIN
                }
                yPosition = drawTableRow(canvas, yPosition, item)
            }
            
            yPosition += 10
            canvas.drawLine(MARGIN.toFloat(), yPosition.toFloat(), (PAGE_WIDTH - MARGIN).toFloat(), yPosition.toFloat(), getPaint())
            yPosition += 15
            
            // 合計
            yPosition = drawTotals(canvas, yPosition, document)
            yPosition += 20
            
            // 支払期限・方法
            val dueDate = formatDate(document.paymentDueDate)
            canvas.drawText("お支払い期限：$dueDate", MARGIN.toFloat(), yPosition.toFloat(), getPaint(bold = true))
            yPosition += 20
            canvas.drawText("お支払い方法：${document.paymentMethod ?: "銀行振込"}", MARGIN.toFloat(), yPosition.toFloat(), getPaint())
            
            pdfDocument.finishPage(page)
            
            val outputFile = File(context.getExternalFilesDir(null), fileName)
            val fos = FileOutputStream(outputFile)
            pdfDocument.writeTo(fos)
            fos.close()
            pdfDocument.close()
            
            outputFile
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    fun generateReceiptPdf(
        context: Context,
        document: DocumentEntity,
        customer: CustomerEntity,
        fileName: String = "receipt_${document.id}.pdf"
    ): File? {
        return try {
            val pdfDocument = PdfDocument()
            var pageHeight = PAGE_HEIGHT
            var yPosition = MARGIN
            
            val pageInfo = PdfDocument.PageInfo.Builder(PAGE_WIDTH, pageHeight, 1).create()
            val page = pdfDocument.startPage(pageInfo)
            val canvas = page.canvas
            
            // ヘッダー
            yPosition = drawHeader(canvas, yPosition, "領収書")
            yPosition += 20
            
            // 会社情報
            yPosition = drawCompanyInfo(canvas, yPosition)
            yPosition += 20
            
            // 領収情報
            canvas.drawText("領収日：${formatDate(document.documentDate)}", MARGIN.toFloat(), yPosition.toFloat(), getPaint())
            yPosition += 20
            canvas.drawText("領収番号：RCP-${document.id.toString().padStart(6, '0')}", MARGIN.toFloat(), yPosition.toFloat(), getPaint())
            yPosition += 30
            
            // 顧客情報
            yPosition = drawCustomerInfo(canvas, yPosition, customer)
            yPosition += 20
            
            // 金額
            canvas.drawText("お振込金額", MARGIN.toFloat(), yPosition.toFloat(), getPaint(bold = true))
            yPosition += 20
            
            val totalText = "¥${String.format("%,d", document.total.toLong())}"
            val totalPaint = getPaint(bold = true, size = 36f)
            canvas.drawText(totalText, MARGIN.toFloat(), yPosition.toFloat(), totalPaint)
            yPosition += 40
            
            // 摘要
            canvas.drawText("摘要：商品・サービス提供代金", MARGIN.toFloat(), yPosition.toFloat(), getPaint())
            yPosition += 20
            
            // 支払い日
            if (document.paidDate != null) {
                canvas.drawText("お支払い日：${formatDate(document.paidDate!!)}", MARGIN.toFloat(), yPosition.toFloat(), getPaint())
            }
            
            pdfDocument.finishPage(page)
            
            val outputFile = File(context.getExternalFilesDir(null), fileName)
            val fos = FileOutputStream(outputFile)
            pdfDocument.writeTo(fos)
            fos.close()
            pdfDocument.close()
            
            outputFile
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    // ========== ヘルパー関数 ==========
    
    private fun drawHeader(canvas: Canvas, yPosition: Int, title: String): Int {
        val paint = getPaint(bold = true, size = 28f)
        canvas.drawText(title, MARGIN.toFloat(), (yPosition + 25).toFloat(), paint)
        return yPosition + 40
    }

    private fun drawCompanyInfo(canvas: Canvas, yPosition: Int): Int {
        val paint = getPaint(size = 10f)
        var y = yPosition
        canvas.drawText("株式会社 ○○○○", MARGIN.toFloat(), y.toFloat(), paint)
        y += 12
        canvas.drawText("住所：〒000-0000 ○○県○○市○○町1-1", MARGIN.toFloat(), y.toFloat(), paint)
        y += 12
        canvas.drawText("電話：09X-XXXX-XXXX", MARGIN.toFloat(), y.toFloat(), paint)
        y += 12
        canvas.drawText("メール：info@example.com", MARGIN.toFloat(), y.toFloat(), paint)
        return y
    }

    private fun drawCustomerInfo(canvas: Canvas, yPosition: Int, customer: CustomerEntity): Int {
        val paint = getPaint()
        var y = yPosition
        canvas.drawText("ご購入者様", MARGIN.toFloat(), y.toFloat(), paint)
        y += 20
        canvas.drawText(customer.name, MARGIN.toFloat(), y.toFloat(), paint)
        y += 15
        if (!customer.address.isNullOrEmpty()) {
            canvas.drawText("住所：${customer.address}", MARGIN.toFloat(), y.toFloat(), paint)
            y += 15
        }
        if (!customer.phone.isNullOrEmpty()) {
            canvas.drawText("電話：${customer.phone}", MARGIN.toFloat(), y.toFloat(), paint)
            y += 15
        }
        return y
    }

    private fun drawTableHeader(canvas: Canvas, yPosition: Int): Int {
        val paint = getPaint(bold = true)
        val smallPaint = getPaint(size = 10f)
        
        var x = MARGIN
        canvas.drawText("品目", x.toFloat(), yPosition.toFloat(), paint)
        x += 200
        canvas.drawText("数量", x.toFloat(), yPosition.toFloat(), paint)
        x += 80
        canvas.drawText("単価", x.toFloat(), yPosition.toFloat(), paint)
        x += 80
        canvas.drawText("小計", x.toFloat(), yPosition.toFloat(), paint)
        
        return yPosition + 15
    }

    private fun drawTableRow(canvas: Canvas, yPosition: Int, item: DocumentItemDto): Int {
        val paint = getPaint(size = 11f)
        
        val productText = item.productName
        val quantityText = String.format("%.2f", item.quantity)
        val unitPriceText = "¥${String.format("%,d", item.unitPrice.toLong())}"
        val subtotalText = "¥${String.format("%,d", item.subtotal.toLong())}"
        
        var x = MARGIN
        canvas.drawText(productText, x.toFloat(), yPosition.toFloat(), paint)
        x += 200
        canvas.drawText(quantityText, x.toFloat(), yPosition.toFloat(), paint)
        x += 80
        canvas.drawText(unitPriceText, x.toFloat(), yPosition.toFloat(), paint)
        x += 80
        canvas.drawText(subtotalText, x.toFloat(), yPosition.toFloat(), paint)
        
        return yPosition + 15
    }

    private fun drawTotals(canvas: Canvas, yPosition: Int, document: DocumentEntity): Int {
        val paint = getPaint()
        val boldPaint = getPaint(bold = true)
        
        var y = yPosition
        val rightX = (PAGE_WIDTH - MARGIN - 100).toFloat()
        
        // 小計
        canvas.drawText("小計：", rightX - 80, y.toFloat(), paint)
        canvas.drawText("¥${String.format("%,d", document.subtotal.toLong())}", rightX.toFloat(), y.toFloat(), paint)
        y += 20
        
        // 税金
        canvas.drawText("税金：", rightX - 80, y.toFloat(), paint)
        canvas.drawText("¥${String.format("%,d", document.tax.toLong())}", rightX.toFloat(), y.toFloat(), paint)
        y += 20
        
        // 合計
        canvas.drawText("合計：", rightX - 80, y.toFloat(), boldPaint)
        canvas.drawText("¥${String.format("%,d", document.total.toLong())}", rightX.toFloat(), y.toFloat(), boldPaint)
        
        return y + 20
    }

    private fun getPaint(bold: Boolean = false, size: Float = 12f): Paint {
        return Paint().apply {
            this.typeface = if (bold) Typeface.create(Typeface.DEFAULT, Typeface.BOLD) else Typeface.DEFAULT
            this.textSize = size
            this.color = Color.BLACK
        }
    }

    private fun formatDate(timestamp: Long): String {
        val sdf = SimpleDateFormat("yyyy年MM月dd日", Locale.JAPAN)
        return sdf.format(Date(timestamp))
    }

    private fun parseDocumentItems(itemsJson: String): List<DocumentItemDto> {
        return try {
            val gson = Gson()
            gson.fromJson(itemsJson, Array<DocumentItemDto>::class.java).toList()
        } catch (e: Exception) {
            emptyList()
        }
    }
}
