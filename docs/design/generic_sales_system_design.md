# 汎用販売管理システム 設計ドキュメント

**作成日**: 2026-03-07  
**プロジェクト**: 販売アシスト1号 (h-1.flutter.0)

---

## 📋 目次

1. [設計思想](#設計思想)
2. [汎用モジュール構成](#汎用モジュール構成)
3. [共通データモデル](#共通データモデル)
4. [汎用ウィジェット](#汎用ウィジェット)
5. [実装例](#実装例)

---

## 設計思想

### コンセプト

販売管理システムは、以下の共通パターンで構成される：

1. **リスト表示** - 伝票・商品・顧客などの一覧
2. **詳細表示** - 個別データの閲覧
3. **入力フォーム** - 新規作成・編集
4. **検索・フィルタ** - データの絞り込み
5. **アクション** - 削除・コピー・変換など

これらを**汎用的なテンプレート**として実装し、設定だけで様々な画面を生成できるようにする。

### 設計原則

1. **DRY (Don't Repeat Yourself)** - コードの重複を避ける
2. **設定駆動** - ロジックではなく設定で動作を変える
3. **型安全** - ジェネリクスを活用して型安全性を保つ
4. **拡張可能** - 新しい機能を簡単に追加できる

---

## 汎用モジュール構成

### 1. GenericListScreen<T> - 汎用リスト画面

**用途**: 見積一覧、受注一覧、売上一覧など、あらゆるリスト表示

```dart
class GenericListScreen<T> extends StatefulWidget {
  final String screenId;              // 画面ID (例: "Q1")
  final String title;                 // タイトル (例: "見積入力")
  final IconData icon;                // アイコン
  final Color? themeColor;            // テーマカラー
  
  // データ取得
  final Future<List<T>> Function() fetchData;
  
  // カード表示
  final Widget Function(BuildContext, T, VoidCallback) buildCard;
  
  // フィルタ
  final List<FilterOption<T>>? filters;
  
  // アクション
  final Future<void> Function()? onCreateNew;
  final Future<void> Function(T)? onEdit;
  final Future<void> Function(T)? onDelete;
  final Future<void> Function(T)? onCopy;
  
  // 空状態
  final Widget? emptyWidget;
  
  const GenericListScreen({
    super.key,
    required this.screenId,
    required this.title,
    required this.icon,
    required this.fetchData,
    required this.buildCard,
    this.themeColor,
    this.filters,
    this.onCreateNew,
    this.onEdit,
    this.onDelete,
    this.onCopy,
    this.emptyWidget,
  });
}
```

### 2. GenericFormScreen<T> - 汎用フォーム画面

**用途**: 見積入力、受注入力、商品登録など、あらゆるフォーム

```dart
class GenericFormScreen<T> extends StatefulWidget {
  final String screenId;
  final String title;
  final T? initialData;               // 編集時の初期データ
  
  // フォームフィールド定義
  final List<FormFieldConfig> fields;
  
  // 保存処理
  final Future<void> Function(Map<String, dynamic>) onSave;
  
  // バリデーション
  final Map<String, String? Function(dynamic)>? validators;
  
  const GenericFormScreen({
    super.key,
    required this.screenId,
    required this.title,
    required this.fields,
    required this.onSave,
    this.initialData,
    this.validators,
  });
}
```

### 3. GenericDetailScreen<T> - 汎用詳細画面

**用途**: 伝票詳細、商品詳細など、あらゆる詳細表示

```dart
class GenericDetailScreen<T> extends StatefulWidget {
  final String screenId;
  final String title;
  final T data;
  
  // セクション定義
  final List<DetailSection<T>> sections;
  
  // アクション
  final List<DetailAction<T>>? actions;
  
  const GenericDetailScreen({
    super.key,
    required this.screenId,
    required this.title,
    required this.data,
    required this.sections,
    this.actions,
  });
}
```

---

## 共通データモデル

### BaseDocument - 基本伝票モデル

すべての伝票（見積・受注・売上・請求）に共通する基底クラス

```dart
abstract class BaseDocument {
  final String id;
  final String documentNumber;      // 伝票番号
  final DateTime date;              // 伝票日付
  final Customer? customer;         // 顧客
  final List<DocumentItem> items;   // 明細
  final int subtotal;               // 小計
  final int taxAmount;              // 消費税額
  final int total;                  // 合計
  final double taxRate;             // 税率
  final String? notes;              // 備考
  final DocumentStatus status;      // ステータス
  final DateTime createdAt;         // 作成日時
  final DateTime updatedAt;         // 更新日時
  
  BaseDocument({
    required this.id,
    required this.documentNumber,
    required this.date,
    this.customer,
    required this.items,
    required this.subtotal,
    required this.taxAmount,
    required this.total,
    required this.taxRate,
    this.notes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });
  
  // 共通メソッド
  Map<String, dynamic> toMap();
  String getDisplayTitle();
  Color getStatusColor();
}

enum DocumentStatus {
  draft,      // 下書き
  confirmed,  // 確定
  cancelled,  // キャンセル
}
```

### DocumentItem - 伝票明細

```dart
class DocumentItem {
  final String id;
  final String productId;
  final String productName;
  final int quantity;
  final int unitPrice;
  final int subtotal;
  final double taxRate;
  
  DocumentItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    required this.taxRate,
  });
}
```

---

## 汎用ウィジェット

### 1. DocumentCard - 伝票カード

```dart
class DocumentCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amount;
  final DateTime date;
  final DocumentStatus status;
  final Color themeColor;
  final VoidCallback? onTap;
  final List<CardAction>? actions;
  
  const DocumentCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    required this.status,
    required this.themeColor,
    this.onTap,
    this.actions,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
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
                        Text(title, style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        )),
                        if (subtitle.isNotEmpty)
                          Text(subtitle, style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          )),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        amount,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                        ),
                      ),
                      Text(
                        DateFormat('yyyy/MM/dd').format(date),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatusChip(status),
                  const Spacer(),
                  if (actions != null)
                    ...actions!.map((action) => IconButton(
                      icon: Icon(action.icon, size: 20),
                      onPressed: action.onPressed,
                      tooltip: action.label,
                    )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatusChip(DocumentStatus status) {
    Color color;
    String label;
    
    switch (status) {
      case DocumentStatus.draft:
        color = Colors.orange;
        label = '下書き';
        break;
      case DocumentStatus.confirmed:
        color = Colors.green;
        label = '確定';
        break;
      case DocumentStatus.cancelled:
        color = Colors.grey;
        label = 'キャンセル';
        break;
    }
    
    return Chip(
      label: Text(label),
      backgroundColor: color.shade100,
      labelStyle: TextStyle(color: color, fontSize: 12),
    );
  }
}

class CardAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  
  const CardAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
}
```

### 2. EmptyStateWidget - 空状態表示

```dart
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  
  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
```

---

## 実装例

### 見積入力画面（汎用テンプレート使用）

```dart
import 'package:flutter/material.dart';
import '../widgets/generic_list_screen.dart';
import '../models/quotation_model.dart';
import '../services/quotation_repository.dart';

class QuotationInputScreen extends StatelessWidget {
  const QuotationInputScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = QuotationRepository();
    
    return GenericListScreen<Quotation>(
      screenId: 'Q1',
      title: '見積入力',
      icon: Icons.request_quote,
      themeColor: Colors.blue,
      
      // データ取得
      fetchData: () => repo.getAllQuotations(),
      
      // カード表示
      buildCard: (context, quotation, onRefresh) {
        return DocumentCard(
          title: quotation.customer?.displayName ?? '一般客',
          subtitle: quotation.subject ?? '',
          amount: '¥${NumberFormat('#,###').format(quotation.total)}',
          date: quotation.date,
          status: quotation.status,
          themeColor: Colors.blue,
          onTap: () async {
            // 詳細画面へ
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QuotationDetailScreen(quotation: quotation),
              ),
            );
            onRefresh();
          },
          actions: [
            CardAction(
              label: 'コピー',
              icon: Icons.content_copy,
              onPressed: () async {
                await repo.copyQuotation(quotation);
                onRefresh();
              },
            ),
            CardAction(
              label: '受注変換',
              icon: Icons.arrow_forward,
              onPressed: () async {
                await repo.convertToOrder(quotation);
                onRefresh();
              },
            ),
            CardAction(
              label: '削除',
              icon: Icons.delete,
              onPressed: () async {
                await repo.deleteQuotation(quotation.id);
                onRefresh();
              },
            ),
          ],
        );
      },
      
      // フィルタ
      filters: [
        FilterOption(
          label: '全て',
          value: 'all',
          filter: (quotations) => quotations,
        ),
        FilterOption(
          label: '下書き',
          value: 'draft',
          filter: (quotations) => quotations.where((q) => q.status == DocumentStatus.draft).toList(),
        ),
        FilterOption(
          label: '確定',
          value: 'confirmed',
          filter: (quotations) => quotations.where((q) => q.status == DocumentStatus.confirmed).toList(),
        ),
      ],
      
      // 新規作成
      onCreateNew: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QuotationFormScreen(),
          ),
        );
      },
      
      // 空状態
      emptyWidget: EmptyStateWidget(
        icon: Icons.request_quote,
        title: '見積がありません',
        subtitle: '新規見積を作成してください',
        actionLabel: '新規見積作成',
        onAction: () {
          // 新規作成処理
        },
      ),
    );
  }
}
```

### 受注入力画面（汎用テンプレート使用）

```dart
class OrderInputScreen extends StatelessWidget {
  const OrderInputScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = OrderRepository();
    
    return GenericListScreen<Order>(
      screenId: 'O1',
      title: '受注入力',
      icon: Icons.assignment_turned_in,
      themeColor: Colors.teal,
      
      fetchData: () => repo.getAllOrders(),
      
      buildCard: (context, order, onRefresh) {
        return DocumentCard(
          title: order.customer?.displayName ?? '一般客',
          subtitle: order.subject ?? '',
          amount: '¥${NumberFormat('#,###').format(order.total)}',
          date: order.date,
          status: order.status,
          themeColor: Colors.teal,
          onTap: () {
            // 詳細画面へ
          },
          actions: [
            CardAction(
              label: '出荷',
              icon: Icons.local_shipping,
              onPressed: () async {
                await repo.shipOrder(order);
                onRefresh();
              },
            ),
          ],
        );
      },
      
      onCreateNew: () async {
        // 新規受注作成
      },
      
      emptyWidget: EmptyStateWidget(
        icon: Icons.assignment_turned_in,
        title: '受注がありません',
        actionLabel: '新規受注作成',
      ),
    );
  }
}
```

---

## 実装ファイル構成

```
lib/
├── widgets/
│   ├── generic_list_screen.dart       # 汎用リスト画面
│   ├── generic_form_screen.dart       # 汎用フォーム画面
│   ├── generic_detail_screen.dart     # 汎用詳細画面
│   ├── document_card.dart             # 伝票カード
│   └── empty_state_widget.dart        # 空状態ウィジェット
├── models/
│   ├── base_document.dart             # 基本伝票モデル
│   ├── quotation_model.dart           # 見積モデル
│   ├── order_model.dart               # 受注モデル
│   └── sales_model.dart               # 売上モデル
├── services/
│   ├── base_repository.dart           # 基本リポジトリ
│   ├── quotation_repository.dart      # 見積リポジトリ
│   └── order_repository.dart          # 受注リポジトリ
└── screens/
    ├── quotation_input_screen.dart    # 見積入力（汎用テンプレート使用）
    ├── order_input_screen.dart        # 受注入力（汎用テンプレート使用）
    └── sales_entry_screen.dart        # 売上入力（汎用テンプレート使用）
```

---

## メリット

1. **開発速度の向上** - 新しい画面を数十行で実装可能
2. **保守性の向上** - 共通ロジックの修正が全画面に反映
3. **一貫性の確保** - UIとUXが統一される
4. **テストの容易性** - 汎用部分のテストで全画面をカバー
5. **拡張性** - 新機能の追加が容易

---

**この設計に基づいて、汎用モジュールを実装し、未実装機能を組み上げていきます。**
