import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/product_model.dart';
import '../models/product_category_model.dart';
import '../services/product_repository.dart';
import '../services/product_category_repository.dart';
import '../widgets/master_field_config.dart';
import '../widgets/paste_buffer_dialog.dart';
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
    this.wholesalePrice,
    required this.stockQuantity,
  });

  final String name;
  final String category;
  final String barcode;
  final String unitPrice;
  final String? wholesalePrice;
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
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.inventory_2, color: Theme.of(context).colorScheme.primary),
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
                if (wholesalePrice != null && wholesalePrice!.isNotEmpty)
                  _ProductInfoChip(
                    label: '仕入',
                    value: '￥$wholesalePrice',
                  ),
                if (!const ['サポート', 'サービス'].contains(category))
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.4),
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
            ).textTheme.labelSmall?.copyWith(color: colorScheme.primary),
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
  final Uuid _uuid = const Uuid();
  final Map<String, bool> _taxFlags = {};
  final TextEditingController _searchController = TextEditingController();

  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  List<ProductCategory> _categories = [];
  bool _isLoading = true;
  String _searchQuery = "";
  String _sortKey = 'name_asc';
  bool _showHidden = false;
  bool _selectMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _showHidden = widget.showHidden;
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final products = await _productRepo.getAllProducts(
      includeHidden: _showHidden,
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
      if (!_showHidden) {
        _filteredProducts = _filteredProducts
            .where((p) => !p.isHidden)
            .toList();
      }
      if (_showHidden) {
        _filteredProducts.sort((a, b) => b.id.compareTo(a.id));
      } else {
        switch (_sortKey) {
          case 'name_desc':
            _filteredProducts.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
            break;
          case 'category_asc':
            _filteredProducts.sort((a, b) {
              final catA = (a.category ?? '').toLowerCase();
              final catB = (b.category ?? '').toLowerCase();
              final cmp = catA.compareTo(catB);
              if (cmp != 0) return cmp;
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            });
            break;
          default:
            _filteredProducts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
            break;
        }
      }
    });
  }

  Future<String?> _showCategoryPicker() async {
    await _loadProducts(); // カテゴリリストを最新化
    if (!mounted) return null;
    final theme = Theme.of(context);
    final TextEditingController newCatCtrl = TextEditingController();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              minChildSize: 0.4,
              builder: (_, scrollCtrl) => Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('カテゴリを選択',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: newCatCtrl,
                            decoration: InputDecoration(
                              hintText: '新規カテゴリ名',
                              isDense: true,
                              filled: true,
                              fillColor: theme.cardColor,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: theme.dividerColor)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final name = newCatCtrl.text.trim();
                            if (name.isEmpty) return;
                            await _categoryRepo.getOrCreateCategoryId(name);
                            await _loadProducts();
                            if (ctx.mounted) Navigator.pop(ctx, name);
                          },
                          child: const Text('追加'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 16),
                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      children: [
                        Card(
                          color: theme.cardColor,
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: const Icon(Icons.clear, size: 18),
                            title: const Text('未分類（クリア）'),
                            onTap: () => Navigator.pop(ctx, ''),
                          ),
                        ),
                        ..._categories.map((c) => Card(
                          color: theme.cardColor,
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: const Icon(Icons.label_outline, size: 18),
                            title: Text(c.name),
                            onTap: () => Navigator.pop(ctx, c.name),
                          ),
                        )),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmBatchDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('一括削除'),
        content: Text('${_selectedIds.length}件の商品を削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除')),
        ],
      ),
    );
    if (confirmed != true) return;
    final ids = _selectedIds.toList();
    for (final id in ids) {
      try { await _productRepo.deleteProduct(id); } catch (_) {}
    }
    if (!mounted) return;
    setState(() { _selectMode = false; _selectedIds.clear(); });
    _loadProducts();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${ids.length}件削除しました')));
  }

  Future<void> _importFromPasteBuffer() async {
    final items = await showPasteBufferScreen(context);
    if (items.isEmpty) return;
    var imported = 0;
    for (final item in items) {
      try {
        await _productRepo.saveProduct(Product(id: _uuid.v4(), name: item.name, wholesalePrice: item.price, defaultUnitPrice: item.price));
        imported++;
      } catch (_) {}
    }
    if (!mounted) return;
    _loadProducts();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$imported件の商品をマスターに登録しました')));
  }

  Future<void> _showEditDialog({Product? product}) async {
    final theme = Theme.of(context);
    _taxFlags['defaultUnitPriceIsTaxInclusive'] = product?.defaultUnitPriceIsTaxInclusive ?? false;
    _taxFlags['wholesalePriceIsTaxInclusive'] = product?.wholesalePriceIsTaxInclusive ?? false;
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
              hint: 'カテゴリを選択または入力',
              suffixBuilder: (ctrl, setDialogState, updateValue) {
                return IconButton(
                  icon: const Icon(Icons.list_alt),
                  tooltip: 'カテゴリマスターから選択',
                  onPressed: () async {
                    final selected = await _showCategoryPicker();
                    if (selected != null) {
                      ctrl.text = selected;
                      updateValue(selected);
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
            MasterFieldConfig(
              key: 'defaultUnitPrice',
              label: '標準単価',
              hint: '例: 1980',
              keyboardType: TextInputType.number,
              suffixBuilder: (ctrl, setDialogState, updateValue) {
                final isTaxInclusive = _taxFlags['defaultUnitPriceIsTaxInclusive'] ?? false;
                return TextButton(
                  onPressed: () {
                    _taxFlags['defaultUnitPriceIsTaxInclusive'] = !isTaxInclusive;
                    setDialogState(() {});
                  },
                  child: Text(isTaxInclusive ? '税込' : '税抜',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isTaxInclusive ? Colors.orange : Colors.grey)),
                );
              },
            ),
            MasterFieldConfig(
              key: 'wholesalePrice',
              label: '仕入単価',
              hint: '例: 1200',
              keyboardType: TextInputType.number,
              suffixBuilder: (ctrl, setDialogState, updateValue) {
                final isTaxInclusive = _taxFlags['wholesalePriceIsTaxInclusive'] ?? false;
                return TextButton(
                  onPressed: () {
                    _taxFlags['wholesalePriceIsTaxInclusive'] = !isTaxInclusive;
                    setDialogState(() {});
                  },
                  child: Text(isTaxInclusive ? '税込' : '税抜',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isTaxInclusive ? Colors.orange : Colors.grey)),
                );
              },
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
        'wholesalePrice': (p?.wholesalePrice ?? 0).toString(),
        'stockQuantity': (p?.stockQuantity ?? 0).toString(),
        'barcode': p?.barcode ?? '',
      },
      previewBuilder: (ctx, controller) => ProductPreviewCard(
        name: controller.valueOf('name'),
        category: controller.valueOf('category'),
        barcode: controller.valueOf('barcode'),
        unitPrice: controller.valueOf('defaultUnitPrice'),
        wholesalePrice: controller.valueOf('wholesalePrice'),
        stockQuantity: controller.valueOf('stockQuantity'),
      ),
      buildModel: (values) {
        final locked = product?.isLocked ?? false;
        final newId = locked
            ? const Uuid().v4()
            : (product?.id ?? const Uuid().v4());
        final defaultUnitPrice =
            int.tryParse(values['defaultUnitPrice'] ?? '') ?? 0;
        final wholesalePrice =
            int.tryParse(values['wholesalePrice'] ?? '') ?? 0;
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
          defaultUnitPriceIsTaxInclusive: _taxFlags['defaultUnitPriceIsTaxInclusive'] ?? false,
          wholesalePrice: wholesalePrice,
          wholesalePriceIsTaxInclusive: _taxFlags['wholesalePriceIsTaxInclusive'] ?? false,
          stockQuantity: stockQuantity,
          barcode: (barcode?.isEmpty ?? true) ? null : barcode,
          category: (category?.isEmpty ?? true) ? null : category,
          odooId: product?.odooId,
          isLocked: false,
        );
      },
      // フッター透明度設定（キャンセル/保存ボタンの後ろのコンテンツが見えるように）
      footerColor: theme.dividerColor.withValues(alpha: 0.05),
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
    final theme = Theme.of(context);
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
             style: ElevatedButton.styleFrom(
               backgroundColor: Theme.of(context).colorScheme.error,
               foregroundColor: theme.cardColor,
             ),
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
           backgroundColor: count > 0 ? Theme.of(context).colorScheme.primary : null,
         ),
       );
       await _loadProducts();
     } catch (e) {
       if (!mounted) return;
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('エラー: $e'), backgroundColor: Theme.of(context).colorScheme.error),
       );
     }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: _selectMode
            ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _selectMode = false; _selectedIds.clear(); }))
            : const BackButton(),
        title: Text(_selectMode ? '${_selectedIds.length}件選択' : "P1:商品マスター"),
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actionsPadding: const EdgeInsets.only(right: 8),
        actions: _selectMode
            ? <Widget>[
                if (_selectedIds.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete),
                    tooltip: '選択を削除',
                    onPressed: _confirmBatchDelete,
                  ),
              ]
            : <Widget>[
          IconButton(
            icon: const Icon(Icons.content_paste),
            tooltip: 'テキストから取込',
            onPressed: _importFromPasteBuffer,
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _sortKey,
              icon: Icon(Icons.sort, color: Theme.of(context).colorScheme.onPrimary),
              dropdownColor: Theme.of(context).colorScheme.surface,
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
              selectedItemBuilder: (context) => [
                const SizedBox.shrink(),
                const SizedBox.shrink(),
                const SizedBox.shrink(),
              ],
              items: [
                DropdownMenuItem(value: 'name_asc', child: Text('名前昇順', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
                DropdownMenuItem(value: 'name_desc', child: Text('名前降順', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
                DropdownMenuItem(value: 'category_asc', child: Text('カテゴリ昇順', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
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
                } else if (value == 'toggle_hidden') {
                  setState(() => _showHidden = !_showHidden);
                  _loadProducts();
                }
              },
              itemBuilder: (BuildContext context) => [
PopupMenuItem(
                   value: 'cleanup_versions',
                   child: Row(
                     children: [
                       Icon(Icons.merge_type, size: 18, color: Theme.of(context).colorScheme.primary),
                       SizedBox(width: 8),
                       Text('重複商品を整理'),
                     ],
                   ),
                 ),
                 PopupMenuItem(
                   value: 'toggle_hidden',
                   child: Row(
                     children: [
                       Icon(
                         _showHidden ? Icons.visibility_off : Icons.visibility,
                         size: 18,
                         color: Theme.of(context).colorScheme.primary,
                       ),
                      SizedBox(width: 8),
                      Text(_showHidden ? '非表示商品を隠す' : '非表示商品を表示'),
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
              final fillColor = theme.cardColor;
              final hintColor = theme.hintColor;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: theme.textTheme.bodyMedium?.color),
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
                padding: const EdgeInsets.only(bottom: 80, top: 4, left: 12, right: 12),
                itemCount: _filteredProducts.length,
                itemBuilder: (context, index) {
                  final p = _filteredProducts[index];
                  return Card(
                    color: p.isHidden ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3) : theme.cardColor,
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: p.isHidden
                          ? BorderSide(color: Theme.of(context).colorScheme.errorContainer, width: 1)
                          : BorderSide.none,
                    ),
                    child: ListTile(
                    leading: _selectMode
                        ? Checkbox(
                            value: _selectedIds.contains(p.id),
                            onChanged: (_) => setState(() { if (_selectedIds.contains(p.id)) _selectedIds.remove(p.id); else _selectedIds.add(p.id); }),
                          )
                        : CircleAvatar(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Stack(
                              children: [
                                Align(
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.inventory_2,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                if (p.isLocked)
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Icon(
                                      Icons.link,
                                      size: 14,
                                      color: Theme.of(context).colorScheme.error,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                    title: Builder(
                      builder: (context) {
                        return Text(
                          p.name + (p.isHidden ? " (非表示)" : ""),
                          style: TextStyle(
                            fontWeight: p.isHidden || p.isLocked ? FontWeight.normal : FontWeight.bold,
                            color: p.isHidden
                                ? Theme.of(context).colorScheme.error
                                : theme.textTheme.bodyMedium?.color,
                          ),
                        );
                      }
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (p.category != null && p.category!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  margin: const EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(3)),
                                  child: Text(p.category!, style: TextStyle(fontSize: 9, color: theme.colorScheme.primary)),
                                ),
                              if (p.defaultUnitPriceIsTaxInclusive)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  margin: const EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)),
                                  child: Text('税込', style: TextStyle(fontSize: 9, color: Colors.orange.shade700)),
                                ),
                              if (p.wholesalePriceIsTaxInclusive)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  margin: const EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)),
                                  child: Text('仕入税込', style: TextStyle(fontSize: 9, color: Colors.blue.shade700)),
                                ),
                              if (p.barcode != null && p.barcode!.isNotEmpty)
                                Text(p.barcode!, style: TextStyle(fontSize: 8, color: theme.colorScheme.onSurfaceVariant)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text('販売 ¥${NumberFormat('#,###').format(p.defaultUnitPrice)}',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                              if (p.wholesalePrice > 0) ...[
                                const SizedBox(width: 8),
                                Text('仕入 ¥${NumberFormat('#,###').format(p.wholesalePrice)}',
                                    style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                              ],
                              const Spacer(),
                              if (!p.isNonStockCategory)
                                Text('在庫: ${p.stockQuantity?.toString() ?? '管理なし'}',
                                    style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    onTap: () {
                      if (_selectMode) {
                        setState(() { if (_selectedIds.contains(p.id)) _selectedIds.remove(p.id); else _selectedIds.add(p.id); });
                      } else if (widget.selectionMode) {
                        if (p.isHidden) return;
                        Navigator.pop(context, p);
                      } else {
                        _showDetailPane(p);
                      }
                    },
                    onLongPress: () {
                      if (!_selectMode && !widget.selectionMode) {
                        setState(() { _selectMode = true; _selectedIds.add(p.id); });
                      }
                    },
                    trailing: widget.selectionMode
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showEditDialog(product: p),
                            tooltip: "編集（電子帳簿保存法対応：ロック中も履歴保存して編集可能）",
                          ),
                    ),
                  );
                },
              ),
      ),
floatingActionButton: FloatingActionButton(
         onPressed: () => _showEditDialog(),
         backgroundColor: Theme.of(context).colorScheme.primary,
         foregroundColor: theme.cardColor,
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
                     color: p.isLocked ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
                   ),
                   const SizedBox(width: 8),
                   Expanded(
                     child: Text(
                       p.name,
                       style: TextStyle(
                         fontWeight: FontWeight.bold,
                         fontSize: 18,
                         color: p.isLocked ? Theme.of(context).colorScheme.onSurfaceVariant : null,
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
                      if (!p.isNonStockCategory)
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
                    icon: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    label: Text(
                      "削除",
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
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
                               child: Text(
                                 "削除",
                                 style: TextStyle(color: Theme.of(context).colorScheme.error),
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
                      icon: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      label: Text(
                        "削除",
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
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
                               child: Text(
                                 "削除",
                                 style: TextStyle(color: Theme.of(context).colorScheme.error),
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
