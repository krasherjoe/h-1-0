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

  List<List<String>> _rows = [];
  int _columnCount = 3;
  final List<String> _columnLabels = ['品名', '型番', '金額'];

  static const _presetLabels = [
    ['品名', '型番', '金額'],
    ['品名', '金額'],
    ['メーカー', '品名', '型番', '金額'],
    ['品名', '金額', '数量'],
  ];

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
    final raw = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (raw.isEmpty) return;
    final firstLine = raw.first;
    final separators = <String>[];
    for (final s in ['\t', '  ', ' , ', ',', ' ']) {
      if (firstLine.contains(s)) { separators.add(s); break; }
    }
    final sep = separators.isNotEmpty ? RegExp(separators.first) : RegExp(r'\s+');
    final guessedCols = firstLine.split(sep).length;
    setState(() {
      _columnCount = guessedCols.clamp(2, 6);
      while (_columnLabels.length < _columnCount) _columnLabels.add('項目${_columnLabels.length + 1}');
      while (_columnLabels.length > _columnCount) _columnLabels.removeLast();
      _rows = raw.map((l) {
        var cells = l.split(sep).map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
        while (cells.length < _columnCount) cells.add('');
        cells = cells.sublist(0, _columnCount);
        return cells;
      }).toList();
    });
  }

  void _updateCell(int row, int col, String value) {
    setState(() => _rows[row][col] = value);
  }

  void _removeRow(int index) {
    setState(() => _rows.removeAt(index));
  }

  void _applyPreset(List<String> labels) {
    setState(() {
      _columnCount = labels.length;
      _columnLabels.clear();
      _columnLabels.addAll(labels);
      _rows = _rows.map((r) {
        var cells = List<String>.from(r);
        while (cells.length < _columnCount) cells.add('');
        cells = cells.sublist(0, _columnCount);
        return cells;
      }).toList();
    });
  }

  List<ParsedLineItem> _toLineItems() {
    final priceCol = _columnLabels.indexWhere((l) => l.contains('金額') || l.contains('単価') || l.contains('価格'));
    final nameCol = _columnLabels.indexWhere((l) => l.contains('品名'));
    final modelCol = _columnLabels.indexWhere((l) => l.contains('型番'));
    return _rows.map((r) {
      final price = priceCol >= 0 ? int.tryParse(r[priceCol].replaceAll(RegExp(r'[￥¥,,\s円]'), '')) ?? 0 : 0;
      final parts = <String>[];
      if (nameCol >= 0 && r[nameCol].isNotEmpty) parts.add(r[nameCol]);
      if (modelCol >= 0 && r[modelCol].isNotEmpty) parts.add('(${r[modelCol]})');
      return ParsedLineItem(parts.join(' '), price);
    }).toList();
  }

  void _confirm() {
    Navigator.pop(context, _toLineItems());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('PB:テキスト貼付'),
        actions: [
          if (_rows.isNotEmpty)
            TextButton.icon(
              onPressed: _confirm,
              icon: const Icon(Icons.check),
              label: Text('取り込む (${_rows.length}行)'),
            ),
        ],
      ),
      body: _rows.isEmpty ? _buildInputArea(cs) : _buildTableArea(cs),
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
              Text(_clipboardLoaded ? 'クリップボードから自動取込しました' : 'テキストを入力、またはコピーしてから開いてください',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: '品名\t型番\t金額\nパソコン\tPC-9801\t458000\nモニタ\tKD845\t118000',
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

  Widget _buildTableArea(ColorScheme cs) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Text('${_rows.length}行 × $_columnCountカラム', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              const Spacer(),
              DropdownButton<String>(
                value: 'プリセット',
                underline: const SizedBox(),
                items: [
                  const DropdownMenuItem(value: 'プリセット', enabled: false, child: Text('カラム割当')),
                  ..._presetLabels.map((p) => DropdownMenuItem(
                    value: p.join(','),
                    child: Text(p.join('・'), style: const TextStyle(fontSize: 12)),
                    onTap: () => _applyPreset(p),
                  )),
                ],
                onChanged: (v) {},
              ),
              const SizedBox(width: 4),
              TextButton.icon(onPressed: () => setState(() { _rows = []; }), icon: const Icon(Icons.refresh, size: 18), label: const Text('戻る')),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Table(
              border: TableBorder.all(color: cs.outlineVariant, width: 0.5),
              columnWidths: {for (var i = 0; i < _columnCount; i++) i: FlexColumnWidth()},
              children: [
                TableRow(
                  decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.4)),
                  children: [
                    ...List.generate(_columnCount, (c) => _buildHeaderCell(c, cs)),
                    const TableCell(child: SizedBox(width: 32)),
                  ],
                ),
                ..._rows.asMap().entries.map((entry) {
                  final ri = entry.key;
                  final row = entry.value;
                  return TableRow(
                    children: [
                      ...List.generate(_columnCount, (c) => _buildCell(ri, c, row[c], cs)),
                      TableCell(
                        child: IconButton(
                          icon: Icon(Icons.remove_circle_outline, size: 16, color: cs.error),
                          onPressed: () => _removeRow(ri),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCell(int col, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(_columnLabels[col], style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.primary)),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.arrow_drop_down, size: 14, color: cs.primary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onSelected: (v) => setState(() => _columnLabels[col] = v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: '品名', child: Text('品名', style: TextStyle(fontSize: 12))),
              const PopupMenuItem(value: '型番', child: Text('型番', style: TextStyle(fontSize: 12))),
              const PopupMenuItem(value: 'メーカー', child: Text('メーカー', style: TextStyle(fontSize: 12))),
              const PopupMenuItem(value: '金額', child: Text('金額', style: TextStyle(fontSize: 12))),
              const PopupMenuItem(value: '単価', child: Text('単価', style: TextStyle(fontSize: 12))),
              const PopupMenuItem(value: '数量', child: Text('数量', style: TextStyle(fontSize: 12))),
              const PopupMenuItem(value: '備考', child: Text('備考', style: TextStyle(fontSize: 12))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCell(int row, int col, String value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: SizedBox(
        height: 32,
        child: TextField(
          controller: TextEditingController(text: value),
          style: const TextStyle(fontSize: 11),
          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 4), border: InputBorder.none),
          onChanged: (v) => _updateCell(row, col, v),
        ),
      ),
    );
  }
}


