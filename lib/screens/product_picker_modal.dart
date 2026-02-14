import 'package:flutter/material.dart';
import '../models/invoice_models.dart';

/// 商品マスターから項目を選択するためのモーダル（スタブ実装）
class ProductPickerModal extends StatefulWidget {
  final Function(InvoiceItem) onItemSelected;

  const ProductPickerModal({Key? key, required this.onItemSelected}) : super(key: key);

  @override
  State<ProductPickerModal> createState() => _ProductPickerModalState();
}

class _ProductPickerModalState extends State<ProductPickerModal> {
  // 本来はデータベースから取得しますが、現時点ではスタブデータを表示します
  final List<InvoiceItem> _masterProducts = [
    InvoiceItem(description: "技術料", quantity: 1, unitPrice: 50000),
    InvoiceItem(description: "部品代 A", quantity: 1, unitPrice: 15000),
    InvoiceItem(description: "部品代 B", quantity: 1, unitPrice: 3000),
    InvoiceItem(description: "出張費", quantity: 1, unitPrice: 10000),
    InvoiceItem(description: "諸経費", quantity: 1, unitPrice: 5000),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("商品・サービス選択", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: _masterProducts.length,
              itemBuilder: (context, index) {
                final product = _masterProducts[index];
                return ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(product.description),
                  subtitle: Text("単価: ￥${product.unitPrice}"),
                  onTap: () => widget.onItemSelected(product),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
