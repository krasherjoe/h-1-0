import 'package:flutter/material.dart';
import '../widgets/generic_list_screen.dart';
import '../widgets/document_card.dart';
import '../widgets/empty_state_widget.dart';
import '../models/sales_model.dart';
import '../services/sales_repository.dart';
import 'sales_input_screen.dart';

/// 売上返品入力画面（汎用テンプレート使用）
class SalesReturnInputScreen extends StatefulWidget {
  const SalesReturnInputScreen({super.key});

  @override
  State<SalesReturnInputScreen> createState() => _SalesReturnInputScreenState();
}

class _SalesReturnInputScreenState extends State<SalesReturnInputScreen> {
  @override
  Widget build(BuildContext context) {
    final repo = SalesRepository();

    return GenericListScreen<Sales>(
      screenId: 'SR1',
      title: '売上返品入力',
      icon: Icons.assignment_return,
      themeColor: Theme.of(context).colorScheme.error,

      // データ取得（返品は負の金額の売上として扱う）
      fetchData: () async {
        final allSales = await repo.getAllSales();
        return allSales.where((s) => s.total < 0).toList();
      },

      // カード表示
      buildCard: (context, sales, onRefresh) {
        return DocumentCard(
          title: sales.getDisplayTitle(),
          subtitle: sales.getDisplaySubtitle(),
          amount: sales.getDisplayAmount(),
          date: sales.date,
          status: sales.status,
themeColor: Theme.of(context).colorScheme.error,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SalesInputScreen(existingSalesId: sales.id)),
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
                    await repo.deleteSales(sales.id);
                    if (!mounted) return;
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('返品を削除しました')),
                      );
                    }
                    onRefresh();
                  } catch (e) {
                    if (!mounted) return;
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('削除に失敗しました: $e')),
                      );
                    }
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
          filter: (sales) => sales,
        ),
        FilterOption(
          label: '下書き',
          value: 'draft',
          filter: (sales) => sales
              .where((s) => s.status == DocumentStatus.draft)
              .toList(),
        ),
        FilterOption(
          label: '確定',
          value: 'confirmed',
          filter: (sales) => sales
              .where((s) => s.status == DocumentStatus.confirmed)
              .toList(),
        ),
      ],

      // 新規作成
      onCreateNew: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SalesInputScreen()),
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
            MaterialPageRoute(builder: (_) => const SalesInputScreen()),
          );
        },
      ),
    );
  }
}
