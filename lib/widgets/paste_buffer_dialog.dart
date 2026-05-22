import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final _previewScroll = ScrollController();
  List<String> _lines = [];
  bool _clipboardLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_clipboardLoaded) {
      _clipboardLoaded = true;
      _loadClipboard();
    }
  }

  Future<void> _loadClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      if (!mounted) return;
      _textController.text = data.text!;
      _parse();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _previewScroll.dispose();
    super.dispose();
  }

  void _parse() {
    final text = _textController.text;
    if (text.trim().isEmpty) return;
    final raw = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    setState(() {
      _lines = raw;
      _selected.clear();
      var count = 0;
      for (final l in raw) {
        if (_parsePrice(l) != null && count < 2) {
          _selected[l] = true;
          count++;
        }
      }
    });
  }

  void _toggle(String line) {
    setState(() {
      if (_selected.containsKey(line)) _selected.remove(line);
      else _selected[line] = true;
    });
  }

  void _remove(String line) {
    setState(() {
      _selected.remove(line);
      _lines.remove(line);
    });
  }

  void _split(String line) {
    final parts = line.split(RegExp(r'[\s\t,、]')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (parts.length <= 1) return;
    final idx = _lines.indexOf(line);
    if (idx < 0) return;
    setState(() {
      _selected.remove(line);
      _lines.removeAt(idx);
      for (final part in parts.reversed) {
        _lines.insert(idx, part);
        if (_parsePrice(part) != null) _selected[part] = true;
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

  void _showMenu(String line) {
    final canSplit = line.split(RegExp(r'[\s\t,、]')).length > 1;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(line, maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (canSplit)
              ListTile(
                leading: const Icon(Icons.call_split),
                title: const Text('スペースやカンマで分割'),
                onTap: () { Navigator.pop(ctx); _split(line); },
              ),
            ListTile(
              leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              title: Text('削除', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () { Navigator.pop(ctx); _remove(line); },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = _lines.isEmpty ? null : _buildItems();
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('PB:テキスト貼付'),
      ),
      body: _lines.isEmpty ? _buildPasteArea(cs) : _buildSelectArea(cs, items),
      bottomNavigationBar: items != null && items.isNotEmpty
          ? _buildPreviewBar(cs, items)
          : null,
    );
  }

  Widget _buildPasteArea(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(_clipboardLoaded ? 'クリップボードから自動取込しました' : 'テキストを入力するか、コピーしてから開いてください',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: '商品名\n￥1,280\n\n商品名2\n¥2,500',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.2),
              suffixIcon: IconButton(
                icon: const Icon(Icons.content_paste),
                tooltip: 'クリップボードから読込',
                onPressed: _loadClipboard,
              ),
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text('タップ:選択/解除  長押し:分割・削除', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              const Spacer(),
              TextButton.icon(onPressed: () => setState(() => _lines = []), icon: const Icon(Icons.refresh, size: 18), label: const Text('やり直し')),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8),
            itemCount: _lines.length,
            itemBuilder: (context, index) {
              final line = _lines[index];
              final isPrice = _parsePrice(line) != null;
              final checked = _selected.containsKey(line);
              return Card(
                child: GestureDetector(
                  onLongPressStart: (_) => _showMenu(line),
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
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewBar(ColorScheme cs, List<ParsedLineItem> items) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottomPad > 0 ? bottomPad : 8),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.3),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                Icon(Icons.shopping_cart_checkout, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Text('${_selected.length}行 → ${items.length}件', style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface, fontSize: 13)),
                const Spacer(),
                Text('¥${items.fold<int>(0, (s, i) => s + i.price)}', style: TextStyle(fontWeight: FontWeight.bold, color: cs.error, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: ListView(
              controller: _previewScroll,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      children: [
                        Expanded(child: Text(item.name, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        Text('¥${item.price}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.onSurface)),
                      ],
                    ),
                  )).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _confirm,
                icon: const Icon(Icons.download),
                label: Text('${items.length}件を取り込む'),
              ),
            ),
          ),
        ],
      ),
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
