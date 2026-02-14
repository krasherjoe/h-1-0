import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/product_model.dart';
import '../services/product_repository.dart';
import 'barcode_scanner_screen.dart';

class ProductMasterScreen extends StatefulWidget {
  const ProductMasterScreen({Key? key}) : super(key: key);

  @override
  State<ProductMasterScreen> createState() => _ProductMasterScreenState();
}

class _ProductMasterScreenState extends State<ProductMasterScreen> {
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

  Future<void> _addItem({Product? product}) async {
    final isEdit = product != null;
    final nameController = TextEditingController(text: product?.name ?? "");
    final priceController = TextEditingController(text: product?.defaultUnitPrice.toString() ?? "0");
    final barcodeController = TextEditingController(text: product?.barcode ?? "");

    final result = await showDialog<Product>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? "商品を編集" : "商品を新規登録"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "商品名"),
              ),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: "初期単価"),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: barcodeController,
                      decoration: const InputDecoration(labelText: "バーコード"),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: () async {
                      final code = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
                      );
                      if (code != null) {
                        setDialogState(() {
                          barcodeController.text = code;
                        });
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("キャンセル")),
            TextButton(
              onPressed: () {
                if (nameController.text.isEmpty) return;
                final newProduct = Product(
                  id: product?.id ?? const Uuid().v4(),
                  name: nameController.text,
                  defaultUnitPrice: int.tryParse(priceController.text) ?? 0,
                  barcode: barcodeController.text.isEmpty ? null : barcodeController.text,
                  odooId: product?.odooId,
                );
                Navigator.pop(context, newProduct);
              },
              child: const Text("保存"),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await _productRepo.saveProduct(result);
      _loadProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("商品マスター管理"),
        backgroundColor: Colors.blueGrey,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? const Center(child: Text("商品が登録されていません"))
              : ListView.builder(
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final p = _products[index];
                    return ListTile(
                      title: Text(p.name),
                      subtitle: Text("初期単価: ￥${p.defaultUnitPrice}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit), onPressed: () => _addItem(product: p)),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text("削除確認"),
                                  content: Text("「${p.name}」を削除しますか？"),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("キャンセル")),
                                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("削除", style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _productRepo.deleteProduct(p.id);
                                _loadProducts();
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        child: const Icon(Icons.add),
        backgroundColor: Colors.indigo,
      ),
    );
  }
}
