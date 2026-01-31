# モバイルPOS・見積/納品/請求/領収書システム

## 概要

Proxmox CT上で動作するオフラインファーストのスマートフォンアプリケーション。
営業現場で完全スタンドアロンで見積・納品・請求・領収書を作成・管理し、
ネットワーク接続時にOdooと同期します。

## アーキテクチャ

```
┌─────────────────┐
│  Android App    │ ← スマホ（完全オフライン対応）
│  SQLite DB      │
│  PDF生成        │
└────────┬────────┘
         │ (ネットワーク接続時)
         │
    ┌────▼─────────────────────────┐
    │  REST API コンテナ            │
    │  (Python FastAPI)             │
    │  - 同期エンドポイント          │
    │  - Odoo連携                   │
    └────┬────────────────┬─────────┘
         │                │
    ┌────▼──────┐  ┌─────▼─────┐
    │ PostgreSQL│  │   Odoo    │
    │   DB      │  │ (Sales)   │
    └───────────┘  └───────────┘
```

## ディレクトリ構成

```
project_root/
├── docker-compose.yml          # Odoo + API + DB
├── api/
│   ├── main.py                 # FastAPI メイン
│   ├── requirements.txt
│   └── Dockerfile
├── addons/                      # Odooカスタムモジュール
├── scheduler/                   # 定期同期スクリプト
└── android/
    ├── Models.kt               # データモデル
    ├── DAO.kt                  # Room DAO
    ├── Database.kt             # Room DB
    ├── ApiService.kt           # Retrofit API
    └── PdfGenerator.kt         # PDF生成
```

## セットアップ手順

### 1. Docker環境構築（Proxmox CT）

```bash
# リポジトリクローン
git clone <your-repo-url>
cd project_root

# 環境変数設定
cp .env.example .env
# .envを編集（API_SECRET_KEY等）

# コンテナ起動
docker-compose up -d

# ログ確認
docker-compose logs -f api
docker-compose logs -f odoo
```

### 2. Odooの初期セットアップ

```bash
# Odooにアクセス
# http://localhost:8069

# 以下のモジュールを有効化
# - Sales (見積・受注管理)
# - Invoicing (請求・領収書)
# - Accounting (会計・売掛金)

# API認証設定
# Admin > 設定 > API キーを生成
```

### 3. REST APIの初期化

```bash
# DB テーブル作成
docker-compose exec api python -c "from main import Base, engine; Base.metadata.create_all(bind=engine)"

# テスト
curl -X GET http://localhost:8000/api/v1/health \
  -H "X-API-Key: your_secret_key"
```

### 4. Androidアプリ開発

#### 依存パッケージ (build.gradle)

```gradle
dependencies {
    // Room
    implementation "androidx.room:room-runtime:2.6.0"
    implementation "androidx.room:room-ktx:2.6.0"
    kapt "androidx.room:room-compiler:2.6.0"
    
    // Retrofit
    implementation "com.squareup.retrofit2:retrofit:2.9.0"
    implementation "com.squareup.retrofit2:converter-gson:2.9.0"
    implementation "com.squareup.okhttp3:logging-interceptor:4.11.0"
    
    // Coroutines
    implementation "org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3"
    
    // Jetpack Compose
    implementation "androidx.compose.ui:ui:1.6.0"
    implementation "androidx.compose.material3:material3:1.1.0"
    
    // PDF (iText or Apache POI)
    implementation "com.itextpdf:itext-core:8.0.0"
    
    // Gson
    implementation "com.google.code.gson:gson:2.10.1"
}
```

#### AndroidManifest.xml の設定

```xml
<!-- パーミッション -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

#### build.gradle 設定

```gradle
android {
    compileSdk 34
    
    defaultConfig {
        applicationId "com.example.mobilepos"
        minSdk 26
        targetSdk 34
    }
    
    buildFeatures {
        compose = true
    }
    
    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.0"
    }
}
```

## API エンドポイント

### 同期

**POST** `/api/v1/sync`
```bash
curl -X POST http://localhost:8000/api/v1/sync \
  -H "X-API-Key: secret_key" \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "device_001",
    "last_sync_timestamp": null,
    "documents": [
      {
        "doc_type": "quotation",
        "customer_id": 1,
        "document_date": "2026-01-31T10:00:00",
        "items": [
          {
            "product_name": "商品A",
            "quantity": 10,
            "unit_price": 1000,
            "subtotal": 10000
          }
        ],
        "subtotal": 10000,
        "tax": 1000,
        "total": 11000,
        "payment_terms": {
          "billing_date": "2026-01-31",
          "payment_due_date": "2026-02-28",
          "payment_method": "bank_transfer"
        }
      }
    ]
  }'
```

### 顧客一覧

**GET** `/api/v1/customers`
```bash
curl http://localhost:8000/api/v1/customers \
  -H "X-API-Key: secret_key"
```

### ドキュメント取得

**GET** `/api/v1/documents/{id}`

### 領収書自動生成

**POST** `/api/v1/receipts/{invoice_id}`
```bash
# 入金から1週間以内の請求書から領収書を生成
curl -X POST http://localhost:8000/api/v1/receipts/1 \
  -H "X-API-Key: secret_key"
