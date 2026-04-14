import 'package:flutter/material.dart';
import '../models/analytics_summary_model.dart';
import '../models/analytics_metric_model.dart';
import '../services/analytics_repository.dart';
import '../widgets/metric_card.dart';
import '../widgets/analytics_chart.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  final AnalyticsRepository _repository = AnalyticsRepository();
  AnalyticsSummary? _summary;
  bool _loading = true;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final summary = await _repository.fetchMonthlySummary(_selectedMonth);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('データの読み込みに失敗しました: $e')),
      );
    }
  }

  void _selectMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && mounted) {
      setState(() => _selectedMonth = DateTime(picked.year, picked.month));
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AA:集計分析'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectMonth,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _summary == null
              ? const Center(child: Text('データがありません'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPeriodHeader(),
                        const SizedBox(height: 16),
                        _buildMetricsGrid(),
                        const SizedBox(height: 24),
                        _buildChartsSection(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildPeriodHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _summary!.periodLabel,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (_summary!.notes != null) ...[
              const SizedBox(height: 8),
              Text(
                _summary!.notes!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: _summary!.metrics
          .map((metric) => MetricCard(metric: metric))
          .toList(),
    );
  }

  Widget _buildChartsSection() {
    final salesMetrics = _summary!.metricsByCategory(MetricCategory.sales);
    final purchaseMetrics = _summary!.metricsByCategory(MetricCategory.purchasing);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (salesMetrics.isNotEmpty) ...[
          Text(
            '売上推移',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          AnalyticsChart(metrics: salesMetrics),
          const SizedBox(height: 16),
        ],
        if (purchaseMetrics.isNotEmpty) ...[
          Text(
            '仕入推移',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          AnalyticsChart(metrics: purchaseMetrics),
        ],
      ],
    );
  }
}
