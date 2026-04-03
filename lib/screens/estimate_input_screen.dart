import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/customer_model.dart';
import '../models/invoice_models.dart';
import '../services/customer_repository.dart';
import '../services/invoice_repository.dart';
import 'customer_master_screen.dart';

class EstimateInputScreen extends StatefulWidget {
  const EstimateInputScreen({super.key});

  @override
  State<EstimateInputScreen> createState() => _EstimateInputScreenState();
}

class _EstimateInputScreenState extends State<EstimateInputScreen> {
  final InvoiceRepository _repo = InvoiceRepository();
  List<Invoice> _estimates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEstimates();
  }

  Future<void> _loadEstimates() async {
    setState(() => _isLoading = true);
    final customers = await CustomerRepository().getAllCustomers();
    final allInvoices = await _repo.getAllInvoices(customers);
    if (!mounted) return;
    setState(() {
      _estimates = allInvoices.where((inv) => inv.documentType == DocumentType.estimation).toList();
      _estimates.sort((a, b) => b.date.compareTo(a.date));
      _isLoading = false;
    });
  }

  Future<void> _createNewEstimate() async {
    final customer = await Navigator.push<Customer?>(
      context,
      MaterialPageRoute(
        builder: (_) => const CustomerMasterScreen(selectionMode: true),
      ),
    );

    if (customer == null || !mounted) return;

    final newEstimate = Invoice(
      id: const Uuid().v4(),
      customer: customer,
      date: DateTime.now(),
      items: [],
      documentType: DocumentType.estimation,
      isDraft: true,
    );

    await _repo.saveInvoice(newEstimate);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${customer.displayName} の見積を作成しました')),
    );
    _loadEstimates();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('ES:見積入力'),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _estimates.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.description, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('見積が登録されていません'),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _createNewEstimate,
                        icon: const Icon(Icons.add),
                        label: const Text('新規作成'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _estimates.length,
                  itemBuilder: (context, index) {
                    final est = _estimates[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: est.isDraft ? Colors.orange.shade100 : Colors.blue.shade100,
                          child: Icon(
                            est.isDraft ? Icons.edit_note : Icons.description,
                            color: est.isDraft ? Colors.orange : Colors.blue,
                          ),
                        ),
                        title: Text(
                          est.customer.displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${est.date.year}/${est.date.month}/${est.date.day} - ${est.isDraft ? '下書き' : '確定'}\n'
                          '合計: ¥${est.totalAmount}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('見積詳細画面は今後実装予定です')),
                          );
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewEstimate,
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
