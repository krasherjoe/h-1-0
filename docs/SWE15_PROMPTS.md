# SWE1.5向けプロンプト集

**販売アシスト1号 - SWE1.5を効果的に活用する方法**

**最終更新**: 2026-03-08

---

## 🎯 SWE1.5とは

**SWE1.5（Software Engineering 1.5）**は、より軽量で効率的なAIコーディングアシスタントです。

### 特徴

**得意なこと** ✅
- 明確な指示に従った実装
- パターンベースのコード生成
- ステップバイステップの作業
- 既存コードのコピー&カスタマイズ
- 特定箇所の修正

**苦手なこと** ⚠️
- 曖昧な指示の解釈
- 大規模な設計判断
- アーキテクチャの決定
- 複数の大きなタスクを同時に

### 効果的な使い方の原則

**DO（良い指示）**:
- ✅ 具体的なファイル名とパスを指定
- ✅ コピー可能なコード例を全文提供
- ✅ ステップを明確に分割（1ステップ1タスク）
- ✅ チェックリストで確認項目を明示
- ✅ 参考ドキュメント・ファイルを指定

**DON'T（悪い指示）**:
- ❌ 「適切に実装して」のような曖昧な指示
- ❌ 複数の大きなタスクを一度に依頼
- ❌ 設計判断をAIに任せる
- ❌ コードの一部だけ提示して「残りはよろしく」

---

## � オートパイロット運用フロー

この章では、SWE1.5に長時間張り付かなくてもタスクを自律的に進められるよう、Stage単位の分割統治と進捗ログ連携を定義します。監督者（あなた）は `docs/PROGRESS.md` を確認し、完了していたら「次はStage Xを実行してください」と伝えるだけでOKです。

### Stage進行ルール

1. **Stage開始コマンド**：各Stageの冒頭で「内容を理解したら `Proceed Stage X` と返答してください」と指示。
2. **進捗ログ**：完了報告は必ず `docs/PROGRESS.md` に追記 → 同じ内容をチャットにも貼ってから待機。
3. **待機指示**：Stage完了後は「次のStage指示を受けるまで待機してください」と必ず伝える。
4. **途中再開**：Stage冒頭に「前回途中で止まっていた場合の再開方法」を明記し、途中終了しても自力で再開させる。

### Stage一覧（完了条件）

| Stage | 内容 | 完了確認 | 次の合図 |
|-------|------|----------|-----------|
| A | 例1 Step1-2（配送モデル＋リポジトリ） | ✅ Step2完了 | 「次はStage Bを実行してください」 |
| B | 例1 Step3（deliveriesテーブル追加） | ✅ Step3完了 | 「次はStage Cを実行してください」 |
| C | 例1 Step4-6（画面＋メニュー＋ルート＋確認） | ✅ Step6＋analyze＋動作 | 「次はStage Dを実行してください」 |
| D | 例2 Step1（在庫モデル） | ✅ Step1完了 | 「次はStage Eを実行してください」 |
| E | 例2 Step2（在庫リポジトリ） | ✅ Step2完了 | 「次はStage Fを実行してください」 |
| F | 例2 Step3（在庫画面＋確認） | ✅ Step3＋analyze | 「次はStage Gを実行してください」 |
| G | 例3＋4（null参照修正＋routeテーブル） | ✅ 2タスク完了 | 「次はStage Hを実行してください」 |
| H | 例5＋6（メニュー追加＋ウィジェット） | ✅ 2タスク完了 | 完了 |

---

## Stage A: 例1-1（配送モデル＆リポジトリ）

**開始宣言テンプレ**
```
Stage Aを開始します。内容を理解したら「Proceed Stage A」と返答してください。
```

**途中再開方法**
- docs/PROGRESS.md に Step1完了ログがあれば Step2 から再開
- ログがなければ Step1 から開始

