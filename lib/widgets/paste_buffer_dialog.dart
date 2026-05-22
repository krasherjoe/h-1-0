import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  final _currencyFormat = NumberFormat.currency(locale: 'ja_JP', symbol: '¥');
  List<ParsedLineItem> _parsed = [];
  bool _showPreview = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _parse() {
    final text = _textController.text;
    if (text.trim().isEmpty) return;
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final parsed = <ParsedLineItem>[];
    String? currentName;
    for (final line in lines) {
      final price = _parsePrice(line);
      if (price != null && currentName != null) {
        parsed.add(ParsedLineItem(currentName, price));
        currentName = null;
      } else if (price != null) {
        parsed.add(ParsedLineItem('商品', price));
      } else {
        if (currentName != null) parsed.add(ParsedLineItem(currentName, 0));
        currentName = line.replaceAll(RegExp(r'^[・\-•]+\s*'), '');
      }
    }
    if (currentName != null) parsed.add(ParsedLineItem(currentName, 0));
    setState(() {
      _parsed = parsed;
      _showPreview = true;
    });
  }

  void _confirm() {
    Navigator.pop(context, _parsed.where((p) => p.price > 0 || p.name.isNotEmpty).toList());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('PB:テキスト貼付'),
        actions: [
          if (_showPreview)
            TextButton.icon(
              onPressed: _confirm,
              icon: const Icon(Icons.check),
              label: const Text('明細に追加'),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: _showPreview ? 1 : 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Amazon/楽天などからコピーしたテキストを貼り付けてください', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _textController,
                    maxLines: 6,
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
                    label: const Text('解析してプレビュー'),
                  ),
                ],
              ),
            ),
          ),
          if (_showPreview) ...[
            Divider(height: 1, color: cs.outlineVariant),
            Expanded(
              flex: 2,
              child: _parsed.isEmpty
                  ? Center(
                      child: Text('商品名または金額を認識できませんでした', style: TextStyle(color: cs.onSurfaceVariant)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _parsed.length,
                      separatorBuilder: (i, j) => const Divider(height: 8),
                      itemBuilder: (context, index) {
                        final item = _parsed[index];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: TextEditingController(text: item.name),
                                    decoration: const InputDecoration(labelText: '品名', isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                                    onChanged: (v) => item.name = v,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: TextEditingController(text: item.price.toString()),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: '単価', isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                                    onChanged: (v) => item.price = int.tryParse(v.replaceAll(RegExp(r'[￥¥,]'), '')) ?? 0,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(_currencyFormat.format(item.price), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
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
