import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/product_model.dart';
import '../services/product_repository.dart';
import '../widgets/master_field_config.dart';
import '../widgets/rich_master_edit_sheet.dart';
import 'barcode_scanner_screen.dart';

class ProductMasterScreen extends StatefulWidget {
  final bool selectionMode;
  final bool showHidden;

  const ProductMasterScreen({super.key, this.selectionMode = false, this.showHidden = false});

  @override
  State<ProductMasterScreen> createState() => _ProductMasterScreenState();
}

class ProductPreviewCard extends StatelessWidget {
  const ProductPreviewCard({
    super.key,
    required this.name,
    required this.category,
    required this.barcode,
    required this.unitPrice,
    required this.stockQuantity,
  });

  final String name;
  final String category;
  final String barcode;
  final String unitPrice;
  final String stockQuantity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.inventory_2, color: Colors.indigo),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.isEmpty ? '商品名未入力' : name, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        category.isEmpty ? 'カテゴリ: 未分類' : 'カテゴリ: $category',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _ProductInfoChip(label: '単価', value: unitPrice.isEmpty ? '未設定' : '￥$unitPrice'),
                _ProductInfoChip(label: '在庫', value: stockQuantity.isEmpty ? '0' : stockQuantity),
                _ProductInfoChip(label: 'バーコード', value: barcode.isEmpty ? '未登録' : barcode),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductInfoChip extends StatelessWidget {
  const _ProductInfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.indigo)),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
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
    final products = await _productRepo.getAllProducts(includeHidden: widget.showHidden);
    if (!mounted) return;
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
      if (!widget.showHidden) {
        _filteredProducts = _filteredProducts.where((p) => !p.isHidden).toList();
      }
      if (widget.showHidden) {
        _filteredProducts.sort((a, b) => b.id.compareTo(a.id));
      }
    });
  }

  Future<void> _showEditDialog({Product? product}) async {
    final result = await showRichMasterEditSheet<Product>(
      context: context,
      titleNew: '商品追加',
      titleEdit: '商品編集',
      existing: product,
      sections: [
        RichMasterSection(
          title: '基本情報',
          description: '商品名・カテゴリ・バーコードを登録します',
          fields: [
            const MasterFieldConfig(
              key: 'name',
              label: '商品名',
              hint: '例: USB-Cケーブル 1m',
              required: true,
              flex: 2,
            ),
            const MasterFieldConfig(
              key: 'category',
              label: 'カテゴリ',
              hint: '例: 周辺機器',
            ),
            MasterFieldConfig(
              key: 'barcode',
              label: 'バーコード',
              hint: 'JAN / SKU',
              suffixBuilder: (controller, setDialogState, updateValue) {
                return IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () async {
                    final code = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
                    );
                    if (code != null) {
                      updateValue(code);
                    }
                  },
                );
              },
            ),
          ],
        ),
        RichMasterSection(
          title: '価格・在庫',
          description: '販売単価や在庫数を管理します',
          fields: const [
            MasterFieldConfig(
              key: 'defaultUnitPrice',
              label: '標準単価 (税抜)',
              hint: '例: 1980',
              keyboardType: TextInputType.number,
            ),
            MasterFieldConfig(
              key: 'stockQuantity',
              label: '在庫数',
              hint: '例: 120',
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ],
      initialValuesBuilder: (p) => {
        'name': p?.name ?? '',
        'category': p?.category ?? '',
        'defaultUnitPrice': (p?.defaultUnitPrice ?? 0).toString(),
        'stockQuantity': (p?.stockQuantity ?? 0).toString(),
        'barcode': p?.barcode ?? '',
      },
      previewBuilder: (ctx, controller) => ProductPreviewCard(
        name: controller.valueOf('name'),
        category: controller.valueOf('category'),
        barcode: controller.valueOf('barcode'),
        unitPrice: controller.valueOf('defaultUnitPrice'),
        stockQuantity: controller.valueOf('stockQuantity'),
      ),
      buildModel: (values) {
        final locked = product?.isLocked ?? false;
        final newId = locked ? const Uuid().v4() : (product?.id ?? const Uuid().v4());
        final defaultUnitPrice = int.tryParse(values['defaultUnitPrice'] ?? '') ?? 0;
        final stockQuantity = int.tryParse(values['stockQuantity'] ?? '') ?? 0;
        final barcode = values['barcode']?.trim();
        final category = values['category']?.trim();

        return Product(
          id: newId,
          name: values['name']?.trim() ?? '',
          defaultUnitPrice: defaultUnitPrice,
          stockQuantity: stockQuantity,
          barcode: (barcode?.isEmpty ?? true) ? null : barcode,
          category: (category?.isEmpty ?? true) ? null : category,
          odooId: product?.odooId,
          isLocked: false,
        );
      },
    );

    if (result != null) {
      if (!mounted) return;
      try {
        await _productRepo.saveProduct(result);
        _loadProducts();
      } catch (e, st) {
        print('P1 商品保存エラー: $e');
        print('スタックトレース: $st');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('商品の保存に失敗しました: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text("P1:商品マスター"),
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
      body: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _filteredProducts.isEmpty
                ? const Center(child: Text("商品が見つかりません"))
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 80, top: 8),
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
                        title: Text(
                          p.name + (p.isHidden ? " (非表示)" : ""),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: p.isHidden
                                ? Colors.grey
                                : (p.isLocked ? Colors.grey : Colors.black87),
                          ),
                        ),
                        subtitle: Text("${p.category ?? '未分類'} - ￥${p.defaultUnitPrice} (在庫: ${p.stockQuantity})"),
                        onTap: () {
                          if (widget.selectionMode) {
                            if (p.isHidden) return; // safety: do not return hidden in selection
                            Navigator.pop(context, p);
                          } else {
                            _showDetailPane(p);
                          }
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
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      _showEditDialog(product: p);
                                    },
                                  ),
                                  if (!p.isHidden)
                                    ListTile(
                                      leading: const Icon(Icons.visibility_off),
                                      title: const Text("非表示にする"),
                                      onTap: () async {
                                        Navigator.pop(ctx);
                                        await _productRepo.setHidden(p.id, true);
                                        if (mounted) _loadProducts();
                                      },
                                    ),
                                  if (!p.isLocked)
                                    ListTile(
                                      leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                      title: const Text("削除", style: TextStyle(color: Colors.redAccent)),
                                      onTap: () async {
                                        Navigator.pop(ctx);
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text("削除の確認"),
                                            content: Text("${p.name} を削除しますか？"),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("キャンセル")),
                                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("削除", style: TextStyle(color: Colors.red))),
                                            ],
                                          ),
                                        );
                                        if (confirmed == true) {
                                          await _productRepo.deleteProduct(p.id);
                                          if (mounted) _loadProducts();
                                        }
                                      },
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                        trailing: widget.selectionMode
                            ? null
                            : IconButton(
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
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
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
                    icon: const Icon(Icons.edit),
                    label: const Text("編集"),
                    onPressed: () {
                      Navigator.pop(context);
                      _showEditDialog(product: p);
                    },
                  ),
                  const SizedBox(width: 8),
                  if (!p.isLocked)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      label: const Text("削除", style: TextStyle(color: Colors.redAccent)),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("削除の確認"),
                            content: Text("${p.name}を削除してよろしいですか？"),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("キャンセル")),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text("削除", style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (!context.mounted) return;
                        if (confirmed == true) {
                          await _productRepo.deleteProduct(p.id);
                          if (!context.mounted) return;
                          Navigator.pop(context); // sheet
                          _loadProducts();
                        }
                      },
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