### Step 1: `lib/models/delivery_model.dart`
```dart
import 'package:flutter/material.dart';
import 'base_document.dart';
import 'customer_model.dart';

class Delivery extends BaseDocument {
  final String deliveryAddress;
  final String? deliveryNote;

  Delivery({
    required super.id,
    required super.documentNumber,
    required super.date,
    super.customer,
    required super.items,
    required super.subtotal,
    required super.taxAmount,
    required super.total,
    required super.taxRate,
    super.notes,
    super.subject,
    required super.status,
    required super.createdAt,
    required super.updatedAt,
    required this.deliveryAddress,
    this.deliveryNote,
  });

  @override
  Color getStatusColor() {
    switch (status) {
      case DocumentStatus.draft:
        return Colors.grey;
      case DocumentStatus.confirmed:
        return Colors.blue;
      case DocumentStatus.cancelled:
        return Colors.red;
    }
  }

  @override
  Color getThemeColor() => Colors.green;

  @override
  String getDocumentTypeName() => '配送';

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'document_number': documentNumber,
      'date': date.toIso8601String(),
      'customer_id': customer?.id,
      'delivery_address': deliveryAddress,
      'delivery_note': deliveryNote,
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'total': total,
      'tax_rate': taxRate,
      'notes': notes,
      'subject': subject,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Delivery.fromMap(Map<String, dynamic> map, Customer? customer) {
    return Delivery(
      id: map['id'] as String,
      documentNumber: map['document_number'] as String,
      date: DateTime.parse(map['date'] as String),
      customer: customer,
      items: [],
      deliveryAddress: map['delivery_address'] as String,
      deliveryNote: map['delivery_note'] as String?,
      subtotal: map['subtotal'] as int,
      taxAmount: map['tax_amount'] as int,
      total: map['total'] as int,
      taxRate: (map['tax_rate'] as num).toDouble(),
      notes: map['notes'] as String?,
      subject: map['subject'] as String?,
      status: DocumentStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => DocumentStatus.draft,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
```

### Step 2: `lib/services/delivery_repository.dart`
```dart
import '../models/delivery_model.dart';
import '../models/customer_model.dart';
import 'database_helper.dart';
import 'customer_repository.dart';

class DeliveryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final CustomerRepository _customerRepo = CustomerRepository();

  Future<List<Delivery>> getAll() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'deliveries',
      orderBy: 'date DESC',
    );

    final List<Delivery> deliveries = [];
    for (var map in maps) {
      Customer? customer;
      if (map['customer_id'] != null) {
        customer = await _customerRepo.getById(map['customer_id'] as String);
      }
      deliveries.add(Delivery.fromMap(map, customer));
    }
    return deliveries;
  }

  Future<Delivery?> getById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'deliveries',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;

    Customer? customer;
    if (maps.first['customer_id'] != null) {
      customer = await _customerRepo.getById(maps.first['customer_id'] as String);
    }

    return Delivery.fromMap(maps.first, customer);
  }

  Future<void> insert(Delivery delivery) async {
    final db = await _dbHelper.database;
    await db.insert('deliveries', delivery.toMap());
  }

  Future<void> update(Delivery delivery) async {
    final db = await _dbHelper.database;
    await db.update(
      'deliveries',
      delivery.toMap(),
      where: 'id = ?',
      whereArgs: [delivery.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'deliveries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
```

**Stage A 完了報告テンプレ**
```
Stage A 完了
✅ Step 1: delivery_model.dart 作成
✅ Step 2: delivery_repository.dart 作成
```

---

## Stage B: 例1-2（deliveriesテーブル追加）
**開始宣言**：`Proceed Stage B`

### Step 3: `lib/services/database_helper.dart`
1. `static const _databaseVersion = 34;` に更新
2. `_onUpgrade` の末尾に以下を追加

```dart
    if (oldVersion < 34) {
      await db.execute('''
        CREATE TABLE deliveries (
          id TEXT PRIMARY KEY,
          document_number TEXT NOT NULL,
          date TEXT NOT NULL,
          customer_id TEXT,
          delivery_address TEXT NOT NULL,
          delivery_note TEXT,
          subtotal INTEGER NOT NULL,
          tax_amount INTEGER NOT NULL,
          total INTEGER NOT NULL,
          tax_rate REAL NOT NULL,
          notes TEXT,
          subject TEXT,
          status TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (customer_id) REFERENCES customers (id)
        )
      ''');

      await db.execute('''
        CREATE INDEX idx_deliveries_date ON deliveries(date)
      ''');

      await db.execute('''
        CREATE INDEX idx_deliveries_customer ON deliveries(customer_id)
      ''');

      await db.execute('''
        CREATE INDEX idx_deliveries_status ON deliveries(status)
      ''');
    }
```

**Stage B 完了報告**
```
Stage B 完了
✅ Step 3: DatabaseHelper バージョンアップ＆deliveriesテーブル作成
```

---

