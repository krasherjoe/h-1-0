# STAGE-I: 仕入モジュール完成

**タスクID**: STAGE-I  
**優先度**: 🔴 高  
**担当**: SWE1.5  
**推定時間**: 8時間  
**作成日**: 2026-03-08

---

## 📝 タスク概要

仕入モジュールを完成させる。仕入先管理、仕入入力、仕入返品、在庫管理の各画面と機能を実装し、仕入業務の完全なフローを構築する。

### 背景
現在のプロジェクトでは見積・受注・売上モジュールが実装済みだが、仕入モジュールが未実装のため、商品の仕入から在庫管理までの連携ができない。仕入モジュールを実装することで、完全な購買管理システムを完成させる。

---

## ✅ 前提条件確認

- [x] Flutterプロジェクトが正常にビルドできること
- [x] 既存のモジュール（顧客、見積、売上）が実装済みであること
- [x] データベーススキーマが理解できていること
- [ ] 仕入業務の基本的なフローを理解していること

---

## 🎯 対象ファイル

### 仕入先管理
1. `lib/models/supplier_model.dart` - 仕入先モデル（新規作成）
2. `lib/services/supplier_repository.dart` - 仕入先リポジトリ（新規作成）
3. `lib/screens/supplier_master_screen.dart` - 仕入先一覧画面（新規作成）

### 仕入入力
1. `lib/models/purchase_model.dart` - 仕入モデル（新規作成）
2. `lib/services/purchase_repository.dart` - 仕入リポジトリ（新規作成）
3. `lib/screens/purchase_input_screen.dart` - 仕入入力画面（新規作成）

### 仕入返品
1. `lib/screens/purchase_return_input_screen.dart` - 仕入返品画面（新規作成）

### 在庫管理
1. `lib/models/inventory_model.dart` - 在庫モデル（新規作成）
2. `lib/services/inventory_repository.dart` - 在庫リポジトリ（新規作成）
3. `lib/screens/inventory_management_screen.dart` - 在庫管理画面（新規作成）

### メニュー更新
1. `lib/constants/menu_catalog.dart` - メニューカタログに仕入関連を追加

---

## 📋 実行手順

### Step 1: 仕入先モデルの実装

**ファイル**: `lib/models/supplier_model.dart`

顧客モデルを参考に、仕入先モデルを実装：

```dart
class Supplier {
  final String id;
  final String displayName;  // 表示名
  final String formalName;   // 正式名称
  final String title;        // 敬称
  final String? department;  // 部署
  final String? address;     // 住所
  final String? tel;         // 電話番号
  final String? email;       // メール
  final String? contactPerson; // 担当者
  final String? paymentTerms; // 支払条件
  final String? bankAccount;  // 銀行口座
  final bool isLocked;
  final bool isHidden;
  final DateTime updatedAt;
  final String? headChar1;
  final String? headChar2;

  Supplier({
    required this.id,
    required this.displayName,
    required this.formalName,
    this.title = "様",
    this.department,
    this.address,
    this.tel,
    this.email,
    this.contactPerson,
    this.paymentTerms,
    this.bankAccount,
    this.isLocked = false,
    this.isHidden = false,
    DateTime? updatedAt,
    this.headChar1,
    this.headChar2,
  }) : updatedAt = updatedAt ?? DateTime.now();

  // toMap, fromMap, copyWith メソッドを実装
  // invoiceName ゲッターを実装
}
```

### Step 2: 仕入先リポジトリの実装

**ファイル**: `lib/services/supplier_repository.dart`

顧客リポジトリを参考に実装：

```dart
class SupplierRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<Supplier>> getAllSuppliers() async {
    // 全仕入先を取得
  }

  Future<void> saveSupplier(Supplier supplier) async {
    // 仕入先を保存
  }

  Future<void> deleteSupplier(String id) async {
    // 仕入先を削除
  }

  Future<Supplier?> getSupplier(String id) async {
    // 特定仕入先を取得
  }
}
```

### Step 3: 仕入先一覧画面の実装

**ファイル**: `lib/screens/supplier_master_screen.dart`

顧客一覧画面を参考に実装：

