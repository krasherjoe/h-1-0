/// 仕入入力画面（汎用テンプレート使用）
import 'package:flutter/material.dart';
import '../services/purchase_repository.dart';
import '../widgets/generic_list_screen.dart';
import '../widgets/document_card.dart';
import '../widgets/empty_state_widget.dart';
import '../models/base_document.dart';
import '../models/purchase_model.dart';

class PurchaseInputScreen extends StatefulWidget {
  const PurchaseInputScreen({super.key});

  @override
  State<PurchaseInputScreen> createState() => _PurchaseInputScreenState();
}

class _PurchaseInputScreenState extends State<PurchaseInputScreen> {
  @override
  Widget build(BuildContext context) {
    final repo = PurchaseRepository();

    return GenericListScreen<Purchase>(
      screenId: 'P1',
      title: '仕入',
      icon: Icons.shopping_cart,
      themeColor: Colors.orange,

      // データ取得
      fetchData: () => repo.getAllPurchases(),

      // カード表示
      buildCard: (context, purchase, onRefresh) {
        return DocumentCard(
          title: purchase.getDisplayTitle(),
          subtitle: purchase.getDisplaySubtitle(),
          amount: purchase.getDisplayAmount(),
          date: purchase.date,
          status: purchase.status,
          themeColor: purchase.getThemeColor(),
          onTap: () {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('仕入詳細画面は今後実装予定です')),
            );
          },
          actions: [
            CardAction(
              label: 'コピー',
              icon: Icons.content_copy,
              onPressed: () async {
                try {
                  await repo.copyPurchase(purchase);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('仕入をコピーしました')),
                  );
                  onRefresh();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('コピーに失敗しました: $e')),
                  );
                }
              },
            ),
            CardAction(
              label: '削除',
              icon: Icons.delete,
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('確認'),
                    content: const Text('この仕入を削除しますか？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('キャンセル'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('削除'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  try {
                    await repo.deletePurchase(purchase.id);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('仕入を削除しました')),
                    );
                    onRefresh();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('削除に失敗しました: $e')),
                    );
                  }
                }
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
          filter: (purchases) => purchases,
        ),
        FilterOption(
          label: '下書き',
          value: 'draft',
          filter: (purchases) => purchases
              .where((p) => p.status == DocumentStatus.draft)
              .toList(),
        ),
        FilterOption(
          label: '確定',
          value: 'confirmed',
          filter: (purchases) => purchases
              .where((p) => p.status == DocumentStatus.confirmed)
              .toList(),
        ),
        FilterOption(
          label: '入庫済',
          value: 'received',
          filter: (purchases) => purchases
              .where((p) => p.purchaseStatus == PurchaseStatus.received)
              .toList(),
        ),
      ],

      // 新規作成
      onCreateNew: () async {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('仕入作成画面は今後実装予定です')),
        );
      },

      // 空状態
      emptyWidget: EmptyStateWidget(
        icon: Icons.shopping_cart,
        title: '仕入がありません',
        subtitle: '新しい仕入を登録してください',
        actionLabel: '新規仕入',
        iconColor: Colors.orange,
        onAction: () {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('仕入作成画面は今後実装予定です')),
          );
        },
      ),
    );
  }
}
