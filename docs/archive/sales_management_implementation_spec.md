# 02. 販売管理 未実装機能 実装仕様書

**対象**: SWE1.5 AI エージェント  
**作成日**: 2026-03-07  
**プロジェクト**: 販売アシスト1号 (h-1.flutter.0)

---

## 📋 目次

1. [概要](#概要)
2. [未実装機能一覧](#未実装機能一覧)
3. [既存実装の理解](#既存実装の理解)
4. [Q1: 見積入力の実装仕様](#q1-見積入力の実装仕様)
5. [SR1: 売上返品入力の実装仕様](#sr1-売上返品入力の実装仕様)
6. [実装時の注意事項](#実装時の注意事項)
7. [テスト要件](#テスト要件)

---

## 概要

本ドキュメントは、販売管理カテゴリ（02. 販売管理）の未実装機能について、SWE1.5が実装するための詳細仕様を記載します。

### 現状の実装状況

| 画面ID | 機能名 | route | 実装状況 |
|--------|--------|-------|----------|
| A1 | 売上入力 | `invoice_input` | ✅ 実装済み |
| A2 | 伝票一覧 | `invoice_history` | ✅ 実装済み |
| INV1 | 請求書発行 | `invoice_issue` | ✅ 実装済み |
| O1 | 受注入力 | `order_input` | ⚠️ 部分実装（納品書として実装） |
| **Q1** | **見積入力** | `quotation_input` | ❌ **未実装** |
| **SR1** | **売上返品入力** | `sales_return_input` | ❌ **未実装** |

---

## 未実装機能一覧

### 優先度: 高

1. **Q1: 見積入力** (`quotation_input`)
   - 見積書の作成・編集・PDF生成
   - 見積履歴の管理
   - 見積から受注・売上への変換機能

2. **SR1: 売上返品入力** (`sales_return_input`)
   - 返品伝票の作成
   - 在庫の戻し処理
   - マイナス伝票の管理

---

## 既存実装の理解

### データモデル (`lib/models/invoice_models.dart`)

#### DocumentType enum
```dart
enum DocumentType {
  estimation, // 見積
  delivery,   // 納品
  invoice,    // 請求
  receipt,    // 領収
}
```

#### Invoice クラスの主要フィールド
```dart
class Invoice {
  final String id;
  final Customer customer;
  final DateTime date;
  final List<InvoiceItem> items;
  final String? notes;
  final double taxRate;
  final DocumentType documentType; // ★重要: 伝票種別
  final bool isDraft; // 下書きフラグ
  final String? subject; // 案件名
  final bool isLocked; // ロックフラグ（正式発行後）
  final String? metaJson; // メタデータJSON
  final String? metaHash; // ハッシュ値
  // ... その他のフィールド
}
```

### データベーステーブル構造

#### invoices テーブル
- `id` TEXT PRIMARY KEY
- `customer_id` TEXT
- `date` TEXT
- `notes` TEXT
- `tax_rate` REAL
- `document_type` TEXT (estimation/delivery/invoice/receipt)
- `is_draft` INTEGER (0=正式, 1=下書き)
- `subject` TEXT (案件名)
- `is_locked` INTEGER (0=編集可, 1=ロック済み)
- `meta_json` TEXT
- `meta_hash` TEXT
- その他...

#### invoice_items テーブル
- `id` TEXT PRIMARY KEY
- `invoice_id` TEXT (外部キー)
- `product_id` TEXT
- `description` TEXT
- `quantity` INTEGER
- `unit_price` INTEGER

### 既存の売上入力画面 (`lib/screens/invoice_input_screen.dart`)

**重要な特徴**:
1. `InvoiceInputForm` ウィジェットは **DocumentType を切り替え可能**
2. 見積・納品・請求・領収の全てに対応可能な汎用設計
3. 下書き保存・正式発行の2段階フロー
4. PDF生成・プレビュー機能
5. Undo/Redo機能
6. 編集ログ機能
7. GPS位置情報の記録

**コンストラクタ**:
```dart
InvoiceInputForm({
  required this.onInvoiceGenerated,
  this.existingInvoice, // 編集時の既存伝票
  this.initialDocumentType = DocumentType.invoice,
  this.startViewMode = true,
  this.showNewBadge = false,
  this.showCopyBadge = false,
})
```

### 既存のリポジトリ (`lib/services/invoice_repository.dart`)

**主要メソッド**:
- `saveInvoice(Invoice invoice)` - 伝票保存
- `getAllInvoices(List<Customer> customers)` - 全伝票取得
- `getInvoiceById(String id, List<Customer> customers)` - ID指定取得
- `deleteInvoice(String id)` - 伝票削除
- `updateInvoice(Invoice invoice)` - 伝票更新

**フィルタリング例**:
```dart
// 見積書のみ取得
final estimations = allInvoices.where((inv) => 
  inv.documentType == DocumentType.estimation
).toList();
```

---

## Q1: 見積入力の実装仕様

### ファイル作成

**新規作成ファイル**: `lib/screens/quotation_input_screen.dart`

### 実装方針

**既存の `InvoiceInputForm` を最大限活用する**ことで、コードの重複を避け、保守性を高めます。

### 画面構成

```
QuotationInputScreen (StatefulWidget)
├─ AppBar
│  └─ title: "Q1:見積入力"
│  └─ actions: [新規作成ボタン, フィルタボタン]
├─ 見積一覧 (ListView)
│  ├─ 見積カード (Card)
│  │  ├─ 顧客名
│  │  ├─ 案件名
│  │  ├─ 金額
│  │  ├─ 日付
│  │  ├─ ステータス (下書き/正式)
│  │  └─ アクションボタン (編集/コピー/削除/受注変換)
│  └─ ...
└─ FloatingActionButton (新規見積作成)
```

### 実装コード

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/invoice_models.dart';
import '../models/customer_model.dart';
import '../services/invoice_repository.dart';
import '../services/customer_repository.dart';
import 'invoice_input_screen.dart';
import 'invoice_detail_page.dart';
import 'customer_master_screen.dart';

class QuotationInputScreen extends StatefulWidget {
  const QuotationInputScreen({super.key});

  @override
  State<QuotationInputScreen> createState() => _QuotationInputScreenState();
}

class _QuotationInputScreenState extends State<QuotationInputScreen> {
  final InvoiceRepository _repo = InvoiceRepository();
  final CustomerRepository _customerRepo = CustomerRepository();
  List<Invoice> _quotations = [];
  bool _isLoading = true;
  String _filterStatus = 'all'; // all, draft, locked

  @override
  void initState() {
    super.initState();
    _loadQuotations();
  }

  Future<void> _loadQuotations() async {
    setState(() => _isLoading = true);
    final customers = await _customerRepo.getAllCustomers();
    final allInvoices = await _repo.getAllInvoices(customers);
    
    if (!mounted) return;
    
    setState(() {
      // DocumentType.estimation のみフィルタ
      _quotations = allInvoices
          .where((inv) => inv.documentType == DocumentType.estimation)
          .toList();
      
      // 日付降順でソート
      _quotations.sort((a, b) => b.date.compareTo(a.date));
      
      _isLoading = false;
    });
  }

  List<Invoice> get _filteredQuotations {
    switch (_filterStatus) {
      case 'draft':
        return _quotations.where((q) => q.isDraft).toList();
      case 'locked':
        return _quotations.where((q) => q.isLocked).toList();
      default:
        return _quotations;
    }
  }

  Future<void> _createNewQuotation() async {
    // 顧客選択
    final customer = await Navigator.push<Customer>(
      context,
      MaterialPageRoute(
        builder: (_) => const CustomerMasterScreen(selectionMode: true),
      ),
    );

    if (customer == null || !mounted) return;

    // InvoiceInputForm を見積モードで起動
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceInputForm(
          onInvoiceGenerated: (invoice, path) async {
            // 保存後の処理
            await _loadQuotations();
            if (!mounted) return;
            Navigator.pop(context);
          },
          initialDocumentType: DocumentType.estimation,
          startViewMode: false, // 編集モードで開始
          showNewBadge: true,
        ),
      ),
    );

    await _loadQuotations();
  }

  Future<void> _editQuotation(Invoice quotation) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceInputForm(
          existingInvoice: quotation,
          onInvoiceGenerated: (invoice, path) async {
            await _loadQuotations();
            if (!mounted) return;
            Navigator.pop(context);
          },
          initialDocumentType: DocumentType.estimation,
          startViewMode: true,
        ),
      ),
    );

    await _loadQuotations();
  }

  Future<void> _copyQuotation(Invoice quotation) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceInputForm(
          existingInvoice: quotation,
          onInvoiceGenerated: (invoice, path) async {
            await _loadQuotations();
            if (!mounted) return;
            Navigator.pop(context);
          },
          initialDocumentType: DocumentType.estimation,
          startViewMode: false,
          showCopyBadge: true,
        ),
      ),
    );

    await _loadQuotations();
  }

  Future<void> _deleteQuotation(Invoice quotation) async {
    if (quotation.isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ロック済み見積は削除できません')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('見積削除'),
        content: Text('見積「${quotation.subject ?? '無題'}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _repo.deleteInvoice(quotation.id);
    await _loadQuotations();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('見積を削除しました')),
    );
  }

  Future<void> _convertToOrder(Invoice quotation) async {
    // 見積を受注（納品書）に変換
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('受注変換'),
        content: const Text('この見積を受注（納品書）に変換しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('変換'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // 新しい納品書として作成（IDは新規生成される）
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceInputForm(
          existingInvoice: quotation,
          onInvoiceGenerated: (invoice, path) async {
            if (!mounted) return;
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('受注（納品書）を作成しました')),
            );
          },
          initialDocumentType: DocumentType.delivery,
          startViewMode: false,
          showNewBadge: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Q1:見積入力'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createNewQuotation,
            tooltip: '新規見積作成',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _filterStatus = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('全て')),
              const PopupMenuItem(value: 'draft', child: Text('下書きのみ')),
              const PopupMenuItem(value: 'locked', child: Text('正式発行のみ')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredQuotations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.request_quote, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        _filterStatus == 'all'
                            ? '見積がありません'
                            : 'フィルタ条件に一致する見積がありません',
                        style: const TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadQuotations,
                  child: ListView.builder(
                    itemCount: _filteredQuotations.length,
                    itemBuilder: (context, index) {
                      final quotation = _filteredQuotations[index];
                      return _buildQuotationCard(quotation);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewQuotation,
        icon: const Icon(Icons.add),
        label: const Text('新規見積'),
      ),
    );
  }

  Widget _buildQuotationCard(Invoice quotation) {
    final total = quotation.items.fold<int>(
      0,
      (sum, item) => sum + item.subtotal,
    );
    final taxAmount = (total * quotation.taxRate).round();
    final grandTotal = total + taxAmount;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _editQuotation(quotation),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quotation.customer.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (quotation.subject != null && quotation.subject!.isNotEmpty)
                          Text(
                            quotation.subject!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '¥${NumberFormat('#,###').format(grandTotal)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      Text(
                        DateFormat('yyyy/MM/dd').format(quotation.date),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Chip(
                    label: Text(quotation.isDraft ? '下書き' : '正式発行'),
                    backgroundColor: quotation.isDraft
                        ? Colors.orange.shade100
                        : Colors.green.shade100,
                    labelStyle: TextStyle(
                      color: quotation.isDraft ? Colors.orange : Colors.green,
                      fontSize: 12,
                    ),
                  ),
                  if (quotation.isLocked) ...[
                    const SizedBox(width: 8),
                    const Chip(
                      label: Text('ロック'),
                      backgroundColor: Colors.grey,
                      labelStyle: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.content_copy, size: 20),
                    onPressed: () => _copyQuotation(quotation),
                    tooltip: 'コピー',
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward, size: 20),
                    onPressed: () => _convertToOrder(quotation),
                    tooltip: '受注変換',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                    onPressed: () => _deleteQuotation(quotation),
                    tooltip: '削除',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

### ダッシュボード連携

**ファイル**: `lib/screens/dashboard_screen.dart`

**追加するインポート**:
```dart
import 'quotation_input_screen.dart';
```

**`_buildTargetScreen` メソッドに追加**:
```dart
case 'quotation_input':
  return const QuotationInputScreen();
```

---

## SR1: 売上返品入力の実装仕様

### ファイル作成

**新規作成ファイル**: `lib/screens/sales_return_input_screen.dart`

### 実装方針

返品処理は以下の2つのアプローチが考えられます:

1. **マイナス伝票方式** (推奨): 返品専用の伝票を作成し、数量をマイナスで記録
2. **元伝票修正方式**: 元の売上伝票を修正

本仕様では **マイナス伝票方式** を採用します。

### 画面構成

```
SalesReturnInputScreen (StatefulWidget)
├─ AppBar
│  └─ title: "SR1:売上返品入力"
├─ 返品元伝票選択セクション
│  ├─ 顧客選択ボタン
│  ├─ 売上伝票一覧 (選択した顧客の売上のみ)
│  └─ 選択した伝票の詳細表示
├─ 返品明細入力セクション
│  ├─ 返品商品リスト (元伝票から選択)
│  ├─ 返品数量入力
│  └─ 返品理由入力
└─ 保存ボタン
```

### データモデル拡張

返品伝票は `DocumentType` に新しい値を追加するか、`notes` フィールドに返品情報を記録します。

**オプション1**: DocumentType に `salesReturn` を追加
```dart
enum DocumentType {
  estimation,
  delivery,
  invoice,
  receipt,
  salesReturn, // 追加
}
```

**オプション2**: 既存の `invoice` タイプを使い、`notes` に返品情報を記録
- この場合、数量をマイナスにすることで返品を表現

本仕様では **オプション2** を推奨します（既存のDBスキーマを変更せずに実装可能）。

### 実装コード

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/invoice_models.dart';
import '../models/customer_model.dart';
import '../services/invoice_repository.dart';
import '../services/customer_repository.dart';
import 'customer_master_screen.dart';

class SalesReturnInputScreen extends StatefulWidget {
  const SalesReturnInputScreen({super.key});

  @override
  State<SalesReturnInputScreen> createState() => _SalesReturnInputScreenState();
}

class _SalesReturnInputScreenState extends State<SalesReturnInputScreen> {
  final InvoiceRepository _repo = InvoiceRepository();
  final CustomerRepository _customerRepo = CustomerRepository();
  
  Customer? _selectedCustomer;
  List<Invoice> _customerInvoices = [];
  Invoice? _selectedInvoice;
  final Map<String, int> _returnQuantities = {}; // itemId -> 返品数量
  final TextEditingController _reasonController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectCustomer() async {
    final customer = await Navigator.push<Customer>(
      context,
      MaterialPageRoute(
        builder: (_) => const CustomerMasterScreen(selectionMode: true),
      ),
    );

    if (customer == null) return;

    setState(() {
      _selectedCustomer = customer;
      _selectedInvoice = null;
      _returnQuantities.clear();
    });

    await _loadCustomerInvoices();
  }

  Future<void> _loadCustomerInvoices() async {
    if (_selectedCustomer == null) return;

    setState(() => _isLoading = true);

    final customers = await _customerRepo.getAllCustomers();
    final allInvoices = await _repo.getAllInvoices(customers);

    if (!mounted) return;

    setState(() {
      // 選択した顧客の売上伝票のみ（請求書・領収書）
      _customerInvoices = allInvoices
          .where((inv) =>
              inv.customer.id == _selectedCustomer!.id &&
              (inv.documentType == DocumentType.invoice ||
               inv.documentType == DocumentType.receipt) &&
              !inv.isDraft) // 正式発行済みのみ
          .toList();
      
      _customerInvoices.sort((a, b) => b.date.compareTo(a.date));
      _isLoading = false;
    });
  }

  void _selectInvoice(Invoice invoice) {
    setState(() {
      _selectedInvoice = invoice;
      _returnQuantities.clear();
      // 初期値として全商品の返品数量を0に設定
      for (final item in invoice.items) {
        _returnQuantities[item.id!] = 0;
      }
    });
  }

  void _updateReturnQuantity(String itemId, int quantity) {
    setState(() {
      _returnQuantities[itemId] = quantity;
    });
  }

  bool get _canSave {
    if (_selectedInvoice == null) return false;
    final totalReturnQty = _returnQuantities.values.fold<int>(0, (sum, qty) => sum + qty);
    return totalReturnQty > 0;
  }

  Future<void> _saveReturn() async {
    if (!_canSave) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('返品伝票作成'),
        content: const Text('返品伝票を作成しますか？\n在庫が戻され、マイナス伝票が記録されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('作成'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 返品明細を作成（数量をマイナスにする）
    final returnItems = <InvoiceItem>[];
    for (final item in _selectedInvoice!.items) {
      final returnQty = _returnQuantities[item.id] ?? 0;
      if (returnQty > 0) {
        returnItems.add(InvoiceItem(
          id: const Uuid().v4(),
          productId: item.productId,
          description: item.description,
          quantity: -returnQty, // マイナス数量
          unitPrice: item.unitPrice,
        ));
      }
    }

    // 返品伝票を作成
    final returnInvoice = Invoice(
      id: const Uuid().v4(),
      customer: _selectedInvoice!.customer,
      date: DateTime.now(),
      items: returnItems,
      notes: '返品理由: ${_reasonController.text}\n元伝票ID: ${_selectedInvoice!.id}',
      taxRate: _selectedInvoice!.taxRate,
      documentType: DocumentType.invoice, // 請求書タイプで記録
      isDraft: false, // 正式発行
      subject: '返品: ${_selectedInvoice!.subject ?? ''}',
      isLocked: false,
      terminalId: 'T1',
      updatedAt: DateTime.now(),
      isSynced: false,
    );

    await _repo.saveInvoice(returnInvoice);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('返品伝票を作成しました')),
    );

    // 画面をリセット
    setState(() {
      _selectedInvoice = null;
      _returnQuantities.clear();
      _reasonController.clear();
    });

    await _loadCustomerInvoices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('SR1:売上返品入力'),
      ),
      body: Column(
        children: [
          // 顧客選択セクション
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedCustomer == null
                        ? '顧客を選択してください'
                        : _selectedCustomer!.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _selectCustomer,
                  icon: const Icon(Icons.person),
                  label: const Text('顧客選択'),
                ),
              ],
            ),
          ),

          // 売上伝票一覧
          if (_selectedCustomer != null && _selectedInvoice == null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '返品元の売上伝票を選択',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _customerInvoices.isEmpty
                      ? const Center(
                          child: Text('正式発行済みの売上伝票がありません'),
                        )
                      : ListView.builder(
                          itemCount: _customerInvoices.length,
                          itemBuilder: (context, index) {
                            final invoice = _customerInvoices[index];
                            return _buildInvoiceCard(invoice);
                          },
                        ),
            ),
          ],

          // 返品明細入力
          if (_selectedInvoice != null) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '元伝票: ${_selectedInvoice!.subject ?? "無題"}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedInvoice = null;
                            _returnQuantities.clear();
                          });
                        },
                        child: const Text('変更'),
                      ),
                    ],
                  ),
                  Text(
                    '日付: ${DateFormat('yyyy/MM/dd').format(_selectedInvoice!.date)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _selectedInvoice!.items.length,
                itemBuilder: (context, index) {
                  final item = _selectedInvoice!.items[index];
                  return _buildReturnItemCard(item);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('返品理由', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reasonController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '返品理由を入力してください',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _canSave ? _saveReturn : null,
                      child: const Text('返品伝票を作成'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(Invoice invoice) {
    final total = invoice.items.fold<int>(0, (sum, item) => sum + item.subtotal);
    final taxAmount = (total * invoice.taxRate).round();
    final grandTotal = total + taxAmount;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(invoice.subject ?? '無題'),
        subtitle: Text(DateFormat('yyyy/MM/dd').format(invoice.date)),
        trailing: Text(
          '¥${NumberFormat('#,###').format(grandTotal)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onTap: () => _selectInvoice(invoice),
      ),
    );
  }

  Widget _buildReturnItemCard(InvoiceItem item) {
    final returnQty = _returnQuantities[item.id] ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.description,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('元数量: ${item.quantity}'),
                const Spacer(),
                Text('単価: ¥${NumberFormat('#,###').format(item.unitPrice)}'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('返品数量:'),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: returnQty > 0
                      ? () => _updateReturnQuantity(item.id!, returnQty - 1)
                      : null,
                ),
                Container(
                  width: 60,
                  alignment: Alignment.center,
                  child: Text(
                    returnQty.toString(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: returnQty < item.quantity
                      ? () => _updateReturnQuantity(item.id!, returnQty + 1)
                      : null,
                ),
                const Spacer(),
                Text(
                  '返品額: ¥${NumberFormat('#,###').format(returnQty * item.unitPrice)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

### ダッシュボード連携

**ファイル**: `lib/screens/dashboard_screen.dart`

**追加するインポート**:
```dart
import 'sales_return_input_screen.dart';
```

**`_buildTargetScreen` メソッドに追加**:
```dart
case 'sales_return_input':
  return const SalesReturnInputScreen();
```

---

## 実装時の注意事項

### 1. 画面ID命名規則の遵守

すべての画面タイトルは **2文字の画面ID** で始める必要があります:
- ✅ `Q1:見積入力`
- ✅ `SR1:売上返品入力`
- ❌ `見積入力` (NGパターン)

### 2. resizeToAvoidBottomInset の設定

すべての `Scaffold` に以下を設定してください:
```dart
Scaffold(
  resizeToAvoidBottomInset: false,
  // ...
)
```

これにより、キーボード表示時のレイアウト崩れを防ぎます。

### 3. 既存コンポーネントの再利用

- `InvoiceInputForm` は汎用的に設計されているため、最大限活用すること
- `CustomerMasterScreen` の選択モード (`selectionMode: true`) を活用
- `ProductMasterScreen` の選択モードも同様に活用可能

### 4. エラーハンドリング

- `mounted` チェックを必ず行う（非同期処理後）
- ユーザーフレンドリーなエラーメッセージを表示
- ロック済み伝票の編集・削除を防ぐ

### 5. データ整合性

- 返品処理では在庫の戻し処理を考慮（将来的な拡張）
- マイナス数量の伝票は明確に識別できるようにする
- 元伝票との関連を `notes` フィールドに記録

### 6. パフォーマンス

- 大量の伝票がある場合のページネーション（将来的な拡張）
- `RefreshIndicator` でプルリフレッシュを実装
- 不要な再描画を避ける（`const` コンストラクタの活用）

---

## テスト要件

### 単体テスト

各画面について以下をテストすること:

1. **画面の初期表示**
   - AppBar のタイトルが正しいこと
   - 空状態のメッセージが表示されること

2. **データ読み込み**
   - 正しい DocumentType でフィルタされること
   - 日付降順でソートされること

3. **CRUD操作**
   - 新規作成が正常に動作すること
   - 編集が正常に動作すること
   - 削除が正常に動作すること（ロック済みは削除不可）

### 統合テスト

1. **見積→受注変換フロー**
   - 見積を作成
   - 受注（納品書）に変換
   - 両方の伝票が存在することを確認

2. **返品処理フロー**
   - 売上伝票を作成
   - 返品伝票を作成
   - マイナス数量が正しく記録されることを確認

### 手動テスト

1. **UI/UX確認**
   - レスポンシブデザインの確認
   - タップ領域の適切なサイズ
   - エラーメッセージの表示

2. **エッジケース**
   - 顧客が0件の場合
   - 伝票が0件の場合
   - ネットワークエラー時の挙動

---

## 実装チェックリスト

### Q1: 見積入力

- [ ] `lib/screens/quotation_input_screen.dart` を作成
- [ ] `lib/screens/dashboard_screen.dart` にインポートとルート追加
- [ ] 見積一覧の表示
- [ ] 新規見積作成
- [ ] 見積編集
- [ ] 見積コピー
- [ ] 見積削除（ロックチェック）
- [ ] 受注変換機能
- [ ] フィルタ機能（全て/下書き/正式）
- [ ] プルリフレッシュ
- [ ] `flutter test` でテスト実行
- [ ] `flutter analyze` でエラー0件

### SR1: 売上返品入力

- [ ] `lib/screens/sales_return_input_screen.dart` を作成
- [ ] `lib/screens/dashboard_screen.dart` にインポートとルート追加
- [ ] 顧客選択
- [ ] 売上伝票一覧表示
- [ ] 返品明細入力
- [ ] 返品数量の増減
- [ ] 返品理由入力
- [ ] マイナス伝票の作成
- [ ] 元伝票IDの記録
- [ ] `flutter test` でテスト実行
- [ ] `flutter analyze` でエラー0件

---

## コミットメッセージ例

```
Q1:見積入力画面を実装

- QuotationInputScreenを新規作成
- 見積一覧表示、新規作成、編集、削除機能を実装
- 受注変換機能を実装
- ダッシュボード連携を追加
```

```
SR1:売上返品入力画面を実装

- SalesReturnInputScreenを新規作成
- 顧客選択、売上伝票選択機能を実装
- 返品明細入力、マイナス伝票作成機能を実装
- ダッシュボード連携を追加
```

---

## 参考資料

### 既存実装ファイル

- `lib/screens/invoice_input_screen.dart` - 売上入力画面（汎用伝票入力）
- `lib/screens/invoice_history_screen.dart` - 伝票一覧画面
- `lib/screens/order_input_screen.dart` - 受注入力画面（納品書）
- `lib/models/invoice_models.dart` - 伝票データモデル
- `lib/services/invoice_repository.dart` - 伝票リポジトリ

### データベーススキーマ

- `lib/services/database_helper.dart` - DB定義とマイグレーション

---

## 質問・不明点がある場合

実装中に不明点がある場合は、以下を確認してください:

1. 既存の類似画面の実装を参照
2. `invoice_input_screen.dart` の実装パターンを踏襲
3. データモデルの定義を確認
4. 必要に応じて人間の開発者に質問

---

**以上が販売管理機能の実装仕様書です。SWE1.5は本ドキュメントに従って実装を進めてください。**
