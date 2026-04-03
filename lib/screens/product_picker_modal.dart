import 'package:flutter/material.dart';
import '../models/invoice_models.dart';
import '../models/product_model.dart';
import '../services/product_repository.dart';
import 'product_master_screen.dart';

/// 商品マスターから項目を選択するためのモーダル（スタブ実装）
class ProductPickerModal extends StatefulWidget {
  final ValueChanged<InvoiceItem>? onItemSelected;
  final ValueChanged<Product>? onProductSelected;

  const ProductPickerModal({super.key, this.onItemSelected, this.onProductSelected})
      : assert(onItemSelected != null || onProductSelected != null, '少なくとも1つのコールバックを指定してください');

  @override
  State<ProductPickerModal> createState() => _ProductPickerModalState();
}

class _ProductPickerModalState extends State<ProductPickerModal> {
  final ProductRepository _productRepo = ProductRepository();
  final TextEditingController _searchController = TextEditingController();
  List<Product> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _onSearch(""); // 初期表示
  }

  Future<void> _onSearch(String val) async {
    setState(() => _isLoading = true);
    final products = await _productRepo.searchProducts(val);
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
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 4),
                const Text("商品・サービス選択", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: "商品名・カテゴリ・バーコードで検索",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () { _searchController.clear(); _onSearch(""); },
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: _onSearch,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("商品が見つかりません"),
                            TextButton(
                              onPressed: () async {
                                await Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductMasterScreen()));
                                _onSearch(_searchController.text);
                              },
                              child: const Text("マスターに追加する"),
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
                            subtitle: Text("￥${product.defaultUnitPrice} (在庫: ${product.stockQuantity})"),
                            onTap: () {
                              if (widget.onProductSelected != null) {
                                widget.onProductSelected!(product);
                              } else if (widget.onItemSelected != null) {
                                widget.onItemSelected!(
                                  InvoiceItem(
                                    productId: product.id,
                                    description: product.name,
                                    quantity: 1,
                                    unitPrice: product.defaultUnitPrice,
                                  ),
                                );
                              }
                              Navigator.pop(context);
                            },
                            onLongPress: () async {
                              await showModalBottomSheet(
                                context: context,
                                builder: (ctx) => SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.edit),
                                        title: const Text("編集"),
                                        onTap: () async {
                                          Navigator.pop(ctx);
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => const ProductMasterScreen()),
                                          );
                                          _onSearch(_searchController.text);
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                        title: const Text("削除", style: TextStyle(color: Colors.redAccent)),
                                        onTap: () async {
                                          Navigator.pop(ctx);
                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                              title: const Text("削除の確認"),
                                              content: Text("${product.name} を削除しますか？"),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("キャンセル")),
                                                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("削除", style: TextStyle(color: Colors.red))),
                                              ],
                                            ),
                                          );
                                          if (confirmed == true) {
                                            await _productRepo.deleteProduct(product.id);
                                            if (mounted) _onSearch(_searchController.text);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
