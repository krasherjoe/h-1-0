import 'package:flutter/material.dart';
import '../services/performance_service.dart';

/// パフォーマンス最適化画面
class PerformanceOptimizationScreen extends StatefulWidget {
  const PerformanceOptimizationScreen({super.key});

  @override
  State<PerformanceOptimizationScreen> createState() => _PerformanceOptimizationScreenState();
}

class _PerformanceOptimizationScreenState extends State<PerformanceOptimizationScreen> {
  final PerformanceService _performanceService = PerformanceService.instance;
  final IsolateService _isolateService = IsolateService.instance;
  
  Map<String, dynamic>? _performanceStats;
  List<String>? _bottlenecks;
  bool _isOptimizing = false;
  
  @override
  void initState() {
    super.initState();
    _loadPerformanceData();
  }
  
  Future<void> _loadPerformanceData() async {
    setState(() {
      _performanceStats = _performanceService.generateReport();
      _bottlenecks = _performanceService.analyzeBottlenecks();
    });
  }
  
  Future<void> _optimizePerformance() async {
    setState(() {
      _isOptimizing = true;
    });
    
    try {
      // パフォーマンス最適化を実行
      _performanceService.startTimer('optimization');
      
      // キャッシュをクリア
      PerformanceOptimizer.clearCache();
      
      // メモリ使用量を記録
      _performanceService.recordMemoryUsage('optimization');
      
      // 不要なリソースを解放
      PerformanceOptimizer.releaseResources();
      
      // 重い処理をIsolateで実行
      await _isolateService.runInIsolate(
        'heavy_computation',
        _performHeavyComputation,
        1000000,
      );
      
      _performanceService.stopTimer('optimization');
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('パフォーマンス最適化が完了しました'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      
      _loadPerformanceData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('最適化に失敗しました: $e')),
        );
      }
    } finally {
      setState(() {
        _isOptimizing = false;
      });
    }
  }
  
  Future<int> _performHeavyComputation(int iterations) async {
    int sum = 0;
    for (int i = 0; i < iterations; i++) {
      sum += i * i;
    }
    return sum;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PO:パフォーマンス最適化'),
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPerformanceData,
            tooltip: '更新',
          ),
        ],
      ),
      body: _isOptimizing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOptimizationButton(),
                  const SizedBox(height: 16),
                  _buildPerformanceStats(),
                  const SizedBox(height: 16),
                  _buildBottlenecks(),
                  const SizedBox(height: 16),
                  _buildIsolateStatus(),
                  const SizedBox(height: 16),
                  _buildMemoryUsage(),
                ],
              ),
            ),
    );
  }
  
  Widget _buildOptimizationButton() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'パフォーマンス最適化',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
    Text(
               'キャッシュクリア、メモリ解放、Isolate処理を実行してアプリのパフォーマンスを向上させます。',
               style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
             ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _optimizePerformance,
                icon: const Icon(Icons.speed),
                label: const Text('最適化を実行'),
 style: ElevatedButton.styleFrom(
                   backgroundColor: Theme.of(context).colorScheme.tertiary,
                   foregroundColor: Theme.of(context).colorScheme.onTertiary,
                   padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPerformanceStats() {
    if (_performanceStats == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('パフォーマンスデータがありません')),
        ),
      );
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'パフォーマンス統計',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._performanceStats!.entries.map((entry) {
              return _buildStatRow(entry.key, entry.value);
            }),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatRow(String key, dynamic value) {
    String displayValue;
    Color valueColor = Theme.of(context).colorScheme.onSurface;
    
    if (value is Duration) {
      displayValue = '${value.inMilliseconds}ms';
      if (value.inMilliseconds > 1000) {
        valueColor = Theme.of(context).colorScheme.error;
      } else if (value.inMilliseconds > 500) {
        valueColor = Theme.of(context).colorScheme.secondary;
      } else {
        valueColor = Theme.of(context).colorScheme.primary;
      }
    } else if (value is Map) {
      final avg = value['average'] ?? 0;
      displayValue = '${avg.toStringAsFixed(1)}';
      
      if (avg > 100 * 1024 * 1024) { // 100MB
        valueColor = Theme.of(context).colorScheme.error;
      } else if (avg > 50 * 1024 * 1024) { // 50MB
        valueColor = Theme.of(context).colorScheme.secondary;
      } else {
        valueColor = Theme.of(context).colorScheme.primary;
      }
    } else {
      displayValue = value.toString();
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 200,
            child: Text(
              key,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              displayValue,
              style: TextStyle(
                color: valueColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBottlenecks() {
    if (_bottlenecks == null || _bottlenecks!.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ボトルネック分析',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
Row(
                 children: [
                   Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                  SizedBox(width: 8),
                  Text('ボトルネックは検出されませんでした'),
                ],
              ),
            ],
          ),
        ),
      );
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ボトルネック分析',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._bottlenecks!.map((bottleneck) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
child: Row(
                   children: [
                     Icon(Icons.warning, color: Theme.of(context).colorScheme.secondary),
                     const SizedBox(width: 8),
                     Expanded(
                       child: Text(
                         bottleneck,
                         style: TextStyle(color: Theme.of(context).colorScheme.secondary),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
  
  Widget _buildIsolateStatus() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Isolateステータス',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  _isolateService.activeIsolateCount > 0
                      ? Icons.memory
                      : Icons.check_circle,
                  color: _isolateService.activeIsolateCount > 0
                      ? Theme.of(context).colorScheme.secondary
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'アクティブなIsolate: ${_isolateService.activeIsolateCount}',
                  style: TextStyle(
                    color: _isolateService.activeIsolateCount > 0
                        ? Theme.of(context).colorScheme.secondary
                        : Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Isolateは重い処理をバックグラウンドで実行し、UIの応答性を維持します。',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMemoryUsage() {
    final currentMemory = _performanceService.getCurrentMemoryUsage();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'メモリ使用量',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (currentMemory / (500 * 1024 * 1024)).clamp(0.0, 1.0),
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                currentMemory > 400 * 1024 * 1024
                    ? Theme.of(context).colorScheme.error
                    : currentMemory > 250 * 1024 * 1024
                        ? Theme.of(context).colorScheme.secondary
                        : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '現在: ${(currentMemory / 1024 / 1024).toStringAsFixed(1)} MB',
              style: TextStyle(
                color: currentMemory > 400 * 1024 * 1024
                    ? Theme.of(context).colorScheme.error
                    : currentMemory > 250 * 1024 * 1024
                        ? Theme.of(context).colorScheme.secondary
                        : Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '上限: 500 MB',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
