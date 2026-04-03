# STAGE-II: 支払管理モジュール完成

**タスクID**: STAGE-II  
**優先度**: 🔴 高  
**担当**: SWE1.5  
**推定時間**: 6時間  
**作成日**: 2026-03-08

---

## 📝 タスク概要

支払管理モジュールを完成させる。支払予定管理、支払実績登録、支払消込、資金繰り表の各機能を実装し、仕入先への支払業務を完全に自動化する。

### 背景
STAGE-Iで仕入モジュールを実装完了したが、支払管理機能が未実装のため、仕入先への支払状況を把握できない。支払管理モジュールを実装することで、仕入から支払までの完全な購買管理サイクルを完成させる。

---

## ✅ 前提条件確認

- [x] Flutterプロジェクトが正常にビルドできること
- [x] 仕入モジュール（STAGE-I）が実装済みであること
- [x] 仕入先モデルと仕入モデルが理解できていること
- [ ] 支払業務の基本的なフローを理解していること

---

## 🎯 対象ファイル

### 支払モデル
1. `lib/models/payment_model.dart` - 支払モデル（新規作成）
2. `lib/models/payment_schedule_model.dart` - 支払予定モデル（新規作成）

### 支払リポジトリ
1. `lib/services/payment_repository.dart` - 支払リポジトリ（新規作成）
2. `lib/services/payment_schedule_repository.dart` - 支払予定リポジトリ（新規作成）

### 支払画面
1. `lib/screens/payment_schedule_screen.dart` - 支払予定一覧画面（新規作成）
2. `lib/screens/payment_register_screen.dart` - 支払実績登録画面（新規作成）
3. `lib/screens/cash_flow_screen.dart` - 資金繰り表画面（新規作成）

### メニュー更新
1. `lib/constants/menu_catalog.dart` - メニューカタログに支払関連を追加

---

## 📋 実行手順

### Step 1: 支払モデルの実装

**ファイル**: `lib/models/payment_model.dart`

支払実績データモデルを実装：

```dart
class Payment {
  final String id;
  final String paymentNumber;    // 支払番号
  final DateTime paymentDate;      // 支払日
  final Supplier supplier;        // 仕入先
  final int amount;              // 支払金額
  final PaymentMethod paymentMethod; // 支払方法
  final String? bankAccount;     // 振込口座
  final List<String> purchaseIds; // 対象仕入IDリスト
  final String? notes;           // 備考
  final DateTime createdAt;
  final DateTime updatedAt;

  // toMap, fromMap, copyWith メソッドを実装
}

enum PaymentMethod {
  bankTransfer,  // 銀行振込
  cash,          // 現金
  creditCard,    // クレジットカード
  other,         // その他
}
```

### Step 2: 支払予定モデルの実装

**ファイル**: `lib/models/payment_schedule_model.dart`

支払予定データモデルを実装：

```dart
class PaymentSchedule {
  final String id;
  final Purchase purchase;       // 対象仕入
  final DateTime dueDate;         // 支払期日
  final int amount;              // 支払金額
  final PaymentStatus status;     // 支払ステータス
  final DateTime? paidDate;      // 支払日
  final String? paymentId;       // 支払実績ID
  final DateTime createdAt;
  final DateTime updatedAt;

  // toMap, fromMap, copyWith メソッドを実装
}

enum PaymentStatus {
  unpaid,     // 未払
  partial,    // 部分支払
  paid,       // 支払済
  overdue,    // 延滞
}
```

### Step 3: 支払リポジトリの実装

**ファイル**: `lib/services/payment_repository.dart`

支払実績のCRUD操作を実装：

```dart
class PaymentRepository {
  Future<List<Payment>> getAllPayments() async;
  Future<void> savePayment(Payment payment) async;
  Future<void> deletePayment(String id) async;
  Future<Payment?> getPayment(String id) async;
  Future<String> generatePaymentNumber() async;
}
```

### Step 4: 支払予定リポジトリの実装

**ファイル**: `lib/services/payment_schedule_repository.dart`

支払予定の管理を実装：

```dart
class PaymentScheduleRepository {
  Future<List<PaymentSchedule>> getAllSchedules() async;
  Future<List<PaymentSchedule>> getOverdueSchedules() async;
  Future<List<PaymentSchedule>> getUpcomingSchedules({int days = 30}) async;
  Future<void> saveSchedule(PaymentSchedule schedule) async;
  Future<void> updateScheduleStatus(String id, PaymentStatus status) async;
}
```

### Step 5: 支払予定一覧画面の実装

**ファイル**: `lib/screens/payment_schedule_screen.dart`

- 画面ID: `P1:支払予定`
- GenericListScreenを使用
- 支払予定の一覧表示
- 支払期日の近い順にソート
- 延滞分のハイライト表示
- 支払実績登録画面への遷移

### Step 6: 支払実績登録画面の実装

**ファイル**: `lib/screens/payment_register_screen.dart`