## Stage C: 例1-3（画面／メニュー／ルート）

**開始宣言**：`Proceed Stage C`

### Step 4: `lib/screens/delivery_list_screen.dart`
```dart
import 'package:flutter/material.dart';
import '../models/delivery_model.dart';
import '../services/delivery_repository.dart';
import '../widgets/generic_list_screen.dart';
import '../widgets/document_card.dart';

class DeliveryListScreen extends StatelessWidget {
  const DeliveryListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GenericListScreen<Delivery>(
      screenId: 'DL',
      screenTitle: '配送記録一覧',
      repository: DeliveryRepository(),
      itemBuilder: (delivery) => DocumentCard(
        document: delivery,
        onTap: () {
          // TODO: 詳細画面への遷移（後で実装）
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('配送記録: ${delivery.documentNumber}')),
          );
        },
      ),
      onAdd: () {
        // TODO: 新規作成画面への遷移（後で実装）
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('新規作成機能は後で実装します')),
        );
      },
    );
  }
}
```

### Step 5: `lib/constants/menu_catalog.dart`
```dart
  MenuDefinition(
    id: 'DL',
    title: '配送記録一覧',
    route: 'delivery_list',
    category: MenuCategory.sales,
    icon: Icons.local_shipping,
    description: '配送記録の一覧表示と管理',
  ),
```

### Step 6: `lib/screens/dashboard_screen.dart`
```dart
import 'delivery_list_screen.dart';
...
      case 'delivery_list':
        return const DeliveryListScreen();
```

### 確認
1. `flutter analyze`
2. アプリ起動 → 「配送記録一覧」メニュー表示、画面タイトルが `DL:配送記録一覧`

**Stage C 完了報告**
```
Stage C 完了
✅ Step 4: delivery_list_screen.dart 作成
✅ Step 5: menu_catalog 追加
✅ Step 6: dashboard_screen 追加
✅ flutter analyze: エラー0件
✅ 動作確認: メニュー表示OK
```

---

## Stage D: 例2-1（在庫モデル）

**開始宣言**：`Proceed Stage D`

### Step 1: `lib/models/inventory_model.dart`
```dart
class Inventory {
  final String id;
  final String productId;
  final String productName;
  final int quantity;
  final String warehouseId;
  final String warehouseName;
  final DateTime updatedAt;

  Inventory({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.warehouseId,
    required this.warehouseName,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'warehouse_id': warehouseId,
      'warehouse_name': warehouseName,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Inventory.fromMap(Map<String, dynamic> map) {
    return Inventory(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      productName: map['product_name'] as String,
      quantity: map['quantity'] as int,
      warehouseId: map['warehouse_id'] as String,
      warehouseName: map['warehouse_name'] as String,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
```

**Stage D 完了報告**：`Stage D 完了（Inventoryモデル作成）`

---

## Stage E: 例2-2（在庫リポジトリ）

**開始宣言**：`Proceed Stage E`

### Step 2: `lib/services/inventory_repository.dart`
```dart
import '../models/inventory_model.dart';
import 'database_helper.dart';

class InventoryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Inventory>> getAll() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        i.id,
        i.product_id,
        p.name as product_name,
        i.quantity,
        i.warehouse_id,
        w.name as warehouse_name,
        i.updated_at
      FROM inventory i
      LEFT JOIN products p ON i.product_id = p.id
      LEFT JOIN warehouses w ON i.warehouse_id = w.id
      ORDER BY p.name
    ''');

    return maps.map((map) => Inventory.fromMap(map)).toList();
  }

  Future<List<Inventory>> getByWarehouse(String warehouseId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        i.id,
        i.product_id,
        p.name as product_name,
        i.quantity,
        i.warehouse_id,
        w.name as warehouse_name,
        i.updated_at
      FROM inventory i
      LEFT JOIN products p ON i.product_id = p.id
      LEFT JOIN warehouses w ON i.warehouse_id = w.id
      WHERE i.warehouse_id = ?
      ORDER BY p.name
    ''', [warehouseId]);

    return maps.map((map) => Inventory.fromMap(map)).toList();
  }
}
```

**Stage E 完了報告**：`Stage E 完了（InventoryRepository追加）`

---

## Stage F: 例2-3（在庫画面＋確認）

**開始宣言**：`Proceed Stage F`

