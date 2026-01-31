// app/src/main/java/com/example/mobilepos/data/dao/DocumentDao.kt

package com.example.mobilepos.data.dao

import androidx.room.*
import com.example.mobilepos.data.models.*
import kotlinx.coroutines.flow.Flow

@Dao
interface CustomerDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertCustomer(customer: CustomerEntity)

    @Update
    suspend fun updateCustomer(customer: CustomerEntity)

    @Delete
    suspend fun deleteCustomer(customer: CustomerEntity)

    @Query("SELECT * FROM customers WHERE id = :id")
    suspend fun getCustomerById(id: Int): CustomerEntity?

    @Query("SELECT * FROM customers ORDER BY name ASC")
    fun getAllCustomers(): Flow<List<CustomerEntity>>

    @Query("SELECT * FROM customers WHERE synced = 0")
    suspend fun getUnsyncedCustomers(): List<CustomerEntity>

    @Query("UPDATE customers SET synced = 1 WHERE id = :id")
    suspend fun markCustomerAsSynced(id: Int)
}

@Dao
interface DocumentDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertDocument(document: DocumentEntity): Long

    @Update
    suspend fun updateDocument(document: DocumentEntity)

    @Delete
    suspend fun deleteDocument(document: DocumentEntity)

    @Query("SELECT * FROM documents WHERE id = :id")
    suspend fun getDocumentById(id: Int): DocumentEntity?

    @Query("SELECT * FROM documents WHERE customerId = :customerId ORDER BY documentDate DESC")
    fun getDocumentsByCustomer(customerId: Int): Flow<List<DocumentEntity>>

    @Query("SELECT * FROM documents WHERE docType = :docType ORDER BY documentDate DESC")
    fun getDocumentsByType(docType: String): Flow<List<DocumentEntity>>

    @Query("SELECT * FROM documents WHERE status = :status ORDER BY documentDate DESC")
    fun getDocumentsByStatus(status: String): Flow<List<DocumentEntity>>

    @Query("SELECT * FROM documents WHERE docType = 'invoice' AND paidDate IS NULL ORDER BY paymentDueDate ASC")
    fun getUnpaidInvoices(): Flow<List<DocumentEntity>>

    @Query("SELECT * FROM documents WHERE synced = 0")
    suspend fun getUnsyncedDocuments(): List<DocumentEntity>

    @Query("SELECT * FROM documents ORDER BY documentDate DESC")
    fun getAllDocuments(): Flow<List<DocumentEntity>>

    @Query("UPDATE documents SET synced = 1, syncTimestamp = :timestamp WHERE id = :id")
    suspend fun markDocumentAsSynced(id: Int, timestamp: Long)

    @Query("UPDATE documents SET status = :status, paidDate = :paidDate WHERE id = :id")
    suspend fun updateDocumentStatus(id: Int, status: String, paidDate: Long?)

    @Query("UPDATE documents SET paymentDueDate = :dueDate WHERE id = :id")
    suspend fun updatePaymentDueDate(id: Int, dueDate: Long)

    @Query("DELETE FROM documents WHERE docType = :docType")
    suspend fun deleteDocumentsByType(docType: String)
}

@Dao
interface PaymentTermsDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertPaymentTerms(terms: PaymentTermsEntity)

    @Query("SELECT * FROM payment_terms WHERE documentId = :documentId")
    suspend fun getPaymentTermsByDocument(documentId: Int): PaymentTermsEntity?

    @Query("SELECT * FROM payment_terms ORDER BY createdAt DESC")
    suspend fun getAllPaymentTerms(): List<PaymentTermsEntity>

    @Delete
    suspend fun deletePaymentTerms(terms: PaymentTermsEntity)
}

@Dao
interface SyncLogDao {
    @Insert
    suspend fun insertSyncLog(log: SyncLogEntity)

    @Query("SELECT * FROM sync_logs ORDER BY timestamp DESC LIMIT :limit")
    suspend fun getRecentSyncLogs(limit: Int = 10): List<SyncLogEntity>

    @Query("SELECT * FROM sync_logs WHERE deviceId = :deviceId ORDER BY timestamp DESC LIMIT :limit")
    suspend fun getSyncLogsByDevice(deviceId: String, limit: Int = 10): List<SyncLogEntity>

    @Query("SELECT MAX(timestamp) FROM sync_logs WHERE operation = 'sync' AND status = 'success'")
    suspend fun getLastSuccessfulSyncTime(): Long?

    @Query("DELETE FROM sync_logs WHERE timestamp < :olderThanMillis")
    suspend fun deleteSyncLogsOlderThan(olderThanMillis: Long)
}
