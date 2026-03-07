# システムアーキテクチャ概要

**販売アシスト1号 / 母艦「お局様」**

**最終更新**: 2026-03-08

---

## 🏗️ システム構成

### 二層アーキテクチャ

```
┌─────────────────────────────────────────────┐
│  販売アシスト1号（Flutter/Dart）              │
│  ┌─────────────────────────────────────┐    │
│  │  UI Layer (Screens/Widgets)         │    │
│  └─────────────────────────────────────┘    │
│  ┌─────────────────────────────────────┐    │
│  │  Business Logic (Services)          │    │
│  └─────────────────────────────────────┘    │
│  ┌─────────────────────────────────────┐    │
│  │  Data Layer (Repositories)          │    │
│  └─────────────────────────────────────┘    │
│  ┌─────────────────────────────────────┐    │
│  │  SQLite Database                    │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
         ↕ 同期（LAN/Gmail）
┌─────────────────────────────────────────────┐
│  母艦「お局様」（Dart Server）                │
│  ┌─────────────────────────────────────┐    │
│  │  HTTP Server (Shelf)                │    │
│  └─────────────────────────────────────┘    │
│  ┌─────────────────────────────────────┐    │
│  │  Data Store                         │    │
│  └─────────────────────────────────────┘    │
│  ┌─────────────────────────────────────┐    │
│  │  Chat Store                         │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

---

## 📱 端末側アーキテクチャ

### レイヤー構成

#### 1. UI Layer（画面・ウィジェット）

**責務**: ユーザーインターフェース

**主要コンポーネント**:
- `lib/screens/` - 40画面以上
- `lib/widgets/` - 再利用可能ウィジェット
- 汎用テンプレート:
  - `GenericListScreen<T>`
  - `GenericFormScreen<T>`
  - `GenericDetailScreen<T>`
  - `DocumentCard`

#### 2. Business Logic Layer（ビジネスロジック）

**責務**: 業務ロジック、外部連携

**主要コンポーネント**:
- `lib/services/` - サービスクラス
  - `database_helper.dart` - DB管理
  - `pdf_generator.dart` - PDF生成
  - `email_sender.dart` - メール送信
  - `google_account_service.dart` - Google認証
  - `drive_backup_service.dart` - Driveバックアップ
  - `gmail_sync_client.dart` - Gmail同期
  - `mothership_client.dart` - 母艦通信
  - `gps_service.dart` - GPS位置情報

#### 3. Data Layer（データアクセス）

**責務**: データの永続化・取得

**主要コンポーネント**:
- `lib/services/*_repository.dart` - リポジトリクラス
  - `invoice_repository.dart`
  - `customer_repository.dart`
  - `product_repository.dart`
  - `quotation_repository.dart`
  - `sales_repository.dart`
  - etc.

#### 4. Model Layer（データモデル）

**責務**: データ構造定義

**主要コンポーネント**:
- `lib/models/` - データモデル
  - `base_document.dart` - 抽象基底クラス
  - `invoice_model.dart`
  - `customer_model.dart`
  - `product_model.dart`
  - etc.

---

## 🗄️ データベース設計

### SQLite（gemi_invoice.db）

**バージョン**: 33

#### テーブル分類

**マスタテーブル**:
- `customers` - 顧客
- `products` - 商品
- `suppliers` - 仕入先
- `warehouses` - 倉庫
- `staff` - 担当者
- `company_info` - 会社情報

**伝票テーブル**:
- `invoices` / `invoice_items` - 請求書・伝票
- `quotations` / `quotation_items` - 見積
- `sales` / `sales_items` - 売上

**在庫テーブル**:
- `warehouse_stock` - 倉庫別在庫
- `stock_transfers` - 在庫移動

**仕入テーブル**:
- `purchase_entries` - 仕入入力
- `purchase_receipts` - 支払予定

**システムテーブル**:
- `app_settings` - アプリ設定
- `app_gps_history` - GPS履歴
- `chat_messages` - チャットメッセージ
- `activity_log` - アクティビティログ

詳細は `docs/03_ARCHITECTURE.md` を参照。

---

## 🔄 同期メカニズム

### 二重同期プロトコル

#### 1. LAN直接通信（優先）

```
端末 → 母艦: HTTP POST /sync/heartbeat
母艦 → 端末: 200 OK

端末 → 母艦: HTTP POST /sync/hash
母艦 → 端末: 200 OK

端末 → 母艦: HTTP POST /chat/send
母艦 → 端末: 200 OK
```

**特徴**:
- GPS位置ベース自動検出
- 低レイテンシ
- リアルタイム同期

#### 2. Gmail経由同期（フォールバック）

```
端末 → Gmail: エンベロープ送信（BCC）
母艦 → Gmail: エンベロープ取得
母艦: データ処理
```

**特徴**:
- インターネット経由
- 非同期
- 信頼性高い

### 同期データ形式

**GmailSyncEnvelope**:
```dart
{
  "clientId": "device-001",
  "messageId": "msg-123",
  "payloadType": "chat_message",
  "payload": {...},
  "createdAt": 1234567890,
  "encoding": "gzip"  // or "plain"
}
```

---

## 🎨 汎用テンプレートシステム

### GenericListScreen<T>

**150行で完全なリスト画面を実装**

```dart
GenericListScreen<Quotation>(
  screenId: 'Q1',
  screenTitle: '見積入力',
  repository: QuotationRepository(),
  itemBuilder: (quotation) => DocumentCard(document: quotation),
  onTap: (quotation) => Navigator.push(...),
  onAdd: () => Navigator.push(...),
)
```

**機能**:
- 検索
- フィルタリング
- ソート
- 空状態表示
- エラーハンドリング
- リフレッシュ

### DocumentCard

**伝票カード表示の統一**

```dart
DocumentCard(
  document: quotation,
  statusColor: Colors.blue,
  onTap: () => ...,
  onEdit: () => ...,
  onDelete: () => ...,
)
```

### BaseDocument

**共通伝票モデル**

```dart
abstract class BaseDocument {
  String get id;
  String get documentNumber;
  DateTime get date;
  Customer? get customer;
  List<DocumentItem> get items;
  int get total;
  DocumentStatus get status;
}
```

---

## 🔐 セキュリティ設計

### データ保護

**ローカルストレージ**:
- SQLite（非暗号化）
- 印影のみ暗号化検討

**通信**:
- LAN: HTTP（ローカルネットワーク）
- Gmail: OAuth 2.0 + TLS

**認証**:
- 端末: PIN/生体認証（計画中）
- 母艦: APIキー認証

### バックアップ

**自動バックアップ**:
- Google Drive（24時間ごと）
- 母艦（リアルタイム）

**リストア**:
- 初回起動時提案
- 手動リストア

---

## 📊 パフォーマンス最適化

### データベース

**インデックス**:
```sql
CREATE INDEX idx_invoices_date ON invoices(date);
CREATE INDEX idx_invoices_customer ON invoices(customer_id);
CREATE INDEX idx_products_barcode ON products(barcode);
```

**クエリ最適化**:
- LIMIT句の活用
- 必要なカラムのみSELECT
- JOIN最小化

### UI

**非同期処理**:
```dart
Future.microtask(() async {
  // 重い処理
});
```

**Widget最適化**:
- const constructor
- ListView.builder
- 不要な再描画防止

---

## 🧪 テスト戦略

### 現状

- `flutter analyze` - エラー0件
- `flutter test` - 全テスト通過

### 今後の計画

**ユニットテスト**:
- リポジトリクラス
- ビジネスロジック

**ウィジェットテスト**:
- 汎用テンプレート
- カスタムウィジェット

**統合テスト**:
- 画面遷移
- データフロー

---

## 🔮 将来のアーキテクチャ拡張

### Phase 1: イベントソーシング

**目的**: 電子帳簿保存法対応

```dart
EventRecord {
  eventType: 'created',
  entityType: 'invoice',
  data: {...},
  previousHash: 'abc123',
  currentHash: 'def456',
}
```

### Phase 2: マルチスレッド処理

**目的**: スマホ性能活用

```dart
compute(_analyzeSalesInBackground, salesData);
```

### Phase 3: プラグインアーキテクチャ

**目的**: 業種カスタマイズ

```dart
BusinessProfile {
  features: [GPS, Photo, VoiceMemo],
  customFields: [...],
}
```

---

## 📚 関連ドキュメント

- **技術詳細**: `docs/03_ARCHITECTURE.md`
- **プロジェクト概要**: `docs/01_OVERVIEW.md`
- **実装状況**: `docs/02_CURRENT_STATUS.md`
- **開発ロードマップ**: `ROADMAP.md`
- **コーディングガイド**: `docs/CODING_GUIDE.md`（作成予定）

---

このアーキテクチャは、シンプルさと拡張性のバランスを重視しています。