### Step 3: `lib/screens/inventory_list_screen.dart`
```dart
import 'package:flutter/material.dart';
import '../models/inventory_model.dart';
import '../services/inventory_repository.dart';

class InventoryListScreen extends StatefulWidget {
  const InventoryListScreen({Key? key}) : super(key: key);

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  final InventoryRepository _repository = InventoryRepository();
  List<Inventory> _inventories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInventories();
  }

  Future<void> _loadInventories() async {
    setState(() => _isLoading = true);
    try {
      final inventories = await _repository.getAll();
      if (mounted) {
        setState(() {
          _inventories = inventories;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IV:在庫一覧'),
        backgroundColor: Colors.orange,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _inventories.isEmpty
              ? const Center(child: Text('在庫データがありません'))
              : RefreshIndicator(
                  onRefresh: _loadInventories,
                  child: ListView.builder(
                    itemCount: _inventories.length,
                    itemBuilder: (context, index) {
                      final inventory = _inventories[index];
                      return ListTile(
                        leading: const Icon(Icons.inventory_2, color: Colors.orange),
                        title: Text(inventory.productName),
                        subtitle: Text('倉庫: ${inventory.warehouseName}'),
                        trailing: Text(
                          '${inventory.quantity}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: inventory.quantity > 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
```

### Step 4: `lib/constants/menu_catalog.dart`
```dart
  MenuDefinition(
    id: 'IV',
    title: '在庫一覧',
    route: 'inventory_list',
    category: MenuCategory.inventory,
    icon: Icons.inventory_2,
    description: '商品在庫の一覧表示',
  ),
```

### Step 5: `lib/screens/dashboard_screen.dart`
```dart
import 'inventory_list_screen.dart';
...
      case 'inventory_list':
        return const InventoryListScreen();
```

### 確認
1. `flutter analyze`
2. アプリ起動 → 「在庫一覧」メニュー表示、画面タイトルが `IV:在庫一覧`

**Stage F 完了報告**
```
Stage F 完了
✅ Step 3: inventory_list_screen.dart 作成
✅ Step 4: menu_catalog 追加
✅ Step 5: dashboard_screen 追加
✅ flutter analyze: エラー0件
✅ 動作確認: メニュー表示OK
```

---

## Stage G: 例3＋例4（null参照修正＆delivery_routesテーブル）

1. `lib/screens/quotation_input_screen.dart` で `customer.name ?? '名称未設定'` などのnull安全化を実施し、`customer.` で検索して類似箇所を修正。
2. `flutter analyze` ＆顧客選択動作確認。
3. `lib/services/database_helper.dart` に `delivery_routes` テーブルとindexを追加（例4のSQLを使用）。
4. `flutter analyze` ＆アプリ起動 → マイグレーション成功を確認。

**Stage G 完了報告**
```
Stage G 完了
✅ 例3: null参照修正（修正箇所X件）
✅ 例4: delivery_routesテーブル追加
✅ flutter analyze: エラー0件
✅ 動作確認: OK
```

---

## Stage H: 例5＋例6（メニュー追加＆ウィジェット）

1. `lib/constants/menu_catalog.dart` に SA メニューを追加。
2. `lib/screens/dashboard_screen.dart` に `sales_analysis` case を仮実装（Scaffold）。
3. `flutter analyze` ＆メニュー表示確認。
4. `lib/models/delivery_status.dart` に `enum DeliveryStatus` と `extension` を追加。
5. `lib/widgets/delivery_status_badge.dart` を作成し、色付きバッジを実装。
6. `flutter analyze` を実行。

