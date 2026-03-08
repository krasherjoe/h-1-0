/// 支払実績登録画面
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/payment_repository.dart';
import '../services/payment_schedule_repository.dart';
import '../services/supplier_repository.dart';
import '../models/payment_model.dart';
import '../models/payment_schedule_model.dart';
import '../models/supplier_model.dart';

class PaymentRegisterScreen extends StatefulWidget {
  const PaymentRegisterScreen({super.key});

  @override
  State<PaymentRegisterScreen> createState() => _PaymentRegisterScreenState();
}

class _PaymentRegisterScreenState extends State<PaymentRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _notesController = TextEditingController();
  
  Supplier? _selectedSupplier;
  PaymentMethod _selectedPaymentMethod = PaymentMethod.bankTransfer;
  List<PaymentSchedule> _selectedSchedules = [];
  List<PaymentSchedule> _availableSchedules = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    setState(() => _isLoading = true);
    try {
      final repo = PaymentScheduleRepository();
      final schedules = await repo.getUpcomingSchedules(days: 90);
      setState(() {
        _availableSchedules = schedules.where((s) => s.status == PaymentStatus.unpaid).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('支払予定の読み込みに失敗しました: $e')),
      );
    }
  }

  int get _totalSelectedAmount {
    return _selectedSchedules.fold(0, (sum, schedule) => sum + schedule.amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('P2:支払登録'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 仕入先選択
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('仕入先', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          FutureBuilder<List<Supplier>>(
                            future: SupplierRepository().getAllSuppliers(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const CircularProgressIndicator();
                              }
                              return DropdownButtonFormField<Supplier>(
                                value: _selectedSupplier,
                                decoration: const InputDecoration(
                                  hintText: '仕入先を選択',
                                ),
                                items: snapshot.data!.map((supplier) {
                                  return DropdownMenuItem(
                                    value: supplier,
                                    child: Text(supplier.displayName),
                                  );
                                }).toList(),
                                onChanged: (supplier) {
                                  setState(() {
                                    _selectedSupplier = supplier;
                                    _selectedSchedules.clear();
                                  });
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 支払予定選択
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('支払対象', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('合計: ¥${_totalSelectedAmount.toString().replaceAllMapped(
                                RegExp(r'(?=(?!^)(\d{3})+$)'),
                                (Match m) => ',',
                              )}'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_availableSchedules.isEmpty)
                            const Text('支払予定がありません')
                          else
                            ..._availableSchedules.map((schedule) {
                              final isSelected = _selectedSchedules.contains(schedule);
                              return CheckboxListTile(
                                title: Text(schedule.displayTitle),
                                subtitle: Text('${schedule.displayAmount} - ${schedule.displaySubtitle}'),
                                value: isSelected,
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedSchedules.add(schedule);
                                    } else {
                                      _selectedSchedules.remove(schedule);
                                    }
                                    // 金額を自動更新
                                    if (_selectedSchedules.isNotEmpty) {
                                      _amountController.text = _totalSelectedAmount.toString();
                                    }
                                  });
                                },
                              );
                            }),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 支払情報
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('支払情報', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _amountController,
                            decoration: const InputDecoration(
                              labelText: '支払金額',
                              hintText: '0',
                              prefixText: '¥',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '金額を入力してください';
                              }
                              if (int.tryParse(value) == null) {
                                return '有効な数値を入力してください';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<PaymentMethod>(
                            value: _selectedPaymentMethod,
                            decoration: const InputDecoration(
                              labelText: '支払方法',
                            ),
                            items: PaymentMethod.values.map((method) {
                              return DropdownMenuItem(
                                value: method,
                                child: Text(_getPaymentMethodDisplayName(method)),
                              );
                            }).toList(),
                            onChanged: (method) {
                              setState(() {
                                _selectedPaymentMethod = method!;
                              });
                            },
                          ),
                          if (_selectedPaymentMethod == PaymentMethod.bankTransfer) ...[
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _bankAccountController,
                              decoration: const InputDecoration(
                                labelText: '振込口座',
                                hintText: '123-456789',
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _notesController,
                            decoration: const InputDecoration(
                              labelText: '備考',
                              hintText: '任意',
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 登録ボタン
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _registerPayment,
                      child: const Text('支払を登録'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _getPaymentMethodDisplayName(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.bankTransfer:
        return '銀行振込';
      case PaymentMethod.cash:
        return '現金';
      case PaymentMethod.creditCard:
        return 'クレジットカード';
      case PaymentMethod.other:
        return 'その他';
    }
  }

  Future<void> _registerPayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('仕入先を選択してください')),
      );
      return;
    }

    try {
      final paymentRepo = PaymentRepository();
      final scheduleRepo = PaymentScheduleRepository();

      // 支払実績を登録
      final payment = Payment(
        id: const Uuid().v4(),
        paymentNumber: paymentRepo.generatePaymentNumber(),
        paymentDate: DateTime.now(),
        supplier: _selectedSupplier!,
        amount: int.parse(_amountController.text),
        paymentMethod: _selectedPaymentMethod,
        bankAccount: _bankAccountController.text.isEmpty ? null : _bankAccountController.text,
        purchaseIds: _selectedSchedules.map((s) => s.purchase.id).toList(),
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      await paymentRepo.savePayment(payment);

      // 支払予定を更新
      for (final schedule in _selectedSchedules) {
        await scheduleRepo.updateScheduleStatus(
          schedule.id,
          PaymentStatus.paid,
          paymentId: payment.id,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('支払を登録しました')),
      );
      
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登録に失敗しました: $e')),
      );
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _bankAccountController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
