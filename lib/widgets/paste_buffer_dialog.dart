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

class _Record {
  _Record({this.manufacturer, this.modelName = '', this.price = 0});
  String? manufacturer;
  String modelName;
  int price;
}

class _PasteBufferScreen extends StatefulWidget {
  const _PasteBufferScreen();
  @override
  State<_PasteBufferScreen> createState() => _PasteBufferScreenState();
}

class _PasteBufferScreenState extends State<_PasteBufferScreen> {
  final _textController = TextEditingController();
  final _previewScroll = ScrollController();
  List<String> _lines = [];
  final Set<int> _selected = {};
  final List<_Record> _records = [];
  bool _clipboardLoaded = false;

  @override
  void dispose() {
    _textController.dispose();
    _previewScroll.dispose();
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
    final text = _textController.text;
    if (text.trim().isEmpty) return;
    setState(() {
      _lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      _selected.clear();
      _records.clear();
    });
  }

  void _toggle(int index) {
    setState(() {
      if (_selected.contains(index)) {
        _selected.remove(index);
      } else {
        _selected.add(index);
      }
    });
  }

  void _buildRecords() {
    final sorted = _selected.toList()..sort();
    final records = <_Record>[];
    _Record? current;
    for (final idx in sorted) {
      final line = _lines[idx];
      final isPrice = _parsePrice(line) != null;
      if (isPrice) {
        if (current != null) {
          current.price = _parsePrice(line)!;
          records.add(current);
        } else {
          records.add(_Record(price: _parsePrice(line)!));
        }
        current = null;
      } else {
        if (current == null) {
          current = _Record(modelName: line);
        } else if (current.manufacturer.isEmpty) {
          current.manufacturer = current.modelName;
          current.modelName = line;
        } else {
          current.modelName = line;
        }
      }
    }
    if (current != null) records.add(current);
    setState(() => _records.addAll(records));
    _selected.clear();
  }

  void _removeRecord(int index) {
    setState(() => _records.removeAt(index));
  }

  List<ParsedLineItem> _toLineItems() {
    return _records.map((r) {
      final parts = <String>[];
      if (r.manufacturer != null && r.manufacturer!.isNotEmpty) parts.add(r.manufacturer!);
      parts.add(r.modelName);
      final name = parts.join(' ');
      return ParsedLineItem(name.trim(), r.price);
    }).where((p) => p.name.isNotEmpty || p.price > 0).toList();
  }

  void _confirm() {
    Navigator.pop(context, _toLineItems());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = _toLineItems();
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('PB:テキスト貼付'),
        actions: [
          if (_lines.isNotEmpty)
            TextButton.icon(
              onPressed: _records.isNotEmpty ? _confirm : _buildRecords,
              icon: Icon(_records.isNotEmpty ? Icons.check : Icons.arrow_forward),
              label: Text(_records.isNotEmpty ? '取り込む (${items.length})' : '組立'),
            ),
        ],
      ),
      body: _lines.isEmpty ? _buildPasteArea(cs) : _buildMainArea(cs, items),
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
              Text(_clipboardLoaded ? 'クリップボードから自動取込しました' : 'テキストを入力、またはコピーしてから開いてください',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: 'パソコン PC-9801 458000\nモニタ KD845 118000\nUSB-Cケーブル 1,280',
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

  Widget _buildMainArea(ColorScheme cs, List<ParsedLineItem> items) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Text('行をタップして選択 →「組立」でレコード化', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              const Spacer(),
              TextButton.icon(onPressed: () => setState(() { _lines = []; _records.clear(); }), icon: const Icon(Icons.refresh, size: 18), label: const Text('戻る')),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          flex: 3,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _lines.length,
            itemBuilder: (context, index) {
              final line = _lines[index];
              final checked = _selected.contains(index);
              final isPrice = _parsePrice(line) != null;
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _toggle(index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Row(
                      children: [
                        Checkbox(value: checked, onChanged: (_) => _toggle(index)),
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
        const Divider(height: 1),
        Expanded(
          flex: 2,
          child: _records.isEmpty
              ? Center(
                  child: Text('選択した行を「組立」するとここにレコードが並びます',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _records.length,
                  itemBuilder: (context, index) {
                    final r = _records[index];
                    return Card(
                      color: cs.primaryContainer.withValues(alpha: 0.3),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (r.manufacturer != null && r.manufacturer!.isNotEmpty)
                                    Text('メーカー: ${r.manufacturer}', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                                  Text(r.modelName.isNotEmpty ? r.modelName : '(名称未設定)',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text('¥${r.price}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.error)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, size: 16, color: cs.error),
                              onPressed: () => _removeRecord(index),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
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