**Stage H 完了報告**
```
Stage H 完了
✅ 例5: 売上分析メニュー追加
✅ 例6: DeliveryStatusBadge 作成
✅ flutter analyze: エラー0件

## Codex Stage Roadmap（I〜M）

SWE1.5での細切れ作業を完了したら、以下の大型StageをCodexクラスのモデルに渡してください。各Stageでは設計～DB～サービス～UI～テストを1ターンで仕上げる想定です。

### Stage I (Codex): 仕入モジュール完成
- 対象メニュー: `purchase_order_input` (po1), `purchase_return_input` (pr1), `purchase_receipts` (p3)
- やること
  - 発注・仕入返品・支払予定テーブル／モデル／リポジトリを追加（purchase_orders, purchase_returns, purchase_payments など）
  - 入力／一覧／詳細画面を作成し、仕入在庫・支払管理と連動
  - 既存 `purchase_entries` / `purchase_receipts` と統合し、在庫引当・支払残計算を一貫化
- 確認: `flutter analyze`, DBマイグレーション成功、ダッシュボード「仕入管理」メニューが操作可能
- 完了報告例:
  ```
  Stage I (Codex) 完了
  ✅ 発注・返品・支払モジュール実装
  ✅ DBマイグレーション: purchase_orders / returns / payments 追加
  ✅ ダッシュボード: 発注/返品/支払メニュー動作確認
  ✅ flutter analyze: エラー0件
  ```

### Stage J (Codex): 在庫オペレーション強化
- 対象メニュー: `inventory_lookup` (i1), `stock_adjustment` (i4)、既存 `stock_transfer`, `stocktake_input`
- やること
  - 在庫照会ルートを `stock_inquiry_screen.dart` と統合し、倉庫／商品フィルタ、即時検索APIを整備
  - 在庫調整ワークフロー（理由、承認、履歴テーブル）を追加
  - 棚卸・在庫移動画面の共通コンポーネント化で入力UXを統一
- 確認: `flutter analyze`, 在庫照会・調整・棚卸のE2Eテスト、倉庫別数量差分の反映
- 完了報告: 「Stage J (Codex) 完了」＋各機能のチェックリスト

### Stage K (Codex): 集計・分析アップグレード
- 対象メニュー: `sales_analysis` (SA), `customer_sales_report` (r2) 拡張, `product_margin_report` (r3), `inventory_valuation_report` (r4)
- やること
  - 売上分析画面に実データ連動チャート、フィルタ保存、エクスポートを実装
  - 粗利分析／在庫評価額レポート用の集計サービスとキャッシュ設計
  - レポート画面共通ウィジェット（期間セレクタ、グラフ、表）を整備
- 確認: `flutter analyze`, グラフ描画確認、集計結果テスト（単体＋結合）
- 完了報告: 各レポートのスクリーンショットや出力ログを添付

### Stage L (Codex): 権限・監査
- 対象メニュー: `user_permissions` (s2), `log_management` (s3)、その他管理系
- やること
  - ロール／権限テーブルとアクセス制御を導入（画面単位のRO/RW制御）
  - 操作ログ／監査ログを拡張し、検索・フィルタ・エクスポート機能を提供
  - 設定画面からユーザー／ロールの管理ができるUIを作成
- 確認: ロール別でメニュー表示が切り替わること、ログ検索が機能すること、`flutter analyze`
- 完了報告: 「Stage L (Codex) 完了」＋権限/監査テスト結果

### Stage M (Codex): 販売フロー仕上げ
- 対象: 見積→受注→売上→配送→請求までの一貫フロー
- やること
  - DocumentモデルとDBスキーマを統一し、状態遷移・在庫引当・配送連携を整理
  - PDF/メール出力、顧客通知、在庫引落、配送ステータス連動のE2E仕様を確立
  - 最終的にダッシュボードから主要販売業務が完了できることを確認
- 確認: 代表的な業務シナリオの結合テスト、`flutter analyze`、PROGRESSログ
- 完了報告: 「Stage M (Codex) 完了」＋フロー図やテスト結果

> **運用ルール**: Codex StageもSWE1.5と同様に `docs/PROGRESS.md` に完了ログを追記し、同内容をチャットへ報告してください。チャット上では「次はStage {I|J|…} (Codex) を実行してください」の形で指示を受け取ります。

## 📋 Stage完了ログ（docs/PROGRESS.md）

SWE1.5に以下を徹底させてください。

1. Stageが終わるたびに `docs/PROGRESS.md` の末尾へ追記：
   ```
   ## 2026-03-08 Stage C
   - ✅ Step 4: delivery_list_screen.dart 作成
   - ✅ Step 5: menu_catalog 追加
   - ✅ Step 6: dashboard_screen 追加
   - ✅ flutter analyze: エラー0件
   - ✅ 動作確認: メニュー表示OK
   ```
2. 同じ内容をチャットにも貼って「次のStage指示を待機します」と宣言。
3. 監督者は `docs/PROGRESS.md` を確認し、完了Stageに応じて「次はStage Xを実行してください」と一行送るだけで進行可能。

---
- カラム:
  - id: TEXT PRIMARY KEY
  - route_name: TEXT NOT NULL（ルート名）
  - start_location: TEXT（開始地点）
  - end_location: TEXT（終了地点）
  - distance: REAL（距離km）
  - estimated_time: INTEGER（推定時間分）
  - created_at: TEXT
  - updated_at: TEXT

---

## Step 1: バージョン番号更新

ファイル: `lib/services/database_helper.dart`

7行目の以下の行を見つけてください：
```dart
static const _databaseVersion = 33;
```

以下に変更してください：
```dart
static const _databaseVersion = 34;
```

完了したら「✅ Step 1完了」と報告してください。

---

## Step 2: マイグレーション追加

同じファイル `lib/services/database_helper.dart` の `_onUpgrade` メソッド内の最後に以下を追加してください：

**追加位置**: `if (oldVersion < 33)` ブロックの後

```dart
    if (oldVersion < 34) {
      await db.execute('''
        CREATE TABLE delivery_routes (
          id TEXT PRIMARY KEY,
          route_name TEXT NOT NULL,
          start_location TEXT,
          end_location TEXT,
          distance REAL,
          estimated_time INTEGER,
          created_at TEXT,
          updated_at TEXT
        )
      ''');

      await db.execute('''
        CREATE INDEX idx_delivery_routes_name 
        ON delivery_routes(route_name)
      ''');
    }
