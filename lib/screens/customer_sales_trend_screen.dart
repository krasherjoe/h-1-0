import 'package:flutter/material.dart';

import '../models/invoice_models.dart';
import '../services/customer_repository.dart';
import '../services/invoice_repository.dart';

class CustomerSalesTrendScreen extends StatefulWidget {
  const CustomerSalesTrendScreen({super.key});

  @override
  State<CustomerSalesTrendScreen> createState() => _CustomerSalesTrendScreenState();
}

class _CustomerSalesTrendScreenState extends State<CustomerSalesTrendScreen> {
  final InvoiceRepository _repo = InvoiceRepository();
  final CustomerRepository _customerRepo = CustomerRepository();
  List<_CustomerSalesSummary> _summary = [];
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

    final Map<String, _CustomerSalesSummary> map = {};
    for (final inv in filtered) {
      final key = inv.customer?.id ?? '';
      if (!map.containsKey(key)) {
        map[key] = _CustomerSalesSummary(
          customerId: inv.customer?.id ?? '',
          customerName: inv.customer?.displayName ?? '未設定顧客',
          totalAmount: 0,
          count: 0,
        );
      }
      map[key] = map[key]!.copyWith(
        totalAmount: map[key]!.totalAmount + inv.totalAmount,
        count: map[key]!.count + 1,
      );
    }

    if (!mounted) return;
    setState(() {
      _summary = map.values.toList()..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('CS:得意先別売上推移'),
        backgroundColor: Colors.deepPurple,
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
                      color: Colors.deepPurple.shade50,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('合計売上', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                Text(
                                  '¥${_summary.fold(0, (sum, s) => sum + s.totalAmount)}',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('得意先数', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                Text(
                                  '${_summary.length} 社',
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
                                backgroundColor: Colors.deepPurple.shade100,
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
                                ),
                              ),
                              title: Text(
                                s.customerName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text('伝票数: ${s.count}'),
                              trailing: Text(
                                '¥${s.totalAmount}',
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

class _CustomerSalesSummary {
  final String customerId;
  final String customerName;
  final int totalAmount;
  final int count;

  _CustomerSalesSummary({
    required this.customerId,
    required this.customerName,
    required this.totalAmount,
    required this.count,
  });

  _CustomerSalesSummary copyWith({
    String? customerId,
    String? customerName,
    int? totalAmount,
    int? count,
  }) {
    return _CustomerSalesSummary(
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      totalAmount: totalAmount ?? this.totalAmount,
      count: count ?? this.count,
    );
  }
}
