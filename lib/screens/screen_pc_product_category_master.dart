import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/product_category_model.dart';
import '../services/product_category_repository.dart';
import '../widgets/master_field_config.dart';
import '../widgets/rich_master_edit_sheet.dart';

/// PC: 商品カテゴリーマスター
/// 商品カテゴリーの新規登録・編集・論理削除・復元を行う専用画面。
class ProductCategoryMasterScreen extends StatefulWidget {
  final bool selectionMode;
  final bool showInactive;

  const ProductCategoryMasterScreen({
    super.key,
    this.selectionMode = false,
    this.showInactive = false,
  });

  @override
  State<ProductCategoryMasterScreen> createState() =>
      _ProductCategoryMasterScreenState();
}

class CategoryPreviewCard extends StatelessWidget {
  const CategoryPreviewCard({
    super.key,
    required this.name,
    required this.description,
  });

  final String name;
  final String description;

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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.category, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    name.isEmpty ? 'カテゴリー名未入力' : name,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('説明', style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(description, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProductCategoryMasterScreenState
    extends State<ProductCategoryMasterScreen> {
  final ProductCategoryRepository _repo = ProductCategoryRepository();
  final TextEditingController _searchController = TextEditingController();

  List<ProductCategory> _all = [];
  List<ProductCategory> _filtered = [];
  bool _isLoading = true;
  bool _showInactive = false;

  @override
  void initState() {
    super.initState();
    _showInactive = widget.showInactive;
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _repo.getAllCategories(includeInactive: true);
    if (!mounted) return;
    setState(() {
      _all = data;
      _isLoading = false;
      _applyFilter();
    });
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _all.where((c) {
        final matchesQuery = c.name.toLowerCase().contains(query) ||
            (c.description?.toLowerCase().contains(query) ?? false);
        final matchesActive = _showInactive ? true : c.isActive;
        return matchesQuery && matchesActive;
      }).toList();
    });
  }

  Future<void> _showEditDialog({ProductCategory? category}) async {
    final result = await showRichMasterEditSheet<ProductCategory>(
      context: context,
      titleNew: 'カテゴリーを新規登録',
      titleEdit: 'カテゴリーを編集',
      existing: category,
      sections: [
        RichMasterSection(
          title: '基本情報',
          description: 'カテゴリー名を入力します（例: 飲料、文具）',
          fields: const [
            MasterFieldConfig(
              key: 'name',
              label: 'カテゴリー名',
              hint: '例: 飲料',
              required: true,
              flex: 2,
            ),
          ],
        ),
        RichMasterSection(
          title: '説明',
          description: 'カテゴリーの用途や範囲をメモできます',
          fields: const [
            MasterFieldConfig(
              key: 'description',
              label: '説明 / 備考',
              maxLines: 4,
              flex: 2,
            ),
          ],
        ),
      ],
      initialValuesBuilder: (c) => {
        'name': c?.name ?? '',
        'description': c?.description ?? '',
      },
      previewBuilder: (ctx, controller) => CategoryPreviewCard(
        name: controller.valueOf('name'),
        description: controller.valueOf('description'),
      ),
      buildModel: (values) => ProductCategory(
        id: category?.id ?? const Uuid().v4(),
        name: values['name']?.trim() ?? '',
        description: values['description']?.trim().isEmpty ?? true
            ? null
            : values['description']!.trim(),
        isActive: category?.isActive ?? true,
        createdAt: category?.createdAt,
      ),
    );

    if (result != null && mounted) {
      await _repo.saveCategory(result);
      if (widget.selectionMode && mounted) {
        Navigator.pop(context, result);
      } else {
        _loadData();
      }
    }
  }

  Future<void> _toggleActive(ProductCategory c) async {
    if (c.isActive) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('カテゴリーを非表示にしますか？'),
          content: Text('「${c.name}」を論理削除（非表示）します。\n'
              '既存の商品に紐づいていても、商品データは削除されません。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
              child: const Text('非表示にする'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      await _repo.deleteCategory(c.id);
    } else {
      await _repo.restoreCategory(c.id);
    }
    if (!mounted) return;
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('PC:商品カテゴリーマスター'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            tooltip: _showInactive ? '有効のみ表示' : '非表示も表示',
            icon: Icon(_showInactive ? Icons.visibility : Icons.visibility_off),
            onPressed: () {
              setState(() {
                _showInactive = !_showInactive;
                _applyFilter();
              });
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'カテゴリー名・説明で検索',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (_) => _applyFilter(),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filtered.isEmpty
              ? const Center(child: Text('カテゴリーが見つかりません'))
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 80, top: 8),
                  itemCount: _filtered.length,
                  itemBuilder: (context, index) {
                    final c = _filtered[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: c.isActive
                            ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5)
                            : Theme.of(context).colorScheme.outlineVariant,
                        child: Icon(
                          Icons.category,
                          color: c.isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      title: Text(
                        c.name + (c.isActive ? '' : ' (非表示)'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: c.isActive ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      subtitle: c.description != null &&
                              c.description!.isNotEmpty
                          ? Text(c.description!)
                          : null,
                      onTap: () {
                        if (widget.selectionMode) {
                          if (!c.isActive) return;
                          Navigator.pop(context, c);
                        } else {
                          _showEditDialog(category: c);
                        }
                      },
                      trailing: widget.selectionMode
                          ? null
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    c.isActive
                                        ? Icons.visibility_off
                                        : Icons.restore,
color: c.isActive
                                         ? Theme.of(context).colorScheme.error
                                         : Theme.of(context).colorScheme.primary,
                                  ),
                                  tooltip: c.isActive ? '非表示にする' : '復元',
                                  onPressed: () => _toggleActive(c),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () =>
                                      _showEditDialog(category: c),
                                ),
                              ],
                            ),
                    );
                  },
                ),
      floatingActionButton: widget.selectionMode
          ? null
          : FloatingActionButton(
              onPressed: () => _showEditDialog(),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              child: const Icon(Icons.add),
            ),
    );
  }
}
