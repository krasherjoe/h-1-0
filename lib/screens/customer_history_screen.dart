import 'package:flutter/material.dart';
import '../models/customer_model.dart';
import '../services/customer_repository.dart';

class CustomerHistoryScreen extends StatefulWidget {
  final Customer customer;
  
  const CustomerHistoryScreen({
    super.key,
    required this.customer,
  });

  @override
  State<CustomerHistoryScreen> createState() => _CustomerHistoryScreenState();
}

class _CustomerHistoryScreenState extends State<CustomerHistoryScreen> {
  final CustomerRepository _customerRepo = CustomerRepository();
  List<Customer> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await _customerRepo.getCustomerHistory(widget.customer.id!);
      if (!mounted) return;
      setState(() {
        _history = history;
        _loading = false;
      });
    } catch (e) {
      print('履歴読み込みエラー: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('CH:履歴 - ${widget.customer.displayName}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(child: Text('履歴がありません'))
              : ListView.builder(
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final customer = _history[index];
                    final isCurrent = customer.isCurrent;
                    final isHidden = customer.isHidden;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCurrent ? Colors.green : Colors.grey,
                          child: Icon(
                            isCurrent ? Icons.check : Icons.history,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          'バージョン ${customer.version ?? 0}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('表示名: ${customer.displayName}'),
                            Text('正式名称: ${customer.formalName}'),
                            Text('敬称: ${customer.title}'),
                            if (customer.validFrom != null)
                              Text('有効開始: ${customer.validFrom}'),
                            if (isHidden)
                              const Text(
                                '非表示',
                                style: TextStyle(color: Colors.red),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isCurrent)
                              IconButton(
                                icon: const Icon(Icons.picture_as_pdf),
                                onPressed: () => _generatePdf(customer),
                                tooltip: "PDFを生成",
                              ),
                            if (isCurrent)
                              const Icon(Icons.star, color: Colors.amber),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _generatePdf(Customer customer) async {
    // TODO: 履歴データを使ってPDFを生成する機能を実装
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('PDF生成機能は実装中です: ${customer.displayName}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
