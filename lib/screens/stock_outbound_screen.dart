import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product_model.dart';
import '../models/stock_transaction_model.dart';
import '../services/stock_transaction_repository.dart';
import '../services/product_repository.dart';
import 'product_master_screen.dart';

/// WHO:出庫処理
class StockOutboundScreen extends StatefulWidget {
  const StockOutboundScreen({super.key});
  @override
  State<StockOutboundScreen> createState() => _StockOutboundScreenState();
}

class _StockOutboundScreenState extends State<StockOutboundScreen> {
  final _repo = StockTransactionRepository();
  final _productRepo = ProductRepository();
  final _nf = NumberFormat('#,###');
  final _df = DateFormat('yyyy/MM/dd');
  List<StockTransaction> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final h = await _repo.getAll(limit: 50);
    if (!mounted) return;
    setState(() { _history = h.where((t) => t.quantity < 0).toList(); _loading = false; });
  }

  Future<void> _outbound() async {
    final product = await Navigator.push<Product>(
      context,
      MaterialPageRoute(builder: (_) => const ProductMasterScreen(selectionMode: true)),
    );
    if (product == null) return;

    if (product.stockQuantity == null || product.stockQuantity! <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('在庫がありません')));
      return;
    }

    final qtyCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context, builder: (ctx) => AlertDialog(
        title: Text('出庫: ${product.name}'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('在庫: ${product.stockQuantity}個', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          TextField(controller: qtyCtrl, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '出庫数', isDense: true, border: OutlineInputBorder()),
            autofocus: true,
          ),
          const SizedBox(height: 8),
          TextField(controller: notesCtrl,
            decoration: const InputDecoration(labelText: '出庫理由', isDense: true, border: OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('出庫')),
        ],
      ),
    );
    if (confirmed != true) return;
    final qty = int.tryParse(qtyCtrl.text);
    if (qty == null || qty <= 0) return;
    if (qty > (product.stockQuantity ?? 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('在庫不足です')));
      return;
    }

    await _repo.outbound(
      productId: product.id, productName: product.name,
      quantity: qty, notes: notesCtrl.text.isNotEmpty ? notesCtrl.text : null,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${product.name} を ${qty}個 出庫しました')));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('WHO:出庫処理')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _outbound, icon: const Icon(Icons.remove), label: const Text('出庫登録'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(child: Text('出庫履歴がありません'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _history.length,
                  itemBuilder: (_, i) {
                    final t = _history[i];
                    return Card(
                      child: ListTile(
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.outbox, color: Colors.orange),
                        ),
                        title: Text(t.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${_df.format(t.createdAt)}${t.notes != null ? " / ${t.notes}" : ""}'),
                        trailing: Text('${t.quantity}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red.shade700)),
                      ),
                    );
                  },
                ),
    );
  }
}
