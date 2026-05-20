import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/generic_list_screen.dart';
import '../widgets/document_card.dart';
import '../widgets/empty_state_widget.dart';
import '../models/sales_model.dart';
import '../services/sales_repository.dart';
import '../services/invoice_repository.dart';
import '../services/pdf_generator.dart';
import 'sales_input_screen.dart';

/// 売上入力画面（汎用テンプレート使用）
class SalesEntryScreen extends StatefulWidget {
  const SalesEntryScreen({super.key});

  @override
  State<SalesEntryScreen> createState() => _SalesEntryScreenState();
}

class _SalesEntryScreenState extends State<SalesEntryScreen> {
  final _salesRepo = SalesRepository();
  final _invoiceRepo = InvoiceRepository();

  Future<void> _showInvoiceImportDialog() async {
    if (!mounted) return;
    
    final unusedInvoices = await _invoiceRepo.getUnusedInvoices();
    
    if (!mounted) return;
    
    if (unusedInvoices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('売上に转换できる請求書はありません')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Text(
                '請求書から売上を生成',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: unusedInvoices.length,
                itemBuilder: (context, index) {
                  final invoice = unusedInvoices[index];
                  return ListTile(
                    title: Text(invoice.customer.displayName),
                    subtitle: Text(
                      '${invoice.documentTypeName} ${invoice.invoiceNumber}\n¥${invoice.totalAmount.toString().replaceAllMapped(
                        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                        (Match m) => '${m[1]},',
                      )}',
                    ),
                    trailing: Text(
                      DateFormat('yyyy/MM/dd').format(invoice.date),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      await _convertInvoiceToSales(invoice.id);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _convertInvoiceToSales(String invoiceId) async {
    try {
      await _invoiceRepo.convertInvoiceToSales(invoiceId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請求書が売上に转换されました')),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('转换に失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GenericListScreen<Sales>(
        screenId: 'SE',
        title: '売上入力',
        icon: Icons.point_of_sale,
        themeColor: Theme.of(context).colorScheme.secondary,

        // データ取得
        fetchData: () => _salesRepo.getAllSalesWithItems(),

        // カード表示
        buildCard: (context, sales, onRefresh) {
          final grossProfitText = sales.grossProfit != null
              ? '粗利: ¥${sales.grossProfit!.toString().replaceAllMapped(
                  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                  (Match m) => '${m[1]},',
                )}'
              : null;

          return DocumentCard(
            title: sales.getDisplayTitle(),
            subtitle: sales.getDisplaySubtitle(),
            amount: sales.getDisplayAmount(),
            date: sales.date,
            status: sales.status,
            themeColor: sales.getThemeColor(),
            grossProfit: grossProfitText,
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
                label: 'PDF出力',
                icon: Icons.picture_as_pdf,
            onPressed: () async {
                   if (!mounted) return;
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('PDF出力機能は今後実装予定です')),
                   );
                 },
              ),
              CardAction(
                label: 'コピー',
                icon: Icons.content_copy,
                onPressed: () async {
                  try {
                    await _salesRepo.copySales(sales);
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
                      await _salesRepo.deleteSales(sales.id);
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
          iconColor: Theme.of(context).colorScheme.secondary,
          onAction: () async {
            if (!mounted) return;
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SalesInputScreen()),
            );
            if (result == true && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('新規売上を保存しました')),
              );
            }
          },
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: _showInvoiceImportDialog,
            icon: const Icon(Icons.import_export),
            label: const Text('請求書から取込'),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            onPressed: () async {
              if (!mounted) return;
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SalesInputScreen()),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('新規売上'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}