- 画面ID: `P2:支払登録`
- 支払先の選択
- 支払金額の入力
- 支払方法の選択
- 対象仕入の選択（消込機能）
- 支払実績の保存

### Step 7: 資金繰り表画面の実装

**ファイル**: `lib/screens/cash_flow_screen.dart`

- 画面ID: `C1:資金繰り`
- 月次の支払予定集計
- グラフ表示（今後3ヶ月）
- 仕入先別の支払状況
- 資金繰りの予測

### Step 8: メニューの更新

**ファイル**: `lib/constants/menu_catalog.dart`

支払関連メニューを追加：

```dart
// 支払管理
MenuItem(
  id: 'payment_schedule',
  title: '支払予定',
  icon: Icons.payment,
  screenBuilder: (context) => const PaymentScheduleScreen(),
  group: MenuGroup.purchasing,
),
MenuItem(
  id: 'payment_register',
  title: '支払登録',
  icon: Icons.receipt_long,
  screenBuilder: (context) => const PaymentRegisterScreen(),
  group: MenuGroup.purchasing,
),
MenuItem(
  id: 'cash_flow',
  title: '資金繰り',
  icon: Icons.trending_up,
  screenBuilder: (context) => const CashFlowScreen(),
  group: MenuGroup.purchasing,
),
```

### Step 9: データベーススキーマの更新

**ファイル**: `lib/services/database_helper.dart`

必要なテーブルを追加：

```sql
-- 支払実績テーブル
CREATE TABLE payments (
  id TEXT PRIMARY KEY,
  payment_number TEXT NOT NULL,
  payment_date TEXT NOT NULL,
  supplier_id TEXT NOT NULL,
  amount INTEGER NOT NULL,
  payment_method TEXT NOT NULL,
  bank_account TEXT,
  notes TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
);

-- 支払・仕入紐付けテーブル
CREATE TABLE payment_purchases (
  id TEXT PRIMARY KEY,
  payment_id TEXT NOT NULL,
  purchase_id TEXT NOT NULL,
  amount INTEGER NOT NULL,
  FOREIGN KEY (payment_id) REFERENCES payments (id),
  FOREIGN KEY (purchase_id) REFERENCES purchases (id)
);

-- 支払予定テーブル
CREATE TABLE payment_schedules (
  id TEXT PRIMARY KEY,
  purchase_id TEXT NOT NULL,
  due_date TEXT NOT NULL,
  amount INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'unpaid',
  paid_date TEXT,
  payment_id TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (purchase_id) REFERENCES purchases (id),
  FOREIGN KEY (payment_id) REFERENCES payments (id)
);
```

### Step 10: ルーティングの実装

**ファイル**: `lib/screens/dashboard_screen.dart`

支払関連画面のルーティングを追加：

```dart
case 'payment_schedule':
  return const PaymentScheduleScreen();
case 'payment_register':
  return const PaymentRegisterScreen();
case 'cash_flow':
  return const CashFlowScreen();
```

---

## ✅ 完了条件

- [ ] 支払モデルと支払予定モデルの実装
- [ ] 支払リポジトリと支払予定リポジトリの実装
- [ ] 支払予定一覧画面の実装
- [ ] 支払実績登録画面の実装
- [ ] 資金繰り表画面の実装
- [ ] メニューに支払関連項目を追加
- [ ] データベーススキーマの更新
- [ ] `flutter analyze` エラー0件
- [ ] `flutter test` すべてパス
- [ ] `docs/PROGRESS.md` に完了報告を追記

---

## 🔧 トラブルシューティング

### エラー: "Foreign key constraint failed"
**原因**: 参照先のデータが存在しない  
**解決**: 仕入先や仕入データが存在するか確認

### 支払消込が正しく計算されない
**原因**: 金額計算ロジックの問題  
**解決**: 部分支払の場合の計算を適切に実装

### 資金繰り表のデータが表示されない
**原因**: 支払予定データの生成ロジックの問題  
**解決**: 仕入データから支払予定を正しく生成

### 画面IDの重複
**原因**: 既存画面とIDが重複  
**解決**: QUICK_REF.mdを確認してユニークなIDを割り当て

---

## 📚 参考資料

### 必須
- **仕入モデル**: `lib/models/purchase_model.dart`
- **仕入先モデル**: `lib/models/supplier_model.dart`
- **既存画面参考**: `lib/screens/purchase_input_screen.dart`

### 補足
- **データベースヘルパー**: `lib/services/database_helper.dart`
- **メニューカタログ**: `lib/constants/menu_catalog.dart`
- **クイックリファレンス**: `docs/QUICK_REF.md`

---

## 🔄 次のタスク

このタスク完了後、`docs/NEXT_TASK.md` を以下に更新：

**次のタスクID**: STAGE-III  
**タスク名**: 集計分析モジュール

---

このタスクを完了したら、必ず完了報告を行ってください。
