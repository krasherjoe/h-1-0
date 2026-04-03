import 'package:flutter/material.dart';
import 'empty_state_widget.dart';

/// 汎用リスト画面
/// あらゆるリスト表示に対応する汎用テンプレート
class GenericListScreen<T> extends StatefulWidget {
  final String screenId;
  final String title;
  final IconData icon;
  final Color? themeColor;

  // データ取得
  final Future<List<T>> Function() fetchData;

  // カード表示
  final Widget Function(BuildContext context, T item, VoidCallback onRefresh) buildCard;

  // フィルタ
  final List<FilterOption<T>>? filters;

  // アクション
  final Future<void> Function()? onCreateNew;

  // 空状態
  final Widget? emptyWidget;

  const GenericListScreen({
    super.key,
    required this.screenId,
    required this.title,
    required this.icon,
    required this.fetchData,
    required this.buildCard,
    this.themeColor,
    this.filters,
    this.onCreateNew,
    this.emptyWidget,
  });

  @override
  State<GenericListScreen<T>> createState() => _GenericListScreenState<T>();
}

class _GenericListScreenState<T> extends State<GenericListScreen<T>> {
  List<T> _allItems = [];
  List<T> _filteredItems = [];
  bool _isLoading = true;
  String _currentFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final items = await widget.fetchData();
      if (!mounted) return;
      setState(() {
        _allItems = items;
        _applyFilter(_currentFilter);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('データの読み込みに失敗しました: $e')),
      );
    }
  }

  void _applyFilter(String filterValue) {
    setState(() {
      _currentFilter = filterValue;
      if (widget.filters == null) {
        _filteredItems = _allItems;
        return;
      }

      final filter = widget.filters!.firstWhere(
        (f) => f.value == filterValue,
        orElse: () => widget.filters!.first,
      );

      _filteredItems = filter.filter(_allItems);
    });
  }

  Future<void> _handleCreateNew() async {
    if (widget.onCreateNew == null) return;
    await widget.onCreateNew!();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text('${widget.screenId}:${widget.title}'),
        actions: [
          if (widget.filters != null && widget.filters!.length > 1)
            PopupMenuButton<String>(
              icon: const Icon(Icons.filter_list),
              onSelected: _applyFilter,
              itemBuilder: (context) => widget.filters!
                  .map((filter) => PopupMenuItem(
                        value: filter.value,
                        child: Row(
                          children: [
                            if (_currentFilter == filter.value)
                              const Icon(Icons.check, size: 20)
                            else
                              const SizedBox(width: 20),
                            const SizedBox(width: 8),
                            Text(filter.label),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: '更新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredItems.isEmpty
              ? widget.emptyWidget ??
                  EmptyStateWidget(
                    icon: widget.icon,
                    title: 'データがありません',
                    actionLabel: widget.onCreateNew != null ? '新規作成' : null,
                    onAction: widget.onCreateNew != null ? _handleCreateNew : null,
                  )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      return widget.buildCard(
                        context,
                        _filteredItems[index],
                        _loadData,
                      );
                    },
                  ),
                ),
      floatingActionButton: widget.onCreateNew != null
          ? FloatingActionButton.extended(
              onPressed: _handleCreateNew,
              icon: const Icon(Icons.add),
              label: const Text('新規作成'),
              backgroundColor: widget.themeColor,
            )
          : null,
    );
  }
}

/// フィルタオプション
class FilterOption<T> {
  final String label;
  final String value;
  final List<T> Function(List<T>) filter;

  const FilterOption({
    required this.label,
    required this.value,
    required this.filter,
  });
}
