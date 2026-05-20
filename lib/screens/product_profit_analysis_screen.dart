import 'package:flutter/material.dart';

import '../models/invoice_models.dart';
import '../services/customer_repository.dart';
import '../services/invoice_repository.dart';

class ProductProfitAnalysisScreen extends StatefulWidget {
  const ProductProfitAnalysisScreen({super.key});

  @override
  State<ProductProfitAnalysisScreen> createState() => _ProductProfitAnalysisScreenState();
}

class _ProductProfitAnalysisScreenState extends State<ProductProfitAnalysisScreen> {
  final InvoiceRepository _repo = InvoiceRepository();
  final CustomerRepository _customerRepo = CustomerRepository();
  List<_ProductProfitSummary> _summary = [];
  bool _isLoading = true;
  String _period = 'month';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final customers = await _customerRepo.getAllCustomers();
    final invoices = await _repo.getAllInvoices(customers);
    
    final now = DateTime.now();
    final filtered = invoices.where((inv) {
      if (inv.documentType != DocumentType.invoice) return false;
      final diff = now.difference(inv.date).inDays;
      switch (_period) {
        case 'week':
          return diff <= 7;
        case 'month':
          return diff <= 30;
        case 'quarter':
          return diff <= 90;
        case 'year':
          return diff <= 365;
        default:
          return true;
      }
    }).toList();

    final Map<String, _ProductProfitSummary> map = {};
    for (final inv in filtered) {
      for (final item in inv.items) {
        final key = item.description;
        if (!map.containsKey(key)) {
          map[key] = _ProductProfitSummary(
            productName: item.description,
            totalSales: 0,
            totalQuantity: 0,
          );
        }
        final sales = item.quantity * item.unitPrice;
        map[key] = map[key]!.copyWith(
          totalSales: map[key]!.totalSales + sales,
          totalQuantity: map[key]!.totalQuantity + item.quantity,
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _summary = map.values.toList()..sort((a, b) => b.totalSales.compareTo(a.totalSales));
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('PA:商品別粗利分析'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.date_range),
            onSelected: (value) {
              setState(() {
                _period = value;
              });
              _loadData();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'week', child: Text('過去1週間')),
              const PopupMenuItem(value: 'month', child: Text('過去1ヶ月')),
              const PopupMenuItem(value: 'quarter', child: Text('過去3ヶ月')),
              const PopupMenuItem(value: 'year', child: Text('過去1年')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _summary.isEmpty
              ? const Center(child: Text('該当期間の売上データがありません'))
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('合計売上', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                Text(
                                  '¥${_summary.fold(0, (sum, s) => sum + s.totalSales)}',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('商品数', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                Text(
                                  '${_summary.length} 品',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _summary.length,
                        itemBuilder: (context, index) {
                          final s = _summary[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                                ),
                              ),
                              title: Text(
                                s.productName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text('販売数: ${s.totalQuantity}'),
                              trailing: Text(
                                '¥${s.totalSales}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _ProductProfitSummary {
  final String productName;
  final int totalSales;
  final int totalQuantity;

  _ProductProfitSummary({
    required this.productName,
    required this.totalSales,
    required this.totalQuantity,
  });

  _ProductProfitSummary copyWith({
    String? productName,
    int? totalSales,
    int? totalQuantity,
  }) {
    return _ProductProfitSummary(
      productName: productName ?? this.productName,
      totalSales: totalSales ?? this.totalSales,
      totalQuantity: totalQuantity ?? this.totalQuantity,
    );
  }
}
