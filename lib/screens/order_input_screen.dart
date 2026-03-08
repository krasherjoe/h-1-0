import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/customer_model.dart';
import '../models/invoice_models.dart';
import '../services/customer_repository.dart';
import '../services/invoice_repository.dart';
import 'customer_master_screen.dart';

class OrderInputScreen extends StatefulWidget {
  const OrderInputScreen({super.key});

  @override
  State<OrderInputScreen> createState() => _OrderInputScreenState();
}

class _OrderInputScreenState extends State<OrderInputScreen> {
  final InvoiceRepository _repo = InvoiceRepository();
  List<Invoice> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    final customers = await CustomerRepository().getAllCustomers();
    final allInvoices = await _repo.getAllInvoices(customers);
    if (!mounted) return;
    setState(() {
      _orders = allInvoices.where((inv) => inv.documentType == DocumentType.delivery).toList();
      _orders.sort((a, b) => b.date.compareTo(a.date));
      _isLoading = false;
    });
  }

  Future<void> _createNewOrder() async {
    final customer = await Navigator.push<Customer?>(
      context,
      MaterialPageRoute(
        builder: (_) => const CustomerMasterScreen(selectionMode: true),
      ),
    );

    if (customer == null || !mounted) return;

    final newOrder = Invoice(
      id: const Uuid().v4(),
      customer: customer,
      date: DateTime.now(),
      items: [],
      documentType: DocumentType.delivery,
      isDraft: true,
    );

    await _repo.saveInvoice(newOrder);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${customer.displayName} の受注を作成しました')),
    );
    _loadOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('O1:受注入力'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.assignment_turned_in, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        '受注が登録されていません',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _createNewOrder,
                        icon: const Icon(Icons.add),
                        label: const Text('新規受注作成'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    final order = _orders[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: order.isDraft ? Colors.orange.shade100 : Colors.teal.shade100,
                          child: Icon(
                            order.isDraft ? Icons.edit_note : Icons.assignment_turned_in,
                            color: order.isDraft ? Colors.orange : Colors.teal,
                          ),
                        ),
                        title: Text(
                          order.customer.displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${order.date.year}/${order.date.month.toString().padLeft(2, '0')}/${order.date.day.toString().padLeft(2, '0')} - ${order.isDraft ? '下書き' : '確定'}\n'
                          '合計: ¥${order.totalAmount.toStringAsFixed(0)}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('受注詳細画面は今後実装予定です')),
                          );
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewOrder,
        icon: const Icon(Icons.add),
        label: const Text('新規受注'),
      ),
    );
  }
}
