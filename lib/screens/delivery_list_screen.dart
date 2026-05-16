import 'package:flutter/material.dart';
import '../models/delivery_model.dart';
import '../services/delivery_repository.dart';
import '../widgets/generic_list_screen.dart';
import '../widgets/document_card.dart';

class DeliveryListScreen extends StatelessWidget {
  const DeliveryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GenericListScreen<Delivery>(
      screenId: 'DL1',
      title: '配送記録一覧',
      icon: Icons.local_shipping,
      themeColor: Colors.green,
      fetchData: () async {
        final repo = DeliveryRepository();
        return await repo.getAll();
      },
      buildCard: (context, delivery, onRefresh) => DocumentCard(
        title: delivery.customer?.displayName ?? '一般客',
        subtitle: delivery.deliveryAddress,
        amount: '¥${delivery.total.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}',
        date: delivery.date,
        status: delivery.status,
        themeColor: delivery.getThemeColor(),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('配送記録: ${delivery.documentNumber}')),
          );
        },
      ),
      onCreateNew: () async {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('新規作成機能は後で実装します')),
        );
      },
    );
  }
}