```

完了したら「✅ Step 2完了」と報告してください。

---

## 確認

1. ターミナルで実行：
```bash
cd /home/user/dev/h-1.flutter.0
flutter analyze
```

2. アプリを起動してマイグレーションが実行されることを確認
   - エラーなく起動すればOK

---

## 完了報告

```
✅ Step 1: バージョン番号更新完了（33 → 34）
✅ Step 2: マイグレーション追加完了
✅ flutter analyze: エラー0件
✅ アプリ起動確認: マイグレーション成功
```
```

---

### 例5: メニュー項目追加のみ

**このプロンプトをそのままSWE1.5にコピー＆ペーストしてください**

```markdown
タスク: 売上分析メニューの追加

## 前提条件
- プロジェクト: 販売アシスト1号（Flutter/Dart）
- プロジェクトパス: /home/user/dev/h-1.flutter.0

## 追加するメニュー
- 画面ID: SA（Sales Analysis）
- タイトル: 売上分析
- ルート名: sales_analysis
- カテゴリ: analysis
- アイコン: Icons.analytics
- 説明: 売上データの分析とグラフ表示

---

## Step 1: メニューカタログに追加

ファイル: `lib/constants/menu_catalog.dart`

`allMenus` リストの最後（最後の `MenuDefinition` の後、閉じ括弧 `]` の前）に以下を追加してください：

```dart
  MenuDefinition(
    id: 'SA',
    title: '売上分析',
    route: 'sales_analysis',
    category: MenuCategory.analysis,
    icon: Icons.analytics,
    description: '売上データの分析とグラフ表示',
  ),
```

**重要**: 最後から2番目の `MenuDefinition` の閉じ括弧 `)` の後にカンマ `,` があることを確認してください。

完了したら「✅ Step 1完了」と報告してください。

---

## Step 2: ダッシュボードにルート追加（仮実装）

ファイル: `lib/screens/dashboard_screen.dart`

`_getScreen` メソッド内のswitch文に以下のcaseを追加してください：

```dart
      case 'sales_analysis':
        return Scaffold(
          appBar: AppBar(
            title: const Text('SA:売上分析'),
            backgroundColor: Colors.purple,
          ),
          body: const Center(
            child: Text('売上分析画面（実装予定）'),
          ),
        );
```

**注意**: これは仮実装です。後で正式な画面を作成します。

完了したら「✅ Step 2完了」と報告してください。

---

## 確認

1. ターミナルで実行：
```bash
cd /home/user/dev/h-1.flutter.0
flutter analyze
```

2. アプリを起動して確認：
   - ダッシュボードに「売上分析」メニューが表示されること
   - メニューをタップして仮画面が表示されること

---

## 完了報告

```
✅ Step 1: メニューカタログ追加完了
✅ Step 2: ダッシュボードルート追加完了（仮実装）
✅ flutter analyze: エラー0件
✅ 動作確認: メニュー表示OK
```
```

---

### 例6: ウィジェット追加

**このプロンプトをそのままSWE1.5にコピー＆ペーストしてください**

