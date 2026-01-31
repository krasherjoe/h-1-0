// app/src/main/java/com/example/mobilepos/data/api/SyncApiService.kt

package com.example.mobilepos.data.api

import retrofit2.Response
import retrofit2.http.*
import com.example.mobilepos.data.models.*
import java.util.UUID

interface SyncApiService {
    
    @POST("/api/v1/sync")
    suspend fun syncDocuments(
        @Header("X-API-Key") apiKey: String,
        @Body request: SyncRequestDto
    ): Response<SyncResponseDto>

    @GET("/api/v1/customers")
    suspend fun getCustomers(
        @Header("X-API-Key") apiKey: String
    ): Response<CustomerListResponse>

    @GET("/api/v1/documents/{id}")
    suspend fun getDocument(
        @Header("X-API-Key") apiKey: String,
        @Path("id") documentId: Int
    ): Response<DocumentDetailResponse>

    @POST("/api/v1/receipts/{invoiceId}")
    suspend fun createReceipt(
        @Header("X-API-Key") apiKey: String,
        @Path("invoiceId") invoiceId: Int
    ): Response<ReceiptCreateResponse>

    @GET("/api/v1/health")
    suspend fun healthCheck(
        @Header("X-API-Key") apiKey: String
    ): Response<HealthCheckResponse>
}

// ========== API Response Models ==========

data class CustomerListResponse(
    val status: String,
    val customers: List<CustomerDto>
)

data class DocumentDetailResponse(
    val status: String,
    val document: DocumentDto
)

data class ReceiptCreateResponse(
    val status: String,
    val receiptId: Int,
    val message: String
)

data class HealthCheckResponse(
    val status: String,
    val timestamp: Long
)

// ========== Retrofit Factory ==========

import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import com.google.gson.GsonBuilder

object ApiClient {
    private var retrofit: Retrofit? = null
    
    fun getClient(baseUrl: String): Retrofit {
        if (retrofit == null) {
            val httpLoggingInterceptor = HttpLoggingInterceptor().apply {
                level = HttpLoggingInterceptor.Level.BODY
            }
            
            val okHttpClient = OkHttpClient.Builder()
                .addInterceptor(httpLoggingInterceptor)
                .connectTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
                .readTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
                .writeTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
                .build()
            
            val gson = GsonBuilder()
                .setDateFormat("yyyy-MM-dd'T'HH:mm:ss")
                .create()
            
            retrofit = Retrofit.Builder()
                .baseUrl(baseUrl)
                .client(okHttpClient)
                .addConverterFactory(GsonConverterFactory.create(gson))
                .build()
        }
        return retrofit!!
    }
    
    fun getSyncApiService(baseUrl: String): SyncApiService {
        return getClient(baseUrl).create(SyncApiService::class.java)
    }
}
