import 'package:flutter/material.dart';

class ParsedLineItem {
  ParsedLineItem(this.name, this.price);
  String name;
  int price;
}

Future<List<ParsedLineItem>> showPasteBufferScreen(BuildContext context) async {
  final result = await Navigator.push<List<ParsedLineItem>>(
    context,
    MaterialPageRoute(builder: (_) => const _PasteBufferScreen()),
  );
  return result ?? [];
}

class _PasteBufferScreen extends StatefulWidget {
  const _PasteBufferScreen();
  @override
  State<_PasteBufferScreen> createState() => _PasteBufferScreenState();
}

class _PasteBufferScreenState extends State<_PasteBufferScreen> {
  final _textController = TextEditingController();
  final _selected = <String, bool>{};
  List<String> _lines = [];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _parse() {
    final text = _textController.text;
    if (text.trim().isEmpty) return;
    final raw = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    setState(() {
      _lines = raw;
      _selected.clear();
      for (final l in raw) {
        if (_parsePrice(l) != null) _selected[l] = true;
      }
    });
  }

  void _toggle(String line) {
    setState(() {
      if (_selected.containsKey(line)) {
        _selected.remove(line);
      } else {
        _selected[line] = true;
      }
    });
  }

  List<ParsedLineItem> _buildItems() {
    final result = <ParsedLineItem>[];
    String? currentName;
    for (final line in _lines) {
      if (!_selected.containsKey(line)) continue;
      final price = _parsePrice(line);
      if (price != null) {
        result.add(ParsedLineItem(currentName ?? '商品', price));
        currentName = null;
      } else {
        if (currentName != null) result.add(ParsedLineItem(currentName, 0));
        currentName = line;
      }
    }
    if (currentName != null) result.add(ParsedLineItem(currentName, 0));
    return result.where((p) => p.price > 0 || p.name.isNotEmpty).toList();
  }

  void _confirm() {
    Navigator.pop(context, _buildItems());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = _lines.isEmpty ? null : _buildItems();
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('PB:テキスト貼付'),
        actions: [
          if (_lines.isNotEmpty)
            TextButton.icon(
              onPressed: _confirm,
              icon: const Icon(Icons.check),
              label: Text('明細に追加 (${items?.length ?? 0})'),
            ),
        ],
      ),
      body: _lines.isEmpty ? _buildPasteArea(cs) : _buildSelectArea(cs, items),
    );
  }

  Widget _buildPasteArea(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Amazon/楽天などからコピーしたテキストを貼り付けてください', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: '商品名\n￥1,280\n\n商品名2\n¥2,500',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _parse,
            icon: const Icon(Icons.transform),
            label: const Text('解析'),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectArea(ColorScheme cs, List<ParsedLineItem>? items) {
    final selectedCount = _selected.length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text('行をタップして選択 (${_selected.length}行)', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              const Spacer(),
              TextButton.icon(onPressed: () => setState(() => _lines = []), icon: const Icon(Icons.refresh, size: 18), label: const Text('戻る')),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _lines.length,
            itemBuilder: (context, index) {
              final line = _lines[index];
              final isPrice = _parsePrice(line) != null;
              final checked = _selected.containsKey(line);
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _toggle(line),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Row(
                      children: [
                        Checkbox(value: checked, onChanged: (_) => _toggle(line)),
                        Icon(isPrice ? Icons.monetization_on : Icons.article_outlined, size: 16, color: isPrice ? cs.error : cs.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(line, style: TextStyle(fontSize: 13, decoration: checked ? null : TextDecoration.lineThrough))),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (items != null && items.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.3),
              border: Border(top: BorderSide(color: cs.outlineVariant)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shopping_cart_checkout, size: 16, color: cs.primary),
                    const SizedBox(width: 6),
                    Text('明細プレビュー ($selectedCount行 → ${items.length}件)', style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface)),
                  ],
                ),
                const SizedBox(height: 8),
                ...items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text(item.name, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
                          Text('¥${item.price}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.onSurface)),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

int? _parsePrice(String text) {
  final cleaned = text.replaceAll(RegExp(r'[￥¥,,\s]'), '').replaceAll('円', '').trim();
  final match = RegExp(r'^(\d+)$').firstMatch(cleaned);
  if (match != null) {
    final v = int.parse(match.group(1)!);
    if (v > 0 && v < 100000000) return v;
  }
  return null;
}