```markdown
タスク: 配送ステータスバッジウィジェットの作成

## 前提条件
- プロジェクト: 販売アシスト1号（Flutter/Dart）
- プロジェクトパス: /home/user/dev/h-1.flutter.0

## ウィジェット仕様
- ウィジェット名: DeliveryStatusBadge
- 用途: 配送ステータスを色付きバッジで表示
- ステータス:
  - pending（配送前）: 灰色、「未配送」
  - inProgress（配送中）: 青色、「配送中」
  - completed（完了）: 緑色、「完了」
  - cancelled（キャンセル）: 赤色、「キャンセル」

---

## Step 1: ステータスenum作成

ファイル: `lib/models/delivery_status.dart`

以下のコードをそのまま作成してください：

```dart
enum DeliveryStatus {
  pending,
  inProgress,
  completed,
  cancelled,
}

extension DeliveryStatusExtension on DeliveryStatus {
  String get displayName {
    switch (this) {
      case DeliveryStatus.pending:
        return '未配送';
      case DeliveryStatus.inProgress:
        return '配送中';
      case DeliveryStatus.completed:
        return '完了';
      case DeliveryStatus.cancelled:
        return 'キャンセル';
    }
  }
}
```

完了したら「✅ Step 1完了」と報告してください。

---

## Step 2: バッジウィジェット作成

ファイル: `lib/widgets/delivery_status_badge.dart`

以下のコードをそのまま作成してください：

```dart
import 'package:flutter/material.dart';
import '../models/delivery_status.dart';

class DeliveryStatusBadge extends StatelessWidget {
  final DeliveryStatus status;
  final double fontSize;

  const DeliveryStatusBadge({
    Key? key,
    required this.status,
    this.fontSize = 12,
  }) : super(key: key);

