import 'package:flutter/material.dart';
import '../services/app_settings_repository.dart';
import '../models/dashboard_menu_item.dart';
import '../widgets/menu_category_header.dart';

class DashboardMenuSettingsScreen extends StatefulWidget {
  const DashboardMenuSettingsScreen({super.key});

  @override
  State<DashboardMenuSettingsScreen> createState() => _DashboardMenuSettingsScreenState();
}

class _DashboardMenuSettingsScreenState extends State<DashboardMenuSettingsScreen> {
  final _repo = AppSettingsRepository();
  List<DashboardMenuItem> _items = [];
  bool _loading = true;
  bool _showCategoryDescriptions = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _repo.getDashboardMenu();
    final showCategoryDesc = await _repo.getDashboardShowCategoryDescriptions();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
      _showCategoryDescriptions = showCategoryDesc;
    });
  }

  Future<void> _save() async {
    await _repo.setDashboardMenu(_items);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ダッシュボードメニューを保存しました')));
  }

  Future<void> _reset() async {
    await _repo.resetDashboardMenu();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('デフォルトメニューに戻しました')));
  }

  void _toggle(int index, bool enabled) {
    setState(() {
      _items[index] = _items[index].copyWith(enabled: enabled);
    });
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      appBar: AppBar(
        title: const Text('D2:ダッシュボード設定'),
        actions: [
          IconButton(onPressed: _loading ? null : _reset, icon: const Icon(Icons.restore)),
          IconButton(onPressed: _loading ? null : _save, icon: const Icon(Icons.save)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ドラッグして並べ替え、スイッチで表示/非表示を切り替えます。\nDEBUGビルドでは常に全項目が表示されます。',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('カテゴリ説明を表示'),
                            subtitle: const Text('ダッシュボードと設定画面双方の説明文を連動'),
                            value: _showCategoryDescriptions,
                            onChanged: (value) async {
                              await _repo.setDashboardShowCategoryDescriptions(value);
                              setState(() => _showCategoryDescriptions = value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverReorderableList(
                    itemCount: _items.length,
                    onReorder: _reorder,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final showHeader = index == 0 || _items[index - 1].category != item.category;
                      return Padding(
                        key: ValueKey(item.id),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showHeader) MenuCategoryDivider(title: item.category),
                            Card(
                              child: SwitchListTile(
                                value: item.enabled,
                                onChanged: (value) => _toggle(index, value),
                                title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: _subtitle(item),
                                secondary: CircleAvatar(child: Text(item.id.toUpperCase())),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
    );
  }

  Widget _subtitle(DashboardMenuItem item) {
    if (!_showCategoryDescriptions || (item.description?.isEmpty ?? true)) {
      return Text('${item.category} • ${item.route}');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${item.category} • ${item.route}'),
        const SizedBox(height: 4),
        Text(
          item.description!,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 12),
        ),
      ],
    );
  }

}
