/// 仕入返品入力画面（汎用テンプレート使用）
import 'package:flutter/material.dart';
import '../services/purchase_repository.dart';
import '../widgets/generic_list_screen.dart';
import '../widgets/document_card.dart';
import '../widgets/empty_state_widget.dart';
import '../models/purchase_model.dart';
import 'purchase_input_screen.dart';

class PurchaseReturnInputScreen extends StatefulWidget {
  const PurchaseReturnInputScreen({super.key});

  @override
  State<PurchaseReturnInputScreen> createState() => _PurchaseReturnInputScreenState();
}

class _PurchaseReturnInputScreenState extends State<PurchaseReturnInputScreen> {
  @override
  Widget build(BuildContext context) {
    final repo = PurchaseRepository();

    return GenericListScreen<Purchase>(
      screenId: 'PR1',
      title: '仕入返品',
      icon: Icons.assignment_return,
      themeColor: Theme.of(context).colorScheme.error,

      // データ取得（返品は負の金額の仕入として扱う）
      fetchData: () async {
        final allPurchases = await repo.getAllPurchases();
        return allPurchases.where((p) => p.total < 0).toList();
      },

      // カード表示
      buildCard: (context, purchase, onRefresh) {
        return DocumentCard(
          title: purchase.getDisplayTitle(),
          subtitle: purchase.getDisplaySubtitle(),
          amount: purchase.getDisplayAmount(),
          date: purchase.date,
          status: purchase.status,
          themeColor: Theme.of(context).colorScheme.error,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PurchaseInputScreen(existingPurchaseId: purchase.id)),
            );
            if (!mounted) return;
            onRefresh();
          },
          actions: [
            CardAction(
              label: '削除',
              icon: Icons.delete,
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('確認'),
                    content: const Text('この返品を削除しますか？'),
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
                      const SnackBar(content: Text('返品を削除しました')),
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
      ],

      // 新規作成
      onCreateNew: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PurchaseInputScreen()),
        );
      },

      // 空状態
      emptyWidget: EmptyStateWidget(
        icon: Icons.assignment_return,
        title: '返品がありません',
        subtitle: '返品処理を登録してください',
        actionLabel: '新規返品',
        iconColor: Theme.of(context).colorScheme.error,
        onAction: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PurchaseInputScreen()),
          );
        },
      ),
    );
  }
}
