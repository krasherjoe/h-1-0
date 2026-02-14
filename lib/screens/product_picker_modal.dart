import 'package:flutter/material.dart';
import '../models/invoice_models.dart';
import '../models/product_model.dart';
import '../services/product_repository.dart';
import 'product_master_screen.dart';

/// 商品マスターから項目を選択するためのモーダル（スタブ実装）
class ProductPickerModal extends StatefulWidget {
  final Function(InvoiceItem) onItemSelected;

  const ProductPickerModal({Key? key, required this.onItemSelected}) : super(key: key);

  @override
  State<ProductPickerModal> createState() => _ProductPickerModalState();
}

class _ProductPickerModalState extends State<ProductPickerModal> {
  final ProductRepository _productRepo = ProductRepository();
  List<Product> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final products = await _productRepo.getAllProducts();
    setState(() {
      _products = products;
      _isLoading = false;
    });
  }

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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("商品マスターが空です"),
                            TextButton(
                              onPressed: () async {
                                await Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductMasterScreen()));
                                _loadProducts();
                              },
                              child: const Text("商品マスターを編集する"),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _products.length,
                        itemBuilder: (context, index) {
                          final product = _products[index];
                          return ListTile(
                            leading: const Icon(Icons.inventory_2_outlined),
                            title: Text(product.name),
                            subtitle: Text("初期単価: ￥${product.defaultUnitPrice}"),
                            onTap: () => widget.onItemSelected(
                              InvoiceItem(
                                description: product.name,
                                quantity: 1,
                                unitPrice: product.defaultUnitPrice,
                              ),
                            ),
                          );
                        },
                      ),
          ),
          if (_products.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text("商品マスターの管理"),
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductMasterScreen()));
                  _loadProducts();
                },
              ),
            ),
        ],
      ),
    );
  }
}
