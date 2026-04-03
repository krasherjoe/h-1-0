# 今後の計画詳細

**販売アシスト1号 / 母艦「お局様」**

**最終更新**: 2026-03-08

---

## 🎯 計画の全体像

3つの主要な拡張計画を統合し、スマートフォンの真の性能を引き出す販売管理システムを構築します。

### 統合テーマ

**「スマホは20年前のスーパーコンピューターより高性能」を証明する**

1. **業種カスタマイズ** - あらゆる業種に対応
2. **電子帳簿保存法対応** - 法令遵守
3. **スマホ性能活用** - 真の性能を引き出す

---

## 📋 Phase 1: 業種カスタマイズ機能

**期間**: 2026-04-01 〜 2026-04-30（4週間）  
**優先度**: 🔴 高  
**詳細設計**: `.windsurf/plans/archive/universal-business-customization-plan-b8753f.md`

### 目標

**「カスタマイズなしで耐えられる汎用性」**

焼き芋屋から建設業まで、7つの異なる業種すべてでコード変更なしで使えるシステムを構築します。

### 対象業種

| 業種 | 特徴 | 固有要件 |
|------|------|----------|
| 🍠 焼き芋屋 | 移動販売、現金 | GPS記録、簡易レジ、日次締め |
| 🐟 たいやき屋 | 店舗、製造 | 原材料管理、製造数記録 |
| 💻 HP制作 | 受注制作 | 工程管理、時間記録、請求書 |
| ⚡ 電気屋 | 販売＋工事 | 見積、工事記録、部品在庫 |
| 🏗️ 建設業 | 大型案件 | 現場管理、写真記録、工程表 |
| 🛢️ 灯油配達 | 定期配送 | 配達ルート、使用量記録 |
| 🌾 米通販 | 通販、定期 | 発送管理、定期配送設定 |

### 実装内容

#### Week 1-2: 基盤整備

**BusinessProfile機能**
```dart
class BusinessProfile {
  final String businessType;        // 業種
  final List<String> productUnits;  // 使用する単位
  final bool needsInventory;        // 在庫管理の要否
  final bool needsGPS;              // GPS記録の要否
  final bool needsPhotos;           // 写真記録の要否
  final WorkflowType workflow;      // 業務フロー
  final PricingType pricing;        // 価格体系
}
```

**CustomField機能**
```dart
class CustomFieldManager {
  Future<void> defineField(String fieldName, FieldType type);
  Future<void> saveCustomData(String documentId, Map<String, dynamic> data);
  Future<Map<String, dynamic>> getCustomData(String documentId);
}
```

**データベース拡張**
```sql
CREATE TABLE custom_field_definitions (
  id TEXT PRIMARY KEY,
  field_name TEXT NOT NULL,
  field_type TEXT NOT NULL,
  target_entity TEXT NOT NULL,
  is_required INTEGER DEFAULT 0
);

CREATE TABLE custom_field_values (
  id TEXT PRIMARY KEY,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  field_name TEXT NOT NULL,
  field_value TEXT
);
```

#### Week 3-4: 業種テンプレート

**7業種のプリセット作成**
- 業種設定画面
- 業種別サンプルデータ
- 業種別ヘルプ

**動的UI生成**
```dart
class DynamicFormBuilder {
  Widget buildForm(BusinessProfile profile, BaseDocument document) {
    return Column(
      children: [
        ...buildCommonFields(document),
        ...profile.customFields.map((field) => 
          buildCustomField(field, document.customFields[field.name])
        ),
      ],
    );
  }
}
```

### 成功指標

- ✅ 7業種すべてで実業務に使える
- ✅ 業種固有要件を設定だけで満たせる
- ✅ 新業種でも30分以内に設定完了
- ✅ コード変更なしで対応できる

---

## 📋 Phase 2: 電子帳簿保存法対応

**期間**: 2026-05-01 〜 2026-07-31（12週間）  
**優先度**: 🔴 高  
**詳細設計**: `.windsurf/plans/archive/electronic-bookkeeping-law-compliance-plan-b8753f.md`

### 目標

**電子帳簿保存法の全要件を満たす**

