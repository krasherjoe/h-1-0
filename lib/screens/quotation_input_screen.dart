import 'package:flutter/material.dart';
import '../widgets/generic_list_screen.dart';
import '../widgets/document_card.dart';
import '../widgets/empty_state_widget.dart';
import '../models/quotation_model.dart';
import '../services/quotation_repository.dart';

/// 見積入力画面（汎用テンプレート使用）
class QuotationInputScreen extends StatefulWidget {
  const QuotationInputScreen({super.key});

  @override
  State<QuotationInputScreen> createState() => _QuotationInputScreenState();
}

class _QuotationInputScreenState extends State<QuotationInputScreen> {
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
          title: quotation.getDisplayTitle(),
          subtitle: quotation.getDisplaySubtitle(),
          amount: quotation.getDisplayAmount(),
          date: quotation.date,
          status: quotation.status,
          themeColor: quotation.getThemeColor(),
          onTap: () {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('見積詳細画面は今後実装予定です')),
            );
          },
          actions: [
            CardAction(
              label: 'コピー',
              icon: Icons.content_copy,
              onPressed: () async {
                try {
                  await repo.copyQuotation(quotation);
                  if (!mounted) return;
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('見積をコピーしました')),
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
              label: '受注変換',
              icon: Icons.arrow_forward,
              onPressed: () {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('受注変換機能は今後実装予定です')),
                );
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
                    content: const Text('この見積を削除しますか？'),
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
                    await repo.deleteQuotation(quotation.id);
                    if (!mounted) return;
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('見積を削除しました')),
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
          filter: (quotations) => quotations,
        ),
        FilterOption(
          label: '下書き',
          value: 'draft',
          filter: (quotations) => quotations
              .where((q) => q.status == DocumentStatus.draft)
              .toList(),
        ),
        FilterOption(
          label: '確定',
          value: 'confirmed',
          filter: (quotations) => quotations
              .where((q) => q.status == DocumentStatus.confirmed)
              .toList(),
        ),
      ],

      // 新規作成
      onCreateNew: () async {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('見積作成画面は今後実装予定です')),
        );
      },

      // 空状態
      emptyWidget: EmptyStateWidget(
        icon: Icons.request_quote,
        title: '見積がありません',
        subtitle: '新規見積を作成してください',
        actionLabel: '新規見積作成',
        iconColor: Colors.blue,
        onAction: () {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('見積作成画面は今後実装予定です')),
          );
        },
      ),
    );
  }
}
