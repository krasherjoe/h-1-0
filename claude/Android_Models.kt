// app/src/main/java/com/example/mobilepos/data/models/Models.kt

package com.example.mobilepos.data.models

import androidx.room.Entity
import androidx.room.PrimaryKey
import androidx.room.TypeConverters
import java.util.Date

// ========== Room Database Entities ==========

@Entity(tableName = "customers")
data class CustomerEntity(
    @PrimaryKey
    val id: Int,
    val odooCustomerId: Int? = null,
    val name: String,
    val address: String? = null,
    val phone: String? = null,
    val email: String? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val synced: Boolean = false
)

@Entity(tableName = "documents")
data class DocumentEntity(
    @PrimaryKey
    val id: Int = 0,
    val odooId: Int? = null,
    val docType: String,  // quotation, delivery, invoice, receipt
    val customerId: Int,
    val documentDate: Long,
    val items: String,  // JSON string
    val subtotal: Double,
    val tax: Double,
    val total: Double,
    val status: String,  // draft, sent, confirmed, paid
    val billingDate: Long? = null,
    val paymentDueDate: Long,
    val paymentMethod: String? = null,
    val paidDate: Long? = null,
    val notes: String? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val synced: Boolean = false,
    val syncTimestamp: Long? = null
)

@Entity(tableName = "payment_terms")
data class PaymentTermsEntity(
    @PrimaryKey
    val id: Int = 0,
    val documentId: Int,
    val billingDate: Long? = null,
    val paymentDueDate: Long,
    val paymentMethod: String,
    val createdAt: Long = System.currentTimeMillis()
)

@Entity(tableName = "sync_logs")
data class SyncLogEntity(
    @PrimaryKey
    val id: Int = 0,
    val deviceId: String,
    val operation: String,  // sync, upload, download
    val documentCount: Int,
    val status: String,  // success, failure
    val message: String? = null,
    val timestamp: Long = System.currentTimeMillis()
)

// ========== Data Transfer Objects (DTOs) ==========

data class CustomerDto(
    val id: Int,
    val name: String,
    val address: String? = null,
    val phone: String? = null,
    val email: String? = null
)

data class DocumentItemDto(
    val productName: String,
    val quantity: Double,
    val unitPrice: Double,
    val subtotal: Double
)

data class PaymentTermsDto(
    val billingDate: Long? = null,
    val paymentDueDate: Long,
    val paymentMethod: String
)

data class DocumentDto(
    val id: Int = 0,
    val docType: String,
    val customerId: Int,
    val documentDate: Long,
    val items: List<DocumentItemDto>,
    val subtotal: Double,
    val tax: Double,
    val total: Double,
    val paymentTerms: PaymentTermsDto,
    val status: String = "draft",
    val notes: String? = null
)

data class SyncRequestDto(
    val deviceId: String,
    val lastSyncTimestamp: Long? = null,
    val documents: List<DocumentDto>
)

data class SyncResponseDto(
    val status: String,
    val message: String,
    val syncedDocuments: Int,
    val newDocuments: List<Map<String, Any>>? = null
)

// ========== UI State Models ==========

data class DocumentUIState(
    val id: Int = 0,
    val docType: String = "quotation",
    val customer: CustomerDto? = null,
    val customerId: Int = 0,
    val documentDate: Long = System.currentTimeMillis(),
    val items: List<DocumentItemDto> = emptyList(),
    val subtotal: Double = 0.0,
    val tax: Double = 0.0,
    val total: Double = 0.0,
    val billingDate: Long? = null,
    val paymentDueDate: Long = System.currentTimeMillis(),
    val paymentMethod: String = "bank_transfer",
    val status: String = "draft",
    val notes: String = "",
    val isSaving: Boolean = false,
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
    val showPaymentDatePicker: Boolean = false
)

data class DocumentListUIState(
    val documents: List<DocumentEntity> = emptyList(),
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
    val filter: String = "all"  // all, quotation, delivery, invoice, receipt
)

data class SyncUIState(
    val isSyncing: Boolean = false,
    val syncProgress: Int = 0,
    val lastSyncTime: Long? = null,
    val syncedCount: Int = 0,
    val totalCount: Int = 0,
    val errorMessage: String? = null,
    val status: String = "ready"
)

// ========== Payment Term Patterns ==========
enum class PaymentPattern(val displayName: String, val days: Int? = null) {
    IMMEDIATE("即支払い", 0),
    END_OF_MONTH("末締め翌月末", null),
    THIRTY_DAYS("30日後", 30),
    SIXTY_DAYS("60日後", 60),
    CUSTOM("カスタム", null)
}
