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
  bool _clipboardLoaded = false;
  List<String> _lines = [];
  final Set<int> _selected = {};

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

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

  void _parse() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      _selected.clear();
      for (var i = 0; i < _lines.length; i++) {
        if (_parsePrice(_lines[i]) != null) _selected.add(i);
      }
    });
  }

  void _toggle(int index) {
    setState(() {
      if (_selected.contains(index)) _selected.remove(index);
      else _selected.add(index);
    });
  }

  List<ParsedLineItem> _buildItems() {
    final sorted = _selected.toList()..sort();
    final result = <ParsedLineItem>[];
    String? name;
    for (final i in sorted) {
      final line = _lines[i];
      final price = _parsePrice(line);
      if (price != null) {
        result.add(ParsedLineItem(name ?? '商品', price));
        name = null;
      } else {
        if (name != null) result.add(ParsedLineItem(name, 0));
        name = line;
      }
    }
    if (name != null) result.add(ParsedLineItem(name, 0));
    return result.where((p) => p.price > 0 || p.name.isNotEmpty).toList();
  }

  void _confirm() {
    Navigator.pop(context, _buildItems());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = _buildItems();
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('PB:貼付取込'),
        actions: [
          if (_lines.isNotEmpty)
            TextButton.icon(
              onPressed: _confirm,
              icon: const Icon(Icons.check),
              label: Text('${items.length}件取込'),
            ),
        ],
      ),
      body: _lines.isEmpty ? _buildInputArea(cs) : _buildSelectArea(cs, items),
    );
  }

  Widget _buildInputArea(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(_clipboardLoaded ? 'クリップボードから自動取込' : 'コピーして開くか、直接入力',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: 'パソコン\tPC-9801\t458000\nモニタ\tKD845\t118000',
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
          FilledButton.icon(onPressed: _parse, icon: const Icon(Icons.transform), label: const Text('解析')),
        ],
      ),
    );
  }

  Widget _buildSelectArea(ColorScheme cs, List<ParsedLineItem> items) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Text('${_lines.length}行  ${_selected.length}行選択 → ${items.length}件', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              const Spacer(),
              TextButton.icon(onPressed: () => setState(() { _lines = []; }), icon: const Icon(Icons.refresh, size: 18), label: const Text('戻る')),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _lines.length,
            itemBuilder: (_, i) {
              final line = _lines[i];
              final checked = _selected.contains(i);
              final isPrice = _parsePrice(line) != null;
              return Card(
                child: InkWell(
                  onTap: () => _toggle(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Row(
                      children: [
                        Checkbox(value: checked, onChanged: (_) => _toggle(i)),
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
        if (items.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              border: Border(top: BorderSide(color: cs.outlineVariant)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('取込プレビュー', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: cs.onSurface)),
                const SizedBox(height: 6),
                ...items.take(5).map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: [
                      Expanded(child: Text(item.name, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text('¥${item.price}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.onSurface)),
                    ],
                  ),
                )),
                if (items.length > 5) Text('...他 ${items.length - 5}件', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
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
