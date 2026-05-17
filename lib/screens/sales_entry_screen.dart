import 'package:flutter/material.dart';
import '../widgets/generic_list_screen.dart';
import '../widgets/document_card.dart';
import '../widgets/empty_state_widget.dart';
import '../models/sales_model.dart';
import '../services/sales_repository.dart';
import 'sales_input_screen.dart';

/// 売上入力画面（汎用テンプレート使用）
class SalesEntryScreen extends StatefulWidget {
  const SalesEntryScreen({super.key});

  @override
  State<SalesEntryScreen> createState() => _SalesEntryScreenState();
}

class _SalesEntryScreenState extends State<SalesEntryScreen> {
  @override
  Widget build(BuildContext context) {
    final repo = SalesRepository();

    return GenericListScreen<Sales>(
      screenId: 'SE',
      title: '売上入力',
      icon: Icons.point_of_sale,
      themeColor: Colors.green,

      // データ取得
      fetchData: () => repo.getAllSales(),

      // カード表示
      buildCard: (context, sales, onRefresh) {
        return DocumentCard(
          title: sales.getDisplayTitle(),
          subtitle: sales.getDisplaySubtitle(),
          amount: sales.getDisplayAmount(),
          date: sales.date,
          status: sales.status,
          themeColor: sales.getThemeColor(),
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SalesInputScreen(existingSalesId: sales.id)),
            );
            if (result == true && context.mounted) {
              onRefresh();
            }
          },
          actions: [
            CardAction(
              label: 'コピー',
              icon: Icons.content_copy,
              onPressed: () async {
                try {
                  await repo.copySales(sales);
                  if (!mounted) return;
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('売上をコピーしました')),
                    );
                  }
                  onRefresh();
                } catch (e) {
                  if (!mounted) return;
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('コピーに失敗しました: $e')),
                    );
                  }
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
                    content: const Text('この売上を削除しますか？'),
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
                        const SnackBar(content: Text('売上を削除しました')),
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
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SalesInputScreen()),
        );
      },

      // 空状態
      emptyWidget: EmptyStateWidget(
        icon: Icons.point_of_sale,
        title: '売上がありません',
        subtitle: 'レジモードで売上を登録してください',
        actionLabel: '新規売上作成',
        iconColor: Colors.green,
        onAction: () async {
          if (!mounted) return;
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SalesInputScreen()),
          );
          if (result == true && context.mounted) {
            // GenericListScreenの空状態アクションはVoidCallbackなので直接refreshできないが
            // 画面全体をrefreshする方法がないため、snackbarで案内
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('新規売上を保存しました')),
            );
          }
        },
      ),
    );
  }
}