- 画面ID: `S1:仕入先`
- GenericListScreenを使用
- 検索機能
- 新規作成・編集・削除機能
- 連携先インポート機能

### Step 4: 仕入モデルの実装

**ファイル**: `lib/models/purchase_model.dart`

見積モデルを参考に実装：

```dart
class Purchase extends BaseDocument {
  // 仕入先
  final Supplier? supplier;
  
  // 納期
  final DateTime? dueDate;
  
  // 支払状況
  final PaymentStatus paymentStatus;
  
  // その他仕入固有のフィールド
}

enum PurchaseStatus {
  draft,      // 下書き
  confirmed,  // 確定
  received,   // 入庫済
  cancelled,  // キャンセル
}

enum PaymentStatus {
  unpaid,     // 未払
  partial,    // 部分支払
  paid,       // 支払済
}
```

### Step 5: 仕入リポジトリの実装

**ファイル**: `lib/services/purchase_repository.dart`

見積リポジトリを参考に実装：

```dart
class PurchaseRepository {
  Future<List<Purchase>> getAllPurchases() async;
  Future<void> savePurchase(Purchase purchase) async;
  Future<void> deletePurchase(String id) async;
  Future<void> copyPurchase(Purchase purchase) async;
}
```

### Step 6: 仕入入力画面の実装

**ファイル**: `lib/screens/purchase_input_screen.dart`

- 画面ID: `P1:仕入`
- GenericListScreenを使用
- 仕入先選択機能
- 商品明細入力
- 自動計算（小計、消費税、合計）
- 保存・コピー・削除機能

### Step 7: 仕入返品画面の実装

**ファイル**: `lib/screens/purchase_return_input_screen.dart`

- 画面ID: `PR1:仕入返品`
- 仕入入力画面をベースに実装
- 負の金額で仕入データを管理
- 在庫減算処理

### Step 8: 在庫モデルの実装

**ファイル**: `lib/models/inventory_model.dart`

```dart
class Inventory {
  final String id;
  final String productId;      // 商品ID
  final String productName;    // 商品名
  final int quantity;         // 現在在庫数
  final int reservedQuantity; // 引当数
  final int availableQuantity; // 利用可能在庫
  final String? location;     // 保管場所
  final DateTime updatedAt;
  
  int get totalQuantity => quantity + reservedQuantity;
}
```

### Step 9: 在庫リポジトリの実装

**ファイル**: `lib/services/inventory_repository.dart`

```dart
class InventoryRepository {
  Future<List<Inventory>> getAllInventory() async;
  Future<Inventory?> getInventory(String productId) async;
  Future<void> updateInventory(String productId, int quantity) async;
  Future<void> adjustInventory(String productId, int adjustment) async;
}
```

### Step 10: 在庫管理画面の実装

**ファイル**: `lib/screens/inventory_management_screen.dart`

- 画面ID: `I1:在庫`
- 在庫一覧表示
- 在庫調整機能
- 入出庫履歴表示
- 不足アラート表示

### Step 11: データベーススキーマの更新

**ファイル**: `lib/services/database_helper.dart`

必要なテーブルを追加：

