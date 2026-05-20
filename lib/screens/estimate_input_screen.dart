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
      includeTax: false,
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _estimates.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                    final subjectText =
                        (est.subject?.isNotEmpty == true)
                            ? est.subject!
                            : (est.items.isNotEmpty
                                ? est.items.first.description
                                : '（明細なし）');
                    final amountText =
                        '¥${est.totalAmount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('見積詳細画面は今後実装予定です')),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: est.isDraft
                                    ? Theme.of(context).colorScheme.secondaryContainer
                                    : Theme.of(context).colorScheme.primaryContainer,
                                child: Icon(
                                  est.isDraft
                                      ? Icons.edit_note
                                      : Icons.description,
                                  color: est.isDraft
                                      ? Theme.of(context).colorScheme.secondary
                                      : Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      est.customer.displayName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    ),
                                    const SizedBox(height: 2),
Text(
                                       '${est.date.year}/${est.date.month.toString().padLeft(2, '0')}/${est.date.day.toString().padLeft(2, '0')}  ${est.isDraft ? '下書き' : '確定'}',
                                       style: TextStyle(
                                           fontSize: 12,
                                           color: Theme.of(context).colorScheme.onSurfaceVariant),
                                     ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
Expanded(
                                           child: Text(
                                             subjectText,
                                             style: TextStyle(
                                                 fontSize: 12,
                                                 color: Theme.of(context).colorScheme.onSurfaceVariant),
                                             overflow: TextOverflow.ellipsis,
                                           ),
                                         ),
                                        const SizedBox(width: 8),
                                        Text(
                                          amountText,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.chevron_right,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewEstimate,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        child: const Icon(Icons.add),
      ),
    );
  }
}
