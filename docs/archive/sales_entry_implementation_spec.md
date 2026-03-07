# A1: 売上伝票入力 実装仕様書

**対象**: SWE1.5 AI エージェント  
**作成日**: 2026-03-07  
**プロジェクト**: 販売アシスト1号 (h-1.flutter.0)

---

## 📋 目次

1. [概要](#概要)
2. [要件定義](#要件定義)
3. [画面設計](#画面設計)
4. [データモデル](#データモデル)
5. [実装仕様](#実装仕様)
6. [実装時の注意事項](#実装時の注意事項)

---

## 概要

A1:売上伝票入力は、**レジモード向けの専用売上入力画面**です。見積・納品・請求・領収の汎用入力（InvoiceInputForm）とは**完全に別のシステム**として実装します。

### 既存システムとの違い

| 項目 | InvoiceInputForm（汎用） | A1:売上伝票入力（専用） |
|------|------------------------|---------------------|
| 用途 | 見積・納品・請求・領収の作成 | レジでの売上入力 |
| 入力方式 | フォーム入力中心 | バーコードスキャン中心 |
| 伝票タイプ | 4種類切り替え | 売上のみ |
| 顧客選択 | 必須 | 任意（一般客対応） |
| 商品検索 | マスタから選択 | バーコード即時検索 |
| 在庫連動 | なし | リアルタイム在庫確認 |
| レシート印刷 | PDF生成 | レシートプリンタ対応 |
| 決済方法 | 記録のみ | 現金・カード・電子マネー |

---

## 要件定義

### 機能要件

#### 1. 商品登録
- バーコードスキャンによる即時商品追加
- 手動での商品検索・追加
- 数量・単価の変更
- 商品削除
- 在庫数リアルタイム表示

#### 2. 顧客管理
- 一般客（顧客選択なし）での販売対応
- 顧客マスタからの選択
- 新規顧客の簡易登録

#### 3. 決済処理
- 現金決済（お預かり・お釣り計算）
- クレジットカード決済
- 電子マネー決済
- 複数決済方法の併用

#### 4. 伝票管理
- 一時保留（後で再開）
- 伝票キャンセル
- 売上確定
- レシート印刷

#### 5. その他
- 値引き・割引処理
- 税率切り替え（軽減税率対応）
- 日計・月計レポート

### 非機能要件

- レスポンス時間: バーコードスキャン後0.5秒以内に商品表示
- 操作性: タッチパネル対応（大きめのボタン）
- エラーハンドリング: 在庫不足時の警告表示
- データ整合性: 在庫数の同期

---

## 画面設計

### メイン画面レイアウト

```
┌─────────────────────────────────────────────┐
│ A1:売上伝票入力                    [保留][×]│
├─────────────────────────────────────────────┤
│ 顧客: [一般客 ▼]              伝票No: 00123 │
├─────────────────────────────────────────────┤
│ 商品一覧                                    │
│ ┌─────────────────────────────────────────┐ │
│ │ 商品A  ×2  @1,000  小計: 2,000         │ │
│ │ 商品B  ×1  @500    小計: 500           │ │
│ │                                         │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ 小計:      2,500                            │
│ 消費税(10%): 250                            │
│ 合計:      2,750                            │
├─────────────────────────────────────────────┤
│ [バーコード入力]  [商品検索]  [値引き]      │
│ [現金]  [カード]  [電子マネー]  [会計確定] │
└─────────────────────────────────────────────┘
```

### 画面遷移

```
売上伝票入力
  ├─ 商品検索ダイアログ
  ├─ 顧客選択ダイアログ
  ├─ 決済ダイアログ
  │   ├─ 現金決済（お預かり入力）
  │   ├─ カード決済
  │   └─ 電子マネー決済
  ├─ レシート印刷プレビュー
  └─ 保留伝票一覧
```

---

## データモデル

### SalesEntry（売上伝票）

```dart
class SalesEntry {
  final String id;                    // 伝票ID
  final String entryNumber;           // 伝票番号（連番）
  final DateTime entryDate;           // 売上日時
  final Customer? customer;           // 顧客（nullなら一般客）
  final List<SalesEntryItem> items;   // 商品明細
  final int subtotal;                 // 小計
  final int taxAmount;                // 消費税額
  final int total;                    // 合計
  final double taxRate;               // 税率
  final List<Payment> payments;       // 決済情報
  final String? notes;                // 備考
  final String terminalId;            // 端末ID
  final String staffId;               // 担当者ID
  final SalesEntryStatus status;      // ステータス
  final DateTime createdAt;           // 作成日時
  final DateTime? completedAt;        // 確定日時
}

enum SalesEntryStatus {
  draft,      // 入力中
  onHold,     // 保留
  completed,  // 確定
  cancelled,  // キャンセル
}
```

### SalesEntryItem（売上明細）

```dart
class SalesEntryItem {
  final String id;
  final String productId;
  final String productName;
  final String? barcode;
  final int quantity;
  final int unitPrice;
  final int subtotal;
  final double taxRate;              // 商品ごとの税率（軽減税率対応）
  final int? discountAmount;         // 値引額
}
```

### Payment（決済情報）

```dart
class Payment {
  final String id;
  final PaymentMethod method;
  final int amount;
  final String? transactionId;       // カード・電子マネーの取引ID
  final DateTime paymentDate;
}

enum PaymentMethod {
  cash,           // 現金
  creditCard,     // クレジットカード
  debitCard,      // デビットカード
  eMoney,         // 電子マネー
  qrCode,         // QRコード決済
}
```

---

## 実装仕様

### ファイル構成

```
lib/
├── screens/
│   └── sales_entry_screen.dart          # メイン画面
├── widgets/
│   ├── sales_entry_item_card.dart       # 商品明細カード
│   ├── sales_entry_payment_dialog.dart  # 決済ダイアログ
│   └── sales_entry_summary.dart         # 合計表示ウィジェット
├── models/
│   ├── sales_entry_model.dart           # 売上伝票モデル
│   └── payment_model.dart               # 決済モデル
├── services/
│   ├── sales_entry_repository.dart      # 売上伝票リポジトリ
│   └── barcode_scanner_service.dart     # バーコードスキャナサービス
└── constants/
    └── payment_methods.dart             # 決済方法定数
```

### データベーステーブル

#### sales_entries テーブル

```sql
CREATE TABLE sales_entries (
  id TEXT PRIMARY KEY,
  entry_number TEXT NOT NULL,
  entry_date TEXT NOT NULL,
  customer_id TEXT,
  subtotal INTEGER NOT NULL,
  tax_amount INTEGER NOT NULL,
  total INTEGER NOT NULL,
  tax_rate REAL NOT NULL,
  notes TEXT,
  terminal_id TEXT NOT NULL,
  staff_id TEXT,
  status TEXT NOT NULL,
  created_at TEXT NOT NULL,
  completed_at TEXT
);
```

#### sales_entry_items テーブル

```sql
CREATE TABLE sales_entry_items (
  id TEXT PRIMARY KEY,
  sales_entry_id TEXT NOT NULL,
  product_id TEXT NOT NULL,
  product_name TEXT NOT NULL,
  barcode TEXT,
  quantity INTEGER NOT NULL,
  unit_price INTEGER NOT NULL,
  subtotal INTEGER NOT NULL,
  tax_rate REAL NOT NULL,
  discount_amount INTEGER,
  FOREIGN KEY (sales_entry_id) REFERENCES sales_entries(id)
);
```

#### payments テーブル

```sql
CREATE TABLE payments (
  id TEXT PRIMARY KEY,
  sales_entry_id TEXT NOT NULL,
  method TEXT NOT NULL,
  amount INTEGER NOT NULL,
  transaction_id TEXT,
  payment_date TEXT NOT NULL,
  FOREIGN KEY (sales_entry_id) REFERENCES sales_entries(id)
);
```

### メイン画面実装

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/sales_entry_model.dart';
import '../models/customer_model.dart';
import '../models/product_model.dart';
import '../services/sales_entry_repository.dart';
import '../services/product_repository.dart';
import '../services/customer_repository.dart';
import 'customer_master_screen.dart';
import 'product_master_screen.dart';

class SalesEntryScreen extends StatefulWidget {
  const SalesEntryScreen({super.key});

  @override
  State<SalesEntryScreen> createState() => _SalesEntryScreenState();
}

class _SalesEntryScreenState extends State<SalesEntryScreen> {
  final SalesEntryRepository _repo = SalesEntryRepository();
  final ProductRepository _productRepo = ProductRepository();
  final CustomerRepository _customerRepo = CustomerRepository();
  
  Customer? _selectedCustomer;
  final List<SalesEntryItem> _items = [];
  final TextEditingController _barcodeController = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode();
  
  String _entryNumber = '';
  double _taxRate = 0.10;
  
  @override
  void initState() {
    super.initState();
    _generateEntryNumber();
    // バーコード入力欄に自動フォーカス
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barcodeFocusNode.requestFocus();
    });
  }
  
  @override
  void dispose() {
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    super.dispose();
  }
  
  Future<void> _generateEntryNumber() async {
    // 今日の日付 + 連番で伝票番号を生成
    final today = DateFormat('yyyyMMdd').format(DateTime.now());
    final count = await _repo.getTodayEntryCount();
    setState(() {
      _entryNumber = '$today-${(count + 1).toString().padLeft(4, '0')}';
    });
  }
  
  int get _subtotal => _items.fold<int>(0, (sum, item) => sum + item.subtotal);
  int get _taxAmount => (_subtotal * _taxRate).round();
  int get _total => _subtotal + _taxAmount;
  
  Future<void> _scanBarcode(String barcode) async {
    if (barcode.isEmpty) return;
    
    // バーコードから商品を検索
    final product = await _productRepo.getProductByBarcode(barcode);
    
    if (product == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('商品が見つかりません: $barcode')),
      );
      _barcodeController.clear();
      return;
    }
    
    // 在庫チェック
    if (product.stockQuantity <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name}は在庫がありません'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    
    // 既に同じ商品があれば数量を増やす
    final existingIndex = _items.indexWhere((item) => item.productId == product.id);
    
    setState(() {
      if (existingIndex >= 0) {
        final existing = _items[existingIndex];
        _items[existingIndex] = SalesEntryItem(
          id: existing.id,
          productId: existing.productId,
          productName: existing.productName,
          barcode: existing.barcode,
          quantity: existing.quantity + 1,
          unitPrice: existing.unitPrice,
          subtotal: existing.unitPrice * (existing.quantity + 1),
          taxRate: existing.taxRate,
        );
      } else {
        _items.add(SalesEntryItem(
          id: const Uuid().v4(),
          productId: product.id,
          productName: product.name,
          barcode: product.barcode,
          quantity: 1,
          unitPrice: product.price,
          subtotal: product.price,
          taxRate: _taxRate,
        ));
      }
    });
    
    _barcodeController.clear();
    _barcodeFocusNode.requestFocus();
  }
  
  Future<void> _selectCustomer() async {
    final customer = await Navigator.push<Customer>(
      context,
      MaterialPageRoute(
        builder: (_) => const CustomerMasterScreen(selectionMode: true),
      ),
    );
    
    if (customer != null) {
      setState(() {
        _selectedCustomer = customer;
      });
    }
  }
  
  Future<void> _selectProduct() async {
    final product = await Navigator.push<Product>(
      context,
      MaterialPageRoute(
        builder: (_) => const ProductMasterScreen(selectionMode: true),
      ),
    );
    
    if (product != null) {
      await _scanBarcode(product.barcode ?? product.id);
    }
  }
  
  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }
  
  void _updateQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      _removeItem(index);
      return;
    }
    
    setState(() {
      final item = _items[index];
      _items[index] = SalesEntryItem(
        id: item.id,
        productId: item.productId,
        productName: item.productName,
        barcode: item.barcode,
        quantity: newQuantity,
        unitPrice: item.unitPrice,
        subtotal: item.unitPrice * newQuantity,
        taxRate: item.taxRate,
      );
    });
  }
  
  Future<void> _processPayment() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('商品が登録されていません')),
      );
      return;
    }
    
    // 決済ダイアログを表示
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _PaymentDialog(total: _total),
    );
    
    if (result == null) return;
    
    // 売上伝票を保存
    final entry = SalesEntry(
      id: const Uuid().v4(),
      entryNumber: _entryNumber,
      entryDate: DateTime.now(),
      customer: _selectedCustomer,
      items: _items,
      subtotal: _subtotal,
      taxAmount: _taxAmount,
      total: _total,
      taxRate: _taxRate,
      payments: result['payments'] as List<Payment>,
      terminalId: 'T1',
      status: SalesEntryStatus.completed,
      createdAt: DateTime.now(),
      completedAt: DateTime.now(),
    );
    
    await _repo.saveSalesEntry(entry);
    
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('売上を確定しました')),
    );
    
    // 画面をリセット
    setState(() {
      _selectedCustomer = null;
      _items.clear();
    });
    await _generateEntryNumber();
    _barcodeFocusNode.requestFocus();
  }
  
  void _clearAll() {
    setState(() {
      _selectedCustomer = null;
      _items.clear();
    });
    _barcodeFocusNode.requestFocus();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('A1:売上伝票入力'),
        actions: [
          IconButton(
            icon: const Icon(Icons.pause),
            onPressed: () {
              // TODO: 保留機能
            },
            tooltip: '保留',
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _clearAll,
            tooltip: 'クリア',
          ),
        ],
      ),
      body: Column(
        children: [
          // ヘッダー情報
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectCustomer,
                    child: Row(
                      children: [
                        const Icon(Icons.person),
                        const SizedBox(width: 8),
                        Text(
                          _selectedCustomer?.displayName ?? '一般客',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
                Text(
                  '伝票No: $_entryNumber',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
          
          // バーコード入力
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _barcodeController,
              focusNode: _barcodeFocusNode,
              decoration: InputDecoration(
                labelText: 'バーコード',
                hintText: 'バーコードをスキャンまたは入力',
                prefixIcon: const Icon(Icons.qr_code_scanner),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _selectProduct,
                ),
              ),
              onSubmitted: _scanBarcode,
            ),
          ),
          
          // 商品一覧
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Text(
                      'バーコードをスキャンして商品を追加',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          title: Text(item.productName),
                          subtitle: Text(
                            '¥${NumberFormat('#,###').format(item.unitPrice)}',
                          ),
                          trailing: SizedBox(
                            width: 150,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove),
                                  onPressed: () => _updateQuantity(
                                    index,
                                    item.quantity - 1,
                                  ),
                                ),
                                Text(
                                  '${item.quantity}',
                                  style: const TextStyle(fontSize: 18),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: () => _updateQuantity(
                                    index,
                                    item.quantity + 1,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _removeItem(index),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          // 合計表示
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('小計'),
                    Text(
                      '¥${NumberFormat('#,###').format(_subtotal)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('消費税(${(_taxRate * 100).toInt()}%)'),
                    Text(
                      '¥${NumberFormat('#,###').format(_taxAmount)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '合計',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '¥${NumberFormat('#,###').format(_total)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // 決済ボタン
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _items.isEmpty ? null : _processPayment,
                    icon: const Icon(Icons.payment),
                    label: const Text('会計確定'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(20),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 決済ダイアログ（簡易版）
class _PaymentDialog extends StatefulWidget {
  final int total;
  
  const _PaymentDialog({required this.total});
  
  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final TextEditingController _receivedController = TextEditingController();
  
  @override
  void dispose() {
    _receivedController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final received = int.tryParse(_receivedController.text) ?? 0;
    final change = received - widget.total;
    
    return AlertDialog(
      title: const Text('決済'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '合計: ¥${NumberFormat('#,###').format(widget.total)}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _receivedController,
            decoration: const InputDecoration(
              labelText: 'お預かり',
              prefixText: '¥',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          if (change >= 0)
            Text(
              'お釣り: ¥${NumberFormat('#,###').format(change)}',
              style: const TextStyle(fontSize: 18, color: Colors.green),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: change >= 0
              ? () {
                  final payment = Payment(
                    id: const Uuid().v4(),
                    method: PaymentMethod.cash,
                    amount: widget.total,
                    paymentDate: DateTime.now(),
                  );
                  Navigator.pop(context, {'payments': [payment]});
                }
              : null,
          child: const Text('確定'),
        ),
      ],
    );
  }
}
```

---

## 実装時の注意事項

### 1. 画面ID命名規則

- AppBarタイトルは `A1:売上伝票入力` とする

### 2. バーコードスキャナ対応

- 実機でのバーコードスキャナテストが必要
- キーボード入力とスキャナ入力の両方に対応

### 3. 在庫管理との連携

- 商品追加時に在庫数をチェック
- 売上確定時に在庫を減らす処理を実装

### 4. 決済処理

- 現金決済は必須実装
- カード・電子マネーは将来拡張として設計

### 5. レシート印刷

- 初期実装ではPDF生成で代用可
- 将来的にサーマルプリンタ対応を想定

### 6. パフォーマンス

- バーコードスキャン後0.5秒以内に商品表示
- 大量商品登録時のスクロール性能

---

## データベースマイグレーション

`database_helper.dart` に以下を追加:

```dart
if (oldVersion < 32) {
  await db.execute('''
    CREATE TABLE sales_entries (
      id TEXT PRIMARY KEY,
      entry_number TEXT NOT NULL,
      entry_date TEXT NOT NULL,
      customer_id TEXT,
      subtotal INTEGER NOT NULL,
      tax_amount INTEGER NOT NULL,
      total INTEGER NOT NULL,
      tax_rate REAL NOT NULL,
      notes TEXT,
      terminal_id TEXT NOT NULL,
      staff_id TEXT,
      status TEXT NOT NULL,
      created_at TEXT NOT NULL,
      completed_at TEXT
    )
  ''');
  
  await db.execute('''
    CREATE TABLE sales_entry_items (
      id TEXT PRIMARY KEY,
      sales_entry_id TEXT NOT NULL,
      product_id TEXT NOT NULL,
      product_name TEXT NOT NULL,
      barcode TEXT,
      quantity INTEGER NOT NULL,
      unit_price INTEGER NOT NULL,
      subtotal INTEGER NOT NULL,
      tax_rate REAL NOT NULL,
      discount_amount INTEGER,
      FOREIGN KEY (sales_entry_id) REFERENCES sales_entries(id)
    )
  ''');
  
  await db.execute('''
    CREATE TABLE payments (
      id TEXT PRIMARY KEY,
      sales_entry_id TEXT NOT NULL,
      method TEXT NOT NULL,
      amount INTEGER NOT NULL,
      transaction_id TEXT,
      payment_date TEXT NOT NULL,
      FOREIGN KEY (sales_entry_id) REFERENCES sales_entries(id)
    )
  ''');
}
```

---

**以上がA1:売上伝票入力の実装仕様書です。SWE1.5は本ドキュメントに従って実装を進めてください。**
