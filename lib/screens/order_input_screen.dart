import 'dart:async';

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
  final CustomerRepository _customerRepo = CustomerRepository();
  List<Invoice> _orders = [];
  List<Customer> _customers = [];
  StreamSubscription<List<Invoice>>? _ordersSubscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initOrders();
  }

  Future<void> _initOrders() async {
    setState(() => _isLoading = true);
    try {
      final customers = await _customerRepo.getAllCustomers();
      if (!mounted) return;
      _customers = customers;
      await _loadOrders(customers: customers);
      await _ordersSubscription?.cancel();
      _ordersSubscription = _repo.watchOrders(customers).listen((orders) {
        if (!mounted) return;
        setState(() {
          _orders = List.of(orders)..sort((a, b) => b.date.compareTo(a.date));
          _isLoading = false;
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('受注の読み込みに失敗しました: $e')),
      );
    }
  }

  Future<void> _loadOrders({List<Customer>? customers}) async {
    final sourceCustomers = customers ?? _customers;
    if (sourceCustomers.isEmpty) return;
    final orders = await _repo.getOrders(sourceCustomers);
    if (!mounted) return;
    setState(() {
      _orders = List.of(orders)..sort((a, b) => b.date.compareTo(a.date));
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
      documentType: DocumentType.order,
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
  void dispose() {
    _ordersSubscription?.cancel();
    super.dispose();
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
                    final statusLabel = order.orderStatus.label;
                    final isDraft = order.orderStatus == OrderStatus.draft;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isDraft ? Colors.orange.shade100 : Colors.teal.shade100,
                          child: Icon(
                            isDraft ? Icons.edit_note : Icons.assignment_turned_in,
                            color: isDraft ? Colors.orange : Colors.teal,
                          ),
                        ),
                        title: Text(
                          order.customer.displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${order.date.year}/${order.date.month.toString().padLeft(2, '0')}/${order.date.day.toString().padLeft(2, '0')} - $statusLabel\n'
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