```

## Android実装ガイド

### 1. データベース初期化

```kotlin
val db = AppDatabase.getInstance(context)
val documentDao = db.documentDao()
val customerDao = db.customerDao()
```

### 2. ドキュメント作成・保存

```kotlin
val document = DocumentEntity(
    docType = "quotation",
    customerId = 1,
    documentDate = System.currentTimeMillis(),
    items = Gson().toJson(listOf(
        DocumentItemDto("商品A", 10.0, 1000.0, 10000.0)
    )),
    subtotal = 10000.0,
    tax = 1000.0,
    total = 11000.0,
    paymentDueDate = calculateDueDate(PaymentPattern.END_OF_MONTH),
    synced = false
)

documentDao.insertDocument(document)
```

### 3. PDF生成

```kotlin
val file = PdfGenerator.generateQuotationPdf(
    context = context,
    document = document,
    customer = customer,
    fileName = "quotation_${document.id}.pdf"
)

// ファイル共有
val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
val shareIntent = Intent(Intent.ACTION_SEND).apply {
    type = "application/pdf"
    putExtra(Intent.EXTRA_STREAM, uri)
}
startActivity(Intent.createChooser(shareIntent, "PDFを共有"))
```

### 4. 同期処理

```kotlin
suspend fun syncDocuments(context: Context) {
    val apiKey = "your_secret_key"
    val baseUrl = "http://your_api_server:8000"
    val apiService = ApiClient.getSyncApiService(baseUrl)
    
    val db = AppDatabase.getInstance(context)
    val unsyncedDocs = db.documentDao().getUnsyncedDocuments()
    
    val request = SyncRequestDto(
        deviceId = getDeviceId(),
        documents = unsyncedDocs.map { convertToDto(it) }
    )
    
    try {
        val response = apiService.syncDocuments(apiKey, request)
        if (response.isSuccessful && response.body()?.status == "success") {
            response.body()?.newDocuments?.forEach { doc ->
                db.documentDao().markDocumentAsSynced(doc["local_id"] as Int, System.currentTimeMillis())
            }
        }
    } catch (e: Exception) {
        Log.e("Sync", "Error: ${e.message}")
    }
}
```

### 5. 支払期限の計算

```kotlin
fun calculatePaymentDueDate(billingDate: Long, pattern: PaymentPattern): Long {
    val calendar = Calendar.getInstance().apply {
        timeInMillis = billingDate
    }
    
    return when (pattern) {
        PaymentPattern.IMMEDIATE -> calendar.timeInMillis
        PaymentPattern.END_OF_MONTH -> {
            calendar.set(Calendar.DAY_OF_MONTH, 1)
            calendar.add(Calendar.MONTH, 1)
            calendar.add(Calendar.DAY_OF_MONTH, -1)
            calendar.timeInMillis
        }
        PaymentPattern.THIRTY_DAYS -> {
            calendar.add(Calendar.DAY_OF_MONTH, 30)
            calendar.timeInMillis
        }
        PaymentPattern.SIXTY_DAYS -> {
            calendar.add(Calendar.DAY_OF_MONTH, 60)
            calendar.timeInMillis
        }
        else -> calendar.timeInMillis
    }
}
```

## 同期フロー

### オフライン時
1. スマホアプリで見積/納品/請求/領収書を作成
2. SQLiteに自動保存
3. PDF生成・送信（メール等）

### ネットワーク接続時
1. 未同期ドキュメントを検出
2. REST APIに送信
3. API が Odoo に登録
4. 同期完了後、ローカルの synced フラグを更新
5. Odoo で売掛金管理・レポート生成

## 支払条件パターン

| パターン | 説明 | 計算方式 |
|---------|------|--------|
| 即支払い | 当日支払い | 請求日 |
| 末締め翌月末 | 末締めで翌月末払い | 翌月末日 |
| 30日後 | 請求日から30日後 | 請求日 + 30日 |
| 60日後 | 請求日から60日後 | 請求日 + 60日 |
| カスタム | 任意設定 | ユーザーが指定 |

## セキュリティ

- API キーは環境変数で管理
- HTTPS通信を推奨（本番環境）
- トークン認証で API アクセス制限
- Odoo への認証も環境変数化

## トラブルシューティング

### API接続エラー
```bash
# ヘルスチェック
curl http://localhost:8000/api/v1/health -H "X-API-Key: your_key"

# ログ確認
docker-compose logs api
```

### Odoo連携エラー
```bash
# Odooログ
docker-compose logs odoo

# DBテーブル確認
docker-compose exec postgres psql -U odoo -d odoo -c "\dt"
```

### Android PDF生成エラー
- ストレージパーミッション確認
- 外部ストレージ空き容量確認
- iText/Apache POI の対応バージョン確認

## 今後の実装予定

- [ ] Odoo REST API 直接連携
- [ ] Nextcloud WebDAV バックアップ統合
- [ ] 複数ユーザー・デバイス同期
- [ ] オフライン時の競合解決
- [ ] 売掛金ダッシュボード
- [ ] Web UI（PCから Odoo 管理用）
- [ ] カスタム領収書テンプレート
- [ ] 電子署名対応

## 開発者向け情報

### REST API テスト
```bash
# FastAPI ドキュメント
http://localhost:8000/docs
```

### DB マイグレーション
```bash
# 新しいテーブル追加時
# Android: Migrations クラスを追加
# API: SQLAlchemy モデルを追加 → DB再作成
```

## ライセンス

MIT License

## サポート

問題報告は Issues で。