```sql
-- 仕入先テーブル
CREATE TABLE suppliers (
  id TEXT PRIMARY KEY,
  display_name TEXT NOT NULL,
  formal_name TEXT NOT NULL,
  title TEXT DEFAULT '様',
  department TEXT,
  address TEXT,
  tel TEXT,
  email TEXT,
  contact_person TEXT,
  payment_terms TEXT,
  bank_account TEXT,
  is_locked INTEGER DEFAULT 0,
  is_hidden INTEGER DEFAULT 0,
  updated_at TEXT NOT NULL
);

-- 仕入テーブル
CREATE TABLE purchases (
  id TEXT PRIMARY KEY,
  document_number TEXT NOT NULL,
  date TEXT NOT NULL,
  supplier_id TEXT,
  due_date TEXT,
  subtotal INTEGER NOT NULL DEFAULT 0,
  tax_amount INTEGER NOT NULL DEFAULT 0,
  total INTEGER NOT NULL DEFAULT 0,
  tax_rate REAL NOT NULL DEFAULT 0.1,
  status TEXT NOT NULL DEFAULT 'draft',
  payment_status TEXT NOT NULL DEFAULT 'unpaid',
  notes TEXT,
  subject TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
);

-- 仕入明細テーブル
CREATE TABLE purchase_items (
  id TEXT PRIMARY KEY,
  purchase_id TEXT NOT NULL,
  product_id TEXT,
  product_name TEXT,
  quantity REAL NOT NULL DEFAULT 1,
  unit_price REAL NOT NULL DEFAULT 0,
  tax_rate REAL NOT NULL DEFAULT 0.1,
  FOREIGN KEY (purchase_id) REFERENCES purchases (id)
);

-- 在庫テーブル
CREATE TABLE inventory (
  id TEXT PRIMARY KEY,
  product_id TEXT NOT NULL UNIQUE,
  product_name TEXT NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 0,
  reserved_quantity INTEGER NOT NULL DEFAULT 0,
  location TEXT,
  updated_at TEXT NOT NULL
);
```

### Step 12: メニューの更新

**ファイル**: `lib/constants/menu_catalog.dart`

仕入関連メニューを追加：

```dart
// 仕入管理
MenuItem(
  id: 'suppliers',
  title: '仕入先',
  icon: Icons.business,
  screenBuilder: (context) => const SupplierMasterScreen(),
  group: MenuGroup.purchasing,
),
MenuItem(
  id: 'purchases',
  title: '仕入',
  icon: Icons.shopping_cart,
  screenBuilder: (context) => const PurchaseInputScreen(),
  group: MenuGroup.purchasing,
),
MenuItem(
  id: 'purchase_returns',
  title: '仕入返品',
  icon: Icons.assignment_return,
  screenBuilder: (context) => const PurchaseReturnInputScreen(),
  group: MenuGroup.purchasing,
),
MenuItem(
  id: 'inventory',
  title: '在庫管理',
  icon: Icons.inventory,
  screenBuilder: (context) => const InventoryManagementScreen(),
  group: MenuGroup.purchasing,
),
```

---

## ✅ 完了条件

- [ ] 仕入先モデル・リポジトリ・画面の実装
- [ ] 仕入モデル・リポジトリ・画面の実装
- [ ] 仕入返品画面の実装
- [ ] 在庫モデル・リポジトリ・画面の実装
- [ ] メニューに仕入関連項目を追加
- [ ] データベーススキーマの更新
- [ ] `flutter analyze` エラー0件
- [ ] `flutter test` すべてパス
- [ ] `docs/PROGRESS.md` に完了報告を追記

---

## 🔧 トラブルシューティング

### エラー: "Table doesn't exist"
**原因**: データベーススキーマが更新されていない  
**解決**: DatabaseHelperのonCreate/onUpgradeでテーブルを作成

### エラー: "Foreign key constraint failed"
**原因**: リレーションシップの問題  
**解決**: 参照先のデータが存在するか確認

### 在庫数がマイナスになる
**原因**: 在庫調整ロジックの問題  
**解決**: 仕入入力時に在庫を増加、返品時に減少する処理を追加

### 画面IDの重複
**原因**: 既存画面とIDが重複  
**解決**: QUICK_REF.mdを確認してユニークなIDを割り当て

---

## 📚 参考資料

### 必須
- **顧客モデル**: `lib/models/customer_model.dart`
- **見積モデル**: `lib/models/quotation_model.dart`
- **顧客一覧画面**: `lib/screens/customer_master_screen.dart`
- **見積入力画面**: `lib/screens/quotation_input_screen.dart`

### 補足
- **データベースヘルパー**: `lib/services/database_helper.dart`
- **メニューカタログ**: `lib/constants/menu_catalog.dart`
- **クイックリファレンス**: `docs/QUICK_REF.md`

---

## 🔄 次のタスク

このタスク完了後、`docs/NEXT_TASK.md` を以下に更新：

**次のタスクID**: STAGE-II  
**タスク名**: 支払管理モジュール

---

このタスクを完了したら、必ず完了報告を行ってください。