  Color _getColor() {
    switch (status) {
      case DeliveryStatus.pending:
        return Colors.grey;
      case DeliveryStatus.inProgress:
        return Colors.blue;
      case DeliveryStatus.completed:
        return Colors.green;
      case DeliveryStatus.cancelled:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getColor().withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _getColor(), width: 1),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: _getColor(),
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
```

完了したら「✅ Step 2完了」と報告してください。

---

## Step 3: 使用例の確認

このウィジェットは以下のように使用できます：

```dart
// 使用例
DeliveryStatusBadge(status: DeliveryStatus.inProgress)

// フォントサイズ指定
DeliveryStatusBadge(
  status: DeliveryStatus.completed,
  fontSize: 14,
)
```

---

## 確認

```bash
cd /home/user/dev/h-1.flutter.0
flutter analyze
```

---

## 完了報告

```
✅ Step 1: ステータスenum作成完了
✅ Step 2: バッジウィジェット作成完了
✅ flutter analyze: エラー0件
```
```

---

## 💡 プロンプトの書き方のコツ

### 1. 具体的なファイルパスを指定

❌ **悪い例**: モデルを作成してください
✅ **良い例**: ファイル: lib/models/delivery_model.dart を作成してください

### 2. コード全文を提供

❌ **悪い例**: Deliveryクラスを作成してください
✅ **良い例**: 以下のコード全文で作成してください（コード全文）

### 3. ステップを分割

❌ **悪い例**: 配送記録画面を実装してください
✅ **良い例**: Step 1: モデル作成、Step 2: リポジトリ作成...

### 4. 確認方法を明示

✅ **良い例**: flutter analyze を実行してエラーがないこと

---

## 🚀 実際の使用例

### 例1: 配送記録画面を追加したい

**あなたがSWE1.5に渡すプロンプト**:

```markdown
タスク: 配送記録一覧画面の実装

docs/TASK_TEMPLATES.md のテンプレート1を使用してください。

以下の値で {} を置き換えてください:
- 画面名: 配送記録一覧
- 画面ID: DL
- エンティティ名: Delivery
- テーブル名: deliveries
- 業務固有フィールド: address（配送先住所）
- カテゴリ: sales
- アイコン: local_shipping
- ルート名: delivery_list

Step 1から順番に実装し、各Step完了後に報告してください。
全Step完了後、最終確認を行ってください。
```

**SWE1.5の動作**:
1. テンプレート1を読み込む
2. {} を指定された値に置き換え
3. Step 1から順番に実装
4. 各Step完了後に「✅ Step X完了」と報告
5. 全Step完了後、flutter analyzeを実行
6. 最終報告を出力

### 例2: null参照エラーを修正したい

**あなたがSWE1.5に渡すプロンプト**:

```markdown
タスク: 顧客名null参照エラーの修正

docs/SWE15_PROMPTS.md のテンプレート2を使用してください。

以下の値で {} を置き換えてください:
- 機能名: 顧客名表示
- ファイル名: quotation_input_screen.dart
- 行番号: 123

修正を実施し、確認後に報告してください。
```

---

## 📚 参考ドキュメントの指定方法

SWE1.5に以下のドキュメントを参照させてください：

### 必須ドキュメント

```markdown
参考ドキュメント:
- docs/CODING_GUIDE.md - 実装パターン集
- docs/TASK_TEMPLATES.md - タスクテンプレート集
```

### 状況に応じて追加

```markdown
追加参考:
- docs/02_CURRENT_STATUS.md - 既存画面ID確認用
- lib/screens/quotation_input_screen.dart - 参考実装
- ARCHITECTURE.md - システム構成理解用
```

---

## ⚠️ SWE1.5の得意・不得意まとめ

### ✅ 得意なこと

1. **パターンベースの実装**
   - 既存コードのコピー&カスタマイズ
   - テンプレートの穴埋め

2. **明確な修正**
   - 特定の行の修正
   - エラーメッセージからの修正

3. **ステップバイステップの作業**
   - 順番に実行する複数のステップ
   - チェックリスト形式の作業

### ❌ 不得意なこと

1. **設計判断**
   - 「適切なデータ構造を考えて」→ 具体的に指定すべき

2. **曖昧な指示**
   - 「いい感じに実装して」→ 具体的な仕様を指定すべき

3. **大規模な変更**
   - 「システム全体をリファクタリング」→ 小さな変更に分割すべき

---

## 🎯 SWE1.5活用の3原則

### 原則1: 具体的に指示する

- ファイル名、パス、行番号を明示
- コード全文を提供（一部だけはNG）
- 参考ドキュメント・ファイルを指定

### 原則2: ステップを分割する

- 大きなタスクを小さなステップに分解
- 各ステップは1つの明確な作業
- ステップ完了後に報告させる

### 原則3: 確認方法を明示する

- 何をどう確認するか具体的に指示
- チェックリストを提供
- 完了報告のフォーマットを指定

---

## 📝 プロンプトの基本構造

```markdown
# タスク: {タスク名}

## 前提条件
- プロジェクト情報
- プロジェクトパス
- 参考ドキュメント
- 現在のバージョン情報

## Step 1: {ステップ名}
- ファイル: {具体的なパス}
- 作業内容: {具体的な指示}
- コード: {全文}
- 完了報告: 「✅ Step 1完了」

## Step 2: {ステップ名}
（同様に記載）

## 確認事項
1. {確認項目1}
2. {確認項目2}

## 完了報告
{報告フォーマット}
```

---

## 🔧 トラブルシューティング

### SWE1.5が動かない場合

**症状**: 何も実行されない

**原因と対策**:
1. 指示が曖昧 → より具体的に
2. ファイルパスが不明確 → 絶対パスで指定
3. ステップが大きすぎる → より小さく分割

**症状**: エラーが出る

**原因と対策**:
1. コードに誤りがある → コード全文を再確認
2. ファイルが存在しない → パスを確認
3. 依存関係の問題 → 参考ドキュメントを指定

**症状**: 途中で止まる

**原因と対策**:
1. 次のステップが不明確 → 各ステップを明示
2. 確認方法がわからない → 確認項目を列挙
3. 報告方法がわからない → フォーマットを提供

---

## 📖 関連ドキュメント

- **docs/CODING_GUIDE.md** - 実装パターン詳細
- **docs/TASK_TEMPLATES.md** - タスクテンプレート詳細
- **docs/02_CURRENT_STATUS.md** - 実装状況・既存画面ID
- **ARCHITECTURE.md** - システムアーキテクチャ
- **ROADMAP.md** - 開発ロードマップ

---

## 🎉 まとめ

このプロンプト集を使えば、SWE1.5でも確実に実装できます！

**成功の鍵**:
1. テンプレートを活用
2. 具体的に指示
3. ステップを分割
4. 確認を明示

**次のステップ**:
1. docs/TASK_TEMPLATES.md からテンプレートを選ぶ
2. {} を実際の値に置き換える
3. SWE1.5にプロンプトを渡す
4. ステップバイステップで実装

Good luck! 🚀
