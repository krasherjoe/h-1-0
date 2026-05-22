import 'package:flutter/material.dart';

class ParsedLineItem {
  ParsedLineItem(this.name, this.price);
  final String name;
  final int price;
}

Future<List<ParsedLineItem>> showPasteBufferDialog(BuildContext context) async {
  final textController = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('PB:テキストを貼付'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Amazon/楽天などからコピーしたテキストを貼り付けてください', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                controller: textController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: '商品名\n￥1,280\n\n商品名2\n¥2,500',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
        FilledButton(onPressed: () => Navigator.pop(ctx, textController.text), child: const Text('明細に変換')),
      ],
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) => textController.dispose());
  if (result == null || result.trim().isEmpty) return [];

  final lines = result.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
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
      if (currentName != null) {
        parsed.add(ParsedLineItem(currentName, 0));
      }
      currentName = line.replaceAll(RegExp(r'^[・\-•]+\s*'), '');
    }
  }
  if (currentName != null) {
    parsed.add(ParsedLineItem(currentName, 0));
  }
  return parsed;
}

int? _parsePrice(String text) {
  final cleaned = text
      .replaceAll(RegExp(r'[￥¥,,\s]'), '')
      .replaceAll('円', '')
      .trim();
  final match = RegExp(r'^(\d+)$').firstMatch(cleaned);
  if (match != null) {
    final v = int.parse(match.group(1)!);
    if (v > 0 && v < 100000000) return v;
  }
  return null;
}