2024年1月施行の電子帳簿保存法に完全対応し、税務調査にも耐えられるシステムを構築します。

### 電帳法の3要件

#### 1. 真実性の確保

**イベントソーシング**
```dart
class EventRecord {
  final String id;
  final String eventType;        // created, updated, deleted
  final String entityType;       // invoice, customer, product
  final String entityId;
  final Map<String, dynamic> data;
  final String userId;
  final DateTime timestamp;
  final String previousHash;     // 前イベントのハッシュ
  final String currentHash;      // このイベントのハッシュ
}
```

**ハッシュチェーン**
```
Event1 → Event2 → Event3 → Event4
Hash1 → Hash2 → Hash3 → Hash4

改ざんすると後続のハッシュが全て不一致
→ 完全な改ざん検知
```

#### 2. 可視性の確保

**検索機能**
- 日付範囲検索
- 金額範囲検索
- 取引先検索
- 複合検索（2つ以上の条件）

**出力機能**
- CSV出力
- PDF出力
- 整然とした形式

#### 3. 保存期間

**7年間保存**
- 母艦で一元管理
- 自動バックアップ
- アーカイブ機能

### 実装内容

#### Week 1-3: イベントソーシング基盤

**データベース**
```sql
CREATE TABLE event_log (
  id TEXT PRIMARY KEY,
  event_type TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  data TEXT NOT NULL,
  user_id TEXT NOT NULL,
  timestamp TEXT NOT NULL,
  previous_hash TEXT,
  current_hash TEXT NOT NULL,
  synced_to_mothership INTEGER DEFAULT 0
);
```

**EventLogger**
```dart
class EventLogger {
  Future<void> logEvent({
    required String eventType,
    required String entityType,
    required String entityId,
    required Map<String, dynamic> data,
  }) async {
    final previousHash = await _getLatestHash();
    final event = EventRecord(
      eventType: eventType,
      entityType: entityType,
      entityId: entityId,
      data: data,
      previousHash: previousHash,
      currentHash: _calculateHash(data, previousHash),
    );
    await _db.insertEvent(event);
    await _syncToMothership(event);
  }
}
```

#### Week 4-6: 検索・出力機能

**検索API**
```dart
class ElectronicBookkeepingSearch {
  Future<List<Invoice>> searchByDate({
    DateTime? startDate,
    DateTime? endDate,
  });
  
  Future<List<Invoice>> searchByAmount({
    int? minAmount,
    int? maxAmount,
  });
  
  Future<List<Invoice>> searchByCustomer(String customerId);
  
  Future<List<Invoice>> searchByCombination({
    DateTime? startDate,
    DateTime? endDate,
    int? minAmount,
    int? maxAmount,
    String? customerId,
  });
}
```

#### Week 7-9: 母艦同期拡張

**イベント同期**
```dart
class EventSyncPayload {
  final String clientId;
  final List<EventRecord> events;
  final String chainHash;
  
  bool verifyChain() {
    for (int i = 1; i < events.length; i++) {
      if (events[i].previousHash != events[i-1].currentHash) {
        return false;
      }
    }
    return true;
  }
}
```

#### Week 10-12: 監査機能

**監査証跡出力**
```dart
class AuditTrailExporter {
  Future<File> exportAuditTrail({
    required DateTime startDate,
    required DateTime endDate,
  });
  
  Future<File> exportVerificationReport();
}
```

---

## 📋 Phase 3: スマホ性能活用機能

**期間**: 2026-06-01 〜 2026-08-31（12週間）  
**優先度**: 🟡 中  
**詳細設計**: `.windsurf/plans/archive/smartphone-standalone-enhancement-plan-b8753f.md`

### 目標

**「スマホは20年前のスーパーコンピューター」を証明**

### スマホの性能を最大限活用

#### 1. 計算能力の活用

**マルチスレッド処理**
```dart
// Isolateで並列処理
Future<SalesAnalysis> analyzeSales() async {
  return await compute(_analyzeSalesInBackground, salesData);
}

SalesAnalysis _analyzeSalesInBackground(List<Sales> data) {
  // 数万件のデータを集計
  // UIをブロックせずに高速処理
}
```

