// app/src/main/java/com/example/mobilepos/data/AppDatabase.kt

package com.example.mobilepos.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import com.example.mobilepos.data.dao.*
import com.example.mobilepos.data.models.*

@Database(
    entities = [
        CustomerEntity::class,
        DocumentEntity::class,
        PaymentTermsEntity::class,
        SyncLogEntity::class
    ],
    version = 2,
    exportSchema = true
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun customerDao(): CustomerDao
    abstract fun documentDao(): DocumentDao
    abstract fun paymentTermsDao(): PaymentTermsDao
    abstract fun syncLogDao(): SyncLogDao

    companion object {
        @Volatile
        private var INSTANCE: AppDatabase? = null

        fun getInstance(context: Context): AppDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    AppDatabase::class.java,
                    "mobile_pos_database"
                )
                    .addMigrations(MIGRATION_1_2)
                    .build()
                INSTANCE = instance
                instance
            }
        }

        // マイグレーション: v1 -> v2
        private val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(database: SupportSQLiteDatabase) {
                // syncTimestamp カラムを追加
                database.execSQL(
                    "ALTER TABLE documents ADD COLUMN syncTimestamp INTEGER"
                )
                // インデックスを追加（パフォーマンス向上）
                database.execSQL(
                    "CREATE INDEX IF NOT EXISTS idx_documents_customerId ON documents(customerId)"
                )
                database.execSQL(
                    "CREATE INDEX IF NOT EXISTS idx_documents_docType ON documents(docType)"
                )
                database.execSQL(
                    "CREATE INDEX IF NOT EXISTS idx_documents_status ON documents(status)"
                )
                database.execSQL(
                    "CREATE INDEX IF NOT EXISTS idx_documents_synced ON documents(synced)"
                )
            }
        }
    }
}
