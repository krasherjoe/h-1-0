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

enum _LineTag { name, modelNumber, price, skip }

class _LineEntry {
  _LineEntry(this.text, this.tag);
  final String text;
  _LineTag tag;
}

class _PasteBufferScreen extends StatefulWidget {
  const _PasteBufferScreen();
  @override
  State<_PasteBufferScreen> createState() => _PasteBufferScreenState();
}

class _PasteBufferScreenState extends State<_PasteBufferScreen> {
  final _textController = TextEditingController();
  List<_LineEntry> _lines = [];

  static const _tagLabels = {
    _LineTag.name: '品名',
    _LineTag.modelNumber: '型番',
    _LineTag.price: '単価',
    _LineTag.skip: '無視',
  };

  static const _tagColors = {
    _LineTag.name: Color(0xFF42A5F5),
    _LineTag.modelNumber: Color(0xFFAB47BC),
    _LineTag.price: Color(0xFFEF5350),
    _LineTag.skip: Color(0xFF9E9E9E),
  };

  static const _tagOrder = [_LineTag.name, _LineTag.modelNumber, _LineTag.price, _LineTag.skip];

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
      _lines = raw.map((l) {
        final tag = _parsePrice(l) != null ? _LineTag.price : _LineTag.name;
        return _LineEntry(l, tag);
      }).toList();
    });
  }

  void _cycleTag(int index) {
    setState(() {
      final current = _lines[index].tag;
      final next = _tagOrder[(_tagOrder.indexOf(current) + 1) % _tagOrder.length];
      _lines[index].tag = next;
    });
  }

  List<ParsedLineItem> _buildItems() {
    final result = <ParsedLineItem>[];
    String? currentName;
    for (final entry in _lines) {
      if (entry.tag == _LineTag.skip) continue;
      if (entry.tag == _LineTag.price) {
        final price = int.tryParse(entry.text.replaceAll(RegExp(r'[￥¥,,\s円]'), '')) ?? 0;
        result.add(ParsedLineItem(currentName ?? '商品', price));
        currentName = null;
      } else if (entry.tag == _LineTag.name) {
        if (currentName != null) result.add(ParsedLineItem(currentName, 0));
        currentName = entry.text;
      } else if (entry.tag == _LineTag.modelNumber) {
        if (currentName != null) {
          currentName = '$currentName (${entry.text})';
        } else {
          currentName = entry.text;
        }
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
      body: _lines.isEmpty ? _buildPasteArea(cs) : _buildTaggingArea(cs, items),
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

  Widget _buildTaggingArea(ColorScheme cs, List<ParsedLineItem>? items) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Text('各行をタップして種別を選んでください', style: TextStyle(fontSize: 12)),
              const Spacer(),
              TextButton.icon(onPressed: () => setState(() => _lines = []), icon: const Icon(Icons.refresh, size: 18), label: const Text('戻る')),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _lines.length,
            separatorBuilder: (i, j) => const Divider(height: 4),
            itemBuilder: (context, index) {
              final entry = _lines[index];
              final color = _tagColors[entry.tag]!;
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _cycleTag(index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                          child: Text(_tagLabels[entry.tag]!, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(entry.text, style: const TextStyle(fontSize: 13))),
                        Icon(Icons.touch_app, size: 16, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (items != null && items.isNotEmpty) ...[
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.all(16),
            color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('プレビュー (${items.length}件)', style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface)),
                const SizedBox(height: 8),
                ...items.take(5).map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('${item.name}: ¥${item.price}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
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