**高速検索**
```sql
-- FTS（Full-Text Search）
CREATE VIRTUAL TABLE products_fts USING fts5(
  name, description, barcode
);
```

**リアルタイム分析**
- 売上推移のリアルタイムグラフ
- 在庫評価額の即時計算
- 粗利分析の高速処理

#### 2. センサーの活用

**GPS**
```dart
// 顧客訪問を自動記録
if (await _isNearCustomer(currentLocation, customer)) {
  await _recordVisit(customer, currentLocation);
  _showNotification('${customer.name}様への訪問を記録しました');
}
```

**カメラ**
```dart
// 納品時の写真を自動圧縮・保存
final photo = await ImagePicker().pickImage(source: ImageSource.camera);
final compressed = await _compressImage(photo);
await _saveDeliveryPhoto(deliveryId, compressed);
```

**マイク**
- 商談内容の音声記録
- 音声入力による検索
- 音声メモ機能

#### 3. UI/UX最適化

**片手操作モード**
- 下部FABメニュー
- スワイプジェスチャー
- タップターゲットサイズ最適化

**ダークモード**
- 屋外視認性向上
- バッテリー節約

**クイックアクション**
- ホーム画面ショートカット
- 3D Touch対応

### 実装内容

#### Week 1-3: 計算能力活用
- Dart Isolate実装
- リアルタイム分析
- FTS検索

#### Week 4-6: センサー活用
- GPS自動記録
- 写真証跡管理
- 音声メモ

#### Week 7-9: UI/UX最適化
- 片手操作モード
- ダークモード
- クイックアクション

#### Week 10-12: 高度な機能
- 配達ルート最適化
- QRコード決済
- P2P通信

---

## 🔮 Phase 4: 高度な機能（継続的）

**期間**: 2026-09-01 〜（継続的）  
**優先度**: 🟢 低

### ビジネス機能

- 定期配送管理
- 工程管理機能
- プロジェクト管理
- 時間記録機能
- 契約管理

### 分析機能

- ABC分析
- 在庫評価額分析
- 顧客別収益性分析
- 商品別回転率分析
- 予算実績管理

### 連携機能

- 会計ソフト連携
- ECサイト連携
- 決済端末連携
- POSレジ連携
- 配送業者連携

---

## 📊 実装優先順位マトリクス

| 機能 | 優先度 | 期間 | 効果 | 難易度 |
|------|--------|------|------|--------|
| 業種カスタマイズ | 🔴 高 | 4週 | 大 | 中 |
| 電子帳簿保存法 | 🔴 高 | 12週 | 大 | 高 |
| スマホ性能活用 | 🟡 中 | 12週 | 中 | 中 |
| 高度な機能 | 🟢 低 | 継続 | 小 | 低 |

---

## 🎯 マイルストーン

### 2026年4月
- 業種カスタマイズ機能完成
- 7業種対応完了

### 2026年7月
- 電子帳簿保存法対応完成
- イベントソーシング実装完了

### 2026年8月
- スマホ性能活用機能完成
- リアルタイム分析実装完了

### 2026年12月
- 高度な機能の実装開始
- 外部連携機能の実装

---

## 💡 実装時の注意点

### 1. 既存機能との互換性

**後方互換性を維持**
- 既存データの移行
- 既存画面の動作保証
- 段階的な移行

### 2. パフォーマンス

**スマホの制約を考慮**
- バッテリー消費
- メモリ使用量
- ストレージ容量

### 3. ユーザビリティ

**使いやすさを最優先**
- 複雑な設定は不要
- デフォルトで動作
- 段階的な機能開示

---

## 📚 関連ドキュメント

- **プロジェクト概要**: `docs/01_OVERVIEW.md`
- **実装状況**: `docs/02_CURRENT_STATUS.md`
- **アーキテクチャ**: `ARCHITECTURE.md`
- **開発ロードマップ**: `ROADMAP.md`
- **コーディングガイド**: `docs/CODING_GUIDE.md`
- **タスクテンプレート**: `docs/TASK_TEMPLATES.md`

---

この計画に従って、段階的に機能を拡張していきます。
