import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/product_master.dart';
import '../models/invoice_models.dart';

/// 商品マスターの選択・登録・編集・削除を行うモーダル
class ProductPickerModal extends StatefulWidget {
  final Function(InvoiceItem) onItemSelected;

  const ProductPickerModal({
    Key? key,
    required this.onItemSelected,
  }) : super(key: key);

  @override
  State<ProductPickerModal> createState() => _ProductPickerModalState();
}

class _ProductPickerModalState extends State<ProductPickerModal> {
  String _searchQuery = "";
  List<Product> _masterProducts = [];
  List<Product> _filteredProducts = [];
  String _selectedCategory = "すべて";

  @override
  void initState() {
    super.initState();
    // 本来は永続化層から取得するが、現在はProductMasterの初期データを使用
    _masterProducts = List.from(ProductMaster.products);
    _filterProducts();
  }

  void _filterProducts() {
    setState(() {
      _filteredProducts = _masterProducts.where((product) {
        final matchesQuery = product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            product.id.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesCategory = _selectedCategory == "すべて" || (product.category == _selectedCategory);
        return matchesQuery && matchesCategory;
      }).toList();
    });
  }

  /// 商品の編集・新規登録用ダイアログ
  void _showProductEditDialog({Product? existingProduct}) {
    final idController = TextEditingController(text: existingProduct?.id ?? "");
    final nameController = TextEditingController(text: existingProduct?.name ?? "");
    final priceController = TextEditingController(text: existingProduct?.defaultUnitPrice.toString() ?? "");
    final categoryController = TextEditingController(text: existingProduct?.category ?? "");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existingProduct == null ? "新規商品の登録" : "商品情報の編集"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (existingProduct == null)
                TextField(
                  controller: idController,
                  decoration: const InputDecoration(labelText: "商品コード (例: S001)", border: OutlineInputBorder()),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "商品名", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "標準単価", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: "カテゴリ (任意)", border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("キャンセル")),
          ElevatedButton(
            onPressed: () {
              final String name = nameController.text.trim();
              final int price = int.tryParse(priceController.text) ?? 0;
              if (name.isEmpty) return;

              setState(() {
                if (existingProduct != null) {
                  // 更新
                  final index = _masterProducts.indexWhere((p) => p.id == existingProduct.id);
                  if (index != -1) {
                    _masterProducts[index] = existingProduct.copyWith(
                      name: name,
                      defaultUnitPrice: price,
                      category: categoryController.text.trim(),
                    );
                  }
                } else {
                  // 新規追加
                  _masterProducts.add(Product(
                    id: idController.text.isEmpty ? const Uuid().v4().substring(0, 8) : idController.text,
                    name: name,
                    defaultUnitPrice: price,
                    category: categoryController.text.trim(),
                  ));
                }
                _filterProducts();
              });
              Navigator.pop(context);
            },
            child: const Text("保存"),
          ),
        ],
      ),
    );
  }

  /// 削除確認
  void _confirmDelete(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("商品の削除"),
        content: Text("「${product.name}」をマスターから削除しますか？"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("キャンセル")),
          TextButton(
            onPressed: () {
              setState(() {
                _masterProducts.removeWhere((p) => p.id == product.id);
                _filterProducts();
              });
              Navigator.pop(context);
            },
            child: const Text("削除する", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // マスター内のカテゴリを動的に取得
    final dynamicCategories = ["すべて", ..._masterProducts.map((p) => p.category ?? 'その他').toSet().toList()];

    return Material(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("商品マスター管理", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    hintText: "商品名やコードで検索...",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onChanged: (val) {
                    _searchQuery = val;
                    _filterProducts();
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: dynamicCategories.map((cat) {
                            final isSelected = _selectedCategory == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(cat),
                                selected: isSelected,
                                onSelected: (s) {
                                  if (s) {
                                    setState(() {
                                      _selectedCategory = cat;
                                      _filterProducts();
                                    });
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () => _showProductEditDialog(),
                      icon: const Icon(Icons.add),
                      tooltip: "新規商品を追加",
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _filteredProducts.isEmpty
                ? const Center(child: Text("該当する商品がありません"))
                : ListView.separated(
                    itemCount: _filteredProducts.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      return ListTile(
                        leading: const Icon(Icons.inventory_2, color: Colors.blueGrey),
                        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("${product.id} | ¥${product.defaultUnitPrice}"),
                        onTap: () => widget.onItemSelected(product.toInvoiceItem()),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blueGrey),
                              onPressed: () => _showProductEditDialog(existingProduct: product),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                              onPressed: () => _confirmDelete(product),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
