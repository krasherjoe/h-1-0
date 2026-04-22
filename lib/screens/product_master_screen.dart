import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/product_model.dart';
import '../models/product_category_model.dart';
import '../services/product_repository.dart';
import '../services/product_category_repository.dart';
import '../widgets/master_field_config.dart';
import '../widgets/rich_master_edit_sheet.dart';
import 'barcode_scanner_screen.dart';

class ProductMasterScreen extends StatefulWidget {
  final bool selectionMode;
  final bool showHidden;

  const ProductMasterScreen({
    super.key,
    this.selectionMode = false,
    this.showHidden = false,
  });

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
                      Text(
                        name.isEmpty ? '商品名未入力' : name,
                        style: theme.textTheme.titleMedium,
                      ),
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
                _ProductInfoChip(
                  label: '単価',
                  value: unitPrice.isEmpty ? '未設定' : '￥$unitPrice',
                ),
                _ProductInfoChip(
                  label: '在庫',
                  value: stockQuantity.isEmpty ? '0' : stockQuantity,
                ),
                _ProductInfoChip(
                  label: 'バーコード',
                  value: barcode.isEmpty ? '未登録' : barcode,
                ),
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
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: Colors.indigo),
          ),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ProductMasterScreenState extends State<ProductMasterScreen> {
  final ProductRepository _productRepo = ProductRepository();
  final ProductCategoryRepository _categoryRepo = ProductCategoryRepository();
  final TextEditingController _searchController = TextEditingController();

  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  List<ProductCategory> _categories = [];
  bool _isLoading = true;
  String _searchQuery = "";
  String _sortKey = 'name_asc';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final products = await _productRepo.getAllProducts(
      includeHidden: widget.showHidden,
    );
    final categories = await _categoryRepo.getAllCategories();
    if (!mounted) return;
    setState(() {
      _products = products;
      _categories = categories;
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
        _filteredProducts = _filteredProducts
            .where((p) => !p.isHidden)
            .toList();
      }
      if (widget.showHidden) {
        _filteredProducts.sort((a, b) => b.id.compareTo(a.id));
      } else {
        switch (_sortKey) {
          case 'name_desc':
            _filteredProducts.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
            break;
          default:
            _filteredProducts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
            break;
        }
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
          title: '商品情報',
          description: '商品の基本情報、価格、在庫を登録します',
          fields: [
            const MasterFieldConfig(
              key: 'name',
              label: '商品名',
              hint: '例: USB-Cケーブル 1m',
              required: true,
              flex: 2,
            ),
            MasterFieldConfig(
              key: 'category',
              label: 'カテゴリ',
              hint: '例: 周辺機器',
              suffixBuilder: (controller, setDialogState, updateValue) {
                return IconButton(
                  icon: const Icon(Icons.category),
                  onPressed: () async {
                    final selected = await showDialog<ProductCategory>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('カテゴリを選択'),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _categories.length + 1,
                            itemBuilder: (ctx, i) {
                              if (i == 0) {
                                return ListTile(
                                  title: const Text('未分類'),
                                  onTap: () => Navigator.pop(ctx),
                                );
                              }
                              final cat = _categories[i - 1];
                              return ListTile(
                                title: Text(cat.name),
                                onTap: () => Navigator.pop(ctx, cat),
                              );
                            },
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('キャンセル'),
                          ),
                        ],
                      ),
                    );
                    if (selected != null) {
                      updateValue(selected.name);
                    }
                  },
                );
              },
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
                      MaterialPageRoute(
                        builder: (context) => const BarcodeScannerScreen(),
                      ),
                    );
                    if (code != null) {
                      updateValue(code);
                    }
                  },
                );
              },
            ),
            const MasterFieldConfig(
              key: 'defaultUnitPrice',
              label: '標準単価 (税抜)',
              hint: '例: 1980',
              keyboardType: TextInputType.number,
            ),
            const MasterFieldConfig(
              key: 'stockQuantity',
              label: '在庫数',
              hint: '例: 120',
              keyboardType: TextInputType.number,
              flex: 1,
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
        final newId = locked
            ? const Uuid().v4()
            : (product?.id ?? const Uuid().v4());
        final defaultUnitPrice =
            int.tryParse(values['defaultUnitPrice'] ?? '') ?? 0;
        final stockQuantityStr = values['stockQuantity']?.trim();
        final barcode = values['barcode']?.trim();
        final category = values['category']?.trim();

        // 在庫数：空文字列の場合は null（在庫管理なし）、それ以外は数値
        int? stockQuantity;
        if (stockQuantityStr != null && stockQuantityStr.isNotEmpty) {
          stockQuantity = int.tryParse(stockQuantityStr);
        }

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
      // フッター透明度設定（キャンセル/保存ボタンの後ろのコンテンツが見えるように）
      footerColor: Colors.white.withOpacity(0.05),
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('商品の保存に失敗しました: $e')));
        }
      }
    }
  }

  /// 重複商品（同名で複数の現行レコードが存在するケース）を整理するリカバリー処理
  Future<void> _cleanupDuplicateVersions() async {
    if (_isLoading) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重複商品を整理'),
        content: const Text(
          '同じ商品名で複数のレコードが存在する場合、\n古い方を非現行化＆非表示にします。\n\nデータは削除されません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            child: const Text('整理する'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final count = await _productRepo.cleanupDuplicateVersions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count > 0 ? '$count件の古いレコードを非表示にしました' : '重複は見つかりませんでした'),
          backgroundColor: count > 0 ? Colors.green : null,
        ),
      );
      await _loadProducts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
      );
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
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _sortKey,
              icon: Icon(Icons.sort, color: Theme.of(context).colorScheme.onPrimary),
              dropdownColor: Theme.of(context).colorScheme.surface,
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
              selectedItemBuilder: (context) => [
                Text('名前昇順', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
                Text('名前降順', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
              ],
              items: [
                DropdownMenuItem(value: 'name_asc', child: Text('名前昇順', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
                DropdownMenuItem(value: 'name_desc', child: Text('名前降順', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
              ],
              onChanged: (v) {
                setState(() {
                  _sortKey = v ?? 'name_asc';
                  _applyFilter();
                });
              },
            ),
          ),
          if (!widget.selectionMode)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'cleanup_versions') {
                  _cleanupDuplicateVersions();
                }
              },
              itemBuilder: (BuildContext context) => const [
                PopupMenuItem(
                  value: 'cleanup_versions',
                  child: Row(
                    children: [
                      Icon(Icons.merge_type, size: 18, color: Colors.indigo),
                      SizedBox(width: 8),
                      Text('重複商品を整理'),
                    ],
                  ),
                ),
              ],
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Builder(
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final fillColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
              final hintColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: "商品名・バーコード・カテゴリで検索",
                    hintStyle: TextStyle(color: hintColor),
                    prefixIcon: Icon(Icons.search, color: hintColor),
                    filled: true,
                    fillColor: fillColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (val) {
                    _searchQuery = val;
                    _applyFilter();
                  },
                ),
              );
            }
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
                      backgroundColor: p.isLocked
                          ? Colors.grey.shade300
                          : Colors.indigo.shade100,
                      child: Stack(
                        children: [
                          const Align(
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.inventory_2,
                              color: Colors.indigo,
                            ),
                          ),
                          if (p.isLocked)
                            const Align(
                              alignment: Alignment.bottomRight,
                              child: Icon(
                                Icons.link,
                                size: 14,
                                color: Colors.redAccent,
                              ),
                            ),
                        ],
                      ),
                    ),
                    title: Builder(
                      builder: (context) {
                        final isDark = Theme.of(context).brightness == Brightness.dark;
                        return Text(
                          p.name + (p.isHidden ? " (非表示)" : ""),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: p.isHidden || p.isLocked
                                ? Colors.grey
                                : (isDark ? Colors.white : Colors.black87),
                          ),
                        );
                      }
                    ),
                    subtitle: Builder(
                      builder: (context) {
                        final isDark = Theme.of(context).brightness == Brightness.dark;
                        return Text(
                          "${p.category ?? '未分類'} - ￥${p.defaultUnitPrice} (在庫: ${p.stockQuantity?.toString() ?? '管理なし'})",
                          style: TextStyle(
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                          ),
                        );
                      }
                    ),
                    onTap: () {
                      if (widget.selectionMode) {
                        if (p.isHidden)
                          return; // safety: do not return hidden in selection
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
                                  leading: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                  ),
                                  title: const Text(
                                    "削除",
                                    style: TextStyle(color: Colors.redAccent),
                                  ),
                                  onTap: () async {
                                    Navigator.pop(ctx);
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text("削除の確認"),
                                        content: Text("${p.name} を削除しますか？"),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text("キャンセル"),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text(
                                              "削除",
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
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
                            onPressed: () => _showEditDialog(product: p),
                            tooltip: "編集（電子帳簿保存法対応：ロック中も履歴保存して編集可能）",
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
                  Icon(
                    p.isLocked ? Icons.link : Icons.inventory_2,
                    color: p.isLocked ? Colors.redAccent : Colors.indigo,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: p.isLocked ? Colors.grey : null,
                      ),
                    ),
                  ),
                  Chip(label: Text(p.category ?? '未分類')),
                ],
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final textColor = Theme.of(context).textTheme.bodyMedium?.color;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("単価: ￥${p.defaultUnitPrice}", style: TextStyle(color: textColor)),
                      Text("在庫: ${p.stockQuantity}", style: TextStyle(color: textColor)),
                      if (p.barcode != null && p.barcode!.isNotEmpty)
                        Text("バーコード: ${p.barcode}", style: TextStyle(color: textColor)),
                    ],
                  );
                }
              ),
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
                  OutlinedButton.icon(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    label: const Text(
                      "削除",
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("削除の確認（電子帳簿保存法）"),
                          content: Text(
                            "${p.name}を削除してよろしいですか？\n※電子帳簿保存法により、実際の削除は行わずに非表示フラグのみを設定します。履歴は保持されます。",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text("キャンセル"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text(
                                "削除",
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (!context.mounted) return;
                      if (confirmed == true) {
                        await _productRepo.setHiddenProduct(p.id, true);
                        if (!context.mounted) return;
                        Navigator.pop(context); // sheet
                        _loadProducts();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  if (!p.isLocked)
                    OutlinedButton.icon(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      label: const Text(
                        "削除",
                        style: TextStyle(color: Colors.redAccent),
                      ),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("削除の確認"),
                            content: Text("${p.name}を削除してよろしいですか？"),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text("キャンセル"),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text(
                                  "削除",
                                  style: TextStyle(color: Colors.red),
                                ),
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
                      child: Chip(
                        label: const Text("ロック済み"),
                        avatar: const Icon(Icons.link, size: 16),
                      ),
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
