import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/product_model.dart';
import '../services/product_repository.dart';
import 'barcode_scanner_screen.dart';
import '../widgets/keyboard_inset_wrapper.dart';

class ProductMasterScreen extends StatefulWidget {
  const ProductMasterScreen({Key? key}) : super(key: key);

  @override
  State<ProductMasterScreen> createState() => _ProductMasterScreenState();
}

class _ProductMasterScreenState extends State<ProductMasterScreen> {
  final ProductRepository _productRepo = ProductRepository();
  final TextEditingController _searchController = TextEditingController();

  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  String _searchQuery = "";

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
      _applyFilter();
    });
  }

  void _applyFilter() {
    setState(() {
      _filteredProducts = _products.where((p) {
        final query = _searchQuery.toLowerCase();
        return p.name.toLowerCase().contains(query) ||
               (p.barcode?.toLowerCase().contains(query) ?? false) ||
               (p.category?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  Future<void> _showEditDialog({Product? product}) async {
    final nameController = TextEditingController(text: product?.name ?? "");
    final priceController = TextEditingController(text: (product?.defaultUnitPrice ?? 0).toString());
    final barcodeController = TextEditingController(text: product?.barcode ?? "");
    final categoryController = TextEditingController(text: product?.category ?? "");
    final stockController = TextEditingController(text: (product?.stockQuantity ?? 0).toString());

    final result = await showDialog<Product>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(product == null ? "商品追加" : "商品編集"),
          content: KeyboardInsetWrapper(
            basePadding: EdgeInsets.zero,
            extraBottom: 16,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: "商品名")),
                  TextField(controller: categoryController, decoration: const InputDecoration(labelText: "カテゴリ")),
                  TextField(controller: priceController, decoration: const InputDecoration(labelText: "初期単価"), keyboardType: TextInputType.number),
                  TextField(controller: stockController, decoration: const InputDecoration(labelText: "在庫数"), keyboardType: TextInputType.number),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(controller: barcodeController, decoration: const InputDecoration(labelText: "バーコード")),
                      ),
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: () async {
                          final code = await Navigator.push<String>(
                            context,
                            MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
                          );
                          if (code != null) {
                            setDialogState(() => barcodeController.text = code);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("キャンセル")),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty) return;
                Navigator.pop(
                  context,
                  Product(
                    id: product?.id ?? const Uuid().v4(),
                    name: nameController.text.trim(),
                    defaultUnitPrice: int.tryParse(priceController.text) ?? 0,
                    barcode: barcodeController.text.isEmpty ? null : barcodeController.text.trim(),
                    category: categoryController.text.isEmpty ? null : categoryController.text.trim(),
                    stockQuantity: int.tryParse(stockController.text) ?? 0,
                    odooId: product?.odooId,
                  ),
                );
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
        leading: const BackButton(),
        title: const Text("商品マスター"),
        backgroundColor: Colors.blueGrey,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "商品名・バーコード・カテゴリで検索",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (val) {
                _searchQuery = val;
                _applyFilter();
              },
            ),
          ),
        ),
      ),
      body: KeyboardInsetWrapper(
        basePadding: EdgeInsets.zero,
        extraBottom: 72,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _filteredProducts.isEmpty
                ? const Center(child: Text("商品が見つかりません"))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 120, top: 8),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final p = _filteredProducts[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: p.isLocked ? Colors.grey.shade300 : Colors.indigo.shade100,
                          child: Stack(
                            children: [
                              const Align(alignment: Alignment.center, child: Icon(Icons.inventory_2, color: Colors.indigo)),
                              if (p.isLocked)
                                const Align(alignment: Alignment.bottomRight, child: Icon(Icons.lock, size: 14, color: Colors.redAccent)),
                            ],
                          ),
                        ),
                        title: Text(p.name, style: TextStyle(fontWeight: FontWeight.bold, color: p.isLocked ? Colors.grey : Colors.black87)),
                        subtitle: Text("${p.category ?? '未分類'} - ￥${p.defaultUnitPrice} (在庫: ${p.stockQuantity})"),
                        onTap: () => _showDetailPane(p),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: p.isLocked ? null : () => _showEditDialog(product: p),
                          tooltip: p.isLocked ? "ロック中" : "編集",
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        child: const Icon(Icons.add),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showDetailPane(Product p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        maxChildSize: 0.8,
        minChildSize: 0.35,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                children: [
                  Icon(p.isLocked ? Icons.lock : Icons.inventory_2, color: p.isLocked ? Colors.redAccent : Colors.indigo),
                  const SizedBox(width: 8),
                  Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                  Chip(label: Text(p.category ?? '未分類')),
                ],
              ),
              const SizedBox(height: 8),
              Text("単価: ￥${p.defaultUnitPrice}"),
              Text("在庫: ${p.stockQuantity}"),
              if (p.barcode != null && p.barcode!.isNotEmpty) Text("バーコード: ${p.barcode}"),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showEditDialog(product: p);
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text("編集"),
                  ),
                  const SizedBox(width: 8),
                  if (!p.isLocked)
                    OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("削除の確認"),
                            content: Text("${p.name}を削除してよろしいですか？"),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text("キャンセル")),
                              TextButton(
                                onPressed: () async {
                                  await _productRepo.deleteProduct(p.id);
                                  if (!mounted) return;
                                  Navigator.pop(context); // dialog
                                  Navigator.pop(context); // sheet
                                  _loadProducts();
                                },
                                child: const Text("削除", style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      label: const Text("削除", style: TextStyle(color: Colors.redAccent)),
                    ),
                  if (p.isLocked)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Chip(label: const Text("ロック中"), avatar: const Icon(Icons.lock, size: 16)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
