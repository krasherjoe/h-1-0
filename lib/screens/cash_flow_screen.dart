/// 資金繰り表画面
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/payment_repository.dart';
import '../services/payment_schedule_repository.dart';
import '../models/payment_model.dart';
import '../models/payment_schedule_model.dart';

class CashFlowScreen extends StatefulWidget {
  const CashFlowScreen({super.key});

  @override
  State<CashFlowScreen> createState() => _CashFlowScreenState();
}

class _CashFlowScreenState extends State<CashFlowScreen> {
  List<PaymentSchedule> _schedules = [];
  Map<String, int> _monthlyPayments = {};
  Map<String, int> _monthlySchedules = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final paymentRepo = PaymentRepository();
      final scheduleRepo = PaymentScheduleRepository();

      final schedules = await scheduleRepo.getUpcomingSchedules(days: 90);
      final monthlyPayments = await paymentRepo.getMonthlyPaymentTotals(
        months: 6,
      );
      final monthlySchedules = await scheduleRepo.getMonthlyScheduleTotals(
        months: 6,
      );

      setState(() {
        _schedules = schedules;
        _monthlyPayments = monthlyPayments;
        _monthlySchedules = monthlySchedules;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('データ読み込みに失敗しました: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CF:資金繰り'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // サマリー
                  _buildSummaryCards(),
                  const SizedBox(height: 24),

                  // 月次推移グラフ
                  _buildMonthlyChart(),
                  const SizedBox(height: 24),

                  // 支払方法別内訳
                  _buildPaymentMethodChart(),
                  const SizedBox(height: 24),

                  // 今後の支払予定
                  _buildUpcomingPayments(),
                  const SizedBox(height: 24),

                  // 延滞一覧
                  _buildOverdueList(),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCards() {
    final now = DateTime.now();
    final thisMonth = DateFormat('yyyy-MM').format(now);
    final thisMonthPayments = _monthlyPayments[thisMonth] ?? 0;
    final thisMonthSchedules = _monthlySchedules[thisMonth] ?? 0;

    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('今月支払済', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(
                    '¥${thisMonthPayments.toString().replaceAllMapped(RegExp(r'(?=(?!^)(\d{3})+$)'), (Match m) => ',')}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('今月予定', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(
                    '¥${thisMonthSchedules.toString().replaceAllMapped(RegExp(r'(?=(?!^)(\d{3})+$)'), (Match m) => ',')}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('月次支払推移', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(height: 200, child: _buildBarChart()),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    final now = DateTime.now();
    final months = <String>[];
    final payments = <int>[];
    final schedules = <int>[];

    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthKey = DateFormat('yyyy-MM').format(month);
      months.add(DateFormat('M月').format(month));
      payments.add(_monthlyPayments[monthKey] ?? 0);
      schedules.add(_monthlySchedules[monthKey] ?? 0);
    }

    return Row(
      children: months.map((month) {
        final index = months.indexOf(month);
        final payment = payments[index];
        final schedule = schedules[index];
        final maxValue = [
          ...payments,
          ...schedules,
        ].reduce((a, b) => a > b ? a : b);

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (payment > 0)
                      Container(
                        width: 20,
                        height: (payment / maxValue) * 150,
                        color: Theme.of(context).colorScheme.primaryContainer,
                      ),
                    if (schedule > 0)
                      Container(
                        width: 20,
                        height: (schedule / maxValue) * 150,
                        color: Theme.of(context).colorScheme.secondaryContainer,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(month, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPaymentMethodChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '支払方法別内訳',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            FutureBuilder<Map<PaymentMethod, int>>(
              future: PaymentRepository().getPaymentTotalsByMethod(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                final totals = snapshot.data!;
                if (totals.isEmpty) {
                  return const Text('データがありません');
                }

                final total = totals.values.reduce((a, b) => a + b);

                return Column(
                  children: totals.entries.map((entry) {
                    final method = entry.key;
                    final amount = entry.value;
                    final percentage = total > 0
                        ? (amount / total * 100).toStringAsFixed(1)
                        : '0';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            _getPaymentMethodIcon(method),
                            color: _getPaymentMethodColor(method, Theme.of(context).colorScheme),
                          ),
                          const SizedBox(width: 8),
                          Text(_getPaymentMethodDisplayName(method)),
                          const Spacer(),
                          Text(
                            '¥${amount.toString().replaceAllMapped(RegExp(r'(?=(?!^)(\d{3})+$)'), (Match m) => ',')} ($percentage%)',
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingPayments() {
    final upcomingSchedules = _schedules
        .where((s) => !s.isOverdue)
        .take(10)
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '今後の支払予定（${upcomingSchedules.length}件）',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (upcomingSchedules.isEmpty)
              const Text('支払予定がありません')
            else
              ...upcomingSchedules.map(
                (schedule) => ListTile(
                  title: Text(schedule.displayTitle),
                  subtitle: Text(schedule.displaySubtitle),
                  trailing: Text(schedule.displayAmount),
                  leading: CircleAvatar(
                    backgroundColor: schedule.getStatusColor(),
                    child: Icon(Icons.payment, color: Theme.of(context).colorScheme.onPrimary, size: 20),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverdueList() {
    final overdueSchedules = _schedules
        .where((s) => s.isOverdue)
        .take(5)
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '延滞中（${overdueSchedules.length}件）',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            if (overdueSchedules.isEmpty)
              const Text('延滞はありません')
            else
              ...overdueSchedules.map(
                (schedule) => ListTile(
                  title: Text(schedule.displayTitle),
                  subtitle: Text('延滞日数: ${-schedule.daysUntilDue}日'),
                  trailing: Text(schedule.displayAmount),
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.errorContainer,
                    child: Icon(Icons.warning, color: Theme.of(context).colorScheme.onErrorContainer, size: 20),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getPaymentMethodIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.bankTransfer:
        return Icons.account_balance;
      case PaymentMethod.cash:
        return Icons.money;
      case PaymentMethod.creditCard:
        return Icons.credit_card;
      case PaymentMethod.other:
        return Icons.more_horiz;
    }
  }

  Color _getPaymentMethodColor(PaymentMethod method, ColorScheme cs) {
    switch (method) {
      case PaymentMethod.bankTransfer:
        return cs.primary;
      case PaymentMethod.cash:
        return cs.secondary;
      case PaymentMethod.creditCard:
        return cs.tertiary;
      case PaymentMethod.other:
        return cs.onSurfaceVariant;
    }
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
}
