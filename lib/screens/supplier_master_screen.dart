import 'package:flutter/material.dart';
import '../models/supplier_model.dart';
import '../services/supplier_repository.dart';
import '../widgets/generic_list_screen.dart';
import '../widgets/document_card.dart';
import '../widgets/empty_state_widget.dart';

/// 仕入先一覧画面
class SupplierMasterScreen extends StatefulWidget {
  const SupplierMasterScreen({super.key});

  @override
  State<SupplierMasterScreen> createState() => _SupplierMasterScreenState();
}

class _SupplierMasterScreenState extends State<SupplierMasterScreen> {
  @override
  Widget build(BuildContext context) {
    final repo = SupplierRepository();

    return GenericListScreen<Supplier>(
      screenId: 'S1',
      title: '仕入先',
      icon: Icons.business,
      themeColor: Colors.orange,

      // データ取得
      fetchData: () => repo.getAllSuppliers(),

      // カード表示
      buildCard: (context, supplier, onRefresh) {
        return DocumentCard(
          title: supplier.displayName,
          subtitle: supplier.contactPerson ?? '',
          amount: '',
          date: supplier.updatedAt,
          status: DocumentStatus.confirmed,
          themeColor: Colors.orange,
          onTap: () {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('仕入先詳細画面は今後実装予定です')),
            );
          },
          actions: [
            CardAction(
              label: '編集',
              icon: Icons.edit,
              onPressed: () {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('仕入先編集画面は今後実装予定です')),
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
                    content: const Text('この仕入先を削除しますか？'),
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
                    await repo.deleteSupplier(supplier.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('仕入先を削除しました')),
                      );
                    }
                    onRefresh();
                  } catch (e) {
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
          filter: (suppliers) => suppliers,
        ),
        FilterOption(
          label: '非表示',
          value: 'hidden',
          filter: (suppliers) => suppliers
              .where((s) => s.isHidden)
              .toList(),
        ),
      ],

      // 新規作成
      onCreateNew: () async {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('仕入先作成画面は今後実装予定です')),
          );
        }
      },

      // 空状態
      emptyWidget: EmptyStateWidget(
        icon: Icons.business,
        title: '仕入先がありません',
        subtitle: '新しい仕入先を登録してください',
        actionLabel: '新規仕入先',
        iconColor: Colors.orange,
        onAction: () {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('仕入先作成画面は今後実装予定です')),
          );
        },
      ),
    );
  }
}
