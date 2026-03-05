import 'package:flutter/material.dart';
import '../services/app_settings_repository.dart';

class DashboardMenuSettingsScreen extends StatefulWidget {
  const DashboardMenuSettingsScreen({super.key});

  @override
  State<DashboardMenuSettingsScreen> createState() => _DashboardMenuSettingsScreenState();
}

class _DashboardMenuSettingsScreenState extends State<DashboardMenuSettingsScreen> {
  final _repo = AppSettingsRepository();
  List<DashboardMenuItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _repo.getDashboardMenu();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
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
                      child: Text(
                        'ドラッグして並べ替え、スイッチで表示/非表示を切り替えます。\nDEBUGビルドでは常に全項目が表示されます。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  SliverReorderableList(
                    itemCount: _items.length,
                    onReorder: _reorder,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Padding(
                        key: ValueKey(item.id),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Card(
                          child: SwitchListTile(
                            value: item.enabled,
                            onChanged: (value) => _toggle(index, value),
                            title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(item.route),
                            secondary: CircleAvatar(child: Text(item.id.toUpperCase())),
                          ),
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
}
