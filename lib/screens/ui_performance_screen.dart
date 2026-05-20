import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ui_performance_service.dart';

/// UIパフォーマンス最適化画面
class UIPerformanceScreen extends StatefulWidget {
  const UIPerformanceScreen({super.key});

  @override
  State<UIPerformanceScreen> createState() => _UIPerformanceScreenState();
}

class _UIPerformanceScreenState extends State<UIPerformanceScreen>
    with TickerProviderStateMixin {
  
  final UIPerformanceService _performanceService = UIPerformanceService.instance;
  final AnimationOptimizationService _animationService = AnimationOptimizationService.instance;
  final MemoryOptimizationService _memoryService = MemoryOptimizationService.instance;
  
  Map<String, dynamic>? _performanceStats;
  Map<String, dynamic>? _animationStats;
  Map<String, dynamic>? _memoryStats;
  List<PerformanceEvent>? _performanceEvents;
  List<MemorySnapshot>? _memorySnapshots;
  List<String> _warnings = [];
  
  late AnimationController _demoAnimationController;
  late Animation<double> _demoAnimation;
  
  bool _isMemoryMonitoring = false;
  
  @override
  void initState() {
    super.initState();
    _initializeServices();
    _setupDemoAnimation();
  }
  
  @override
  void dispose() {
    _demoAnimationController.dispose();
    _animationService.disposeAllControllers();
    _memoryService.stopMemoryMonitoring();
    super.dispose();
  }
  
  void _initializeServices() {
    _performanceService.startPerformanceMonitoring();
    _loadStatistics();
    
    // 定期的に統計を更新
    Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        _loadStatistics();
      }
    });
  }
  
  void _setupDemoAnimation() {
    _demoAnimationController = _animationService.createOptimizedController(
      name: 'demo_animation',
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _demoAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _demoAnimationController,
      curve: Curves.easeInOut,
    ));
  }
  
  Future<void> _loadStatistics() async {
    final performanceStats = _performanceService.getPerformanceStatistics();
    final animationStats = _animationService.getAnimationStatistics();
    final memoryStats = _memoryService.getMemoryStatistics();
    final performanceEvents = _performanceService.getPerformanceEvents();
    final memorySnapshots = _memoryService.getMemorySnapshots();
    
    final warnings = <String>[];
    warnings.addAll(_performanceService.checkPerformanceWarnings());
    warnings.addAll(_memoryService.checkMemoryWarnings());
    
    setState(() {
      _performanceStats = performanceStats;
      _animationStats = animationStats;
      _memoryStats = memoryStats;
      _performanceEvents = performanceEvents;
      _memorySnapshots = memorySnapshots;
      _warnings = warnings;
    });
  }
  
  void _startDemoAnimation() {
    _demoAnimationController.forward().then((_) {
      _demoAnimationController.reverse();
    });
  }
  
  void _performMemoryCleanup() async {
    await _memoryService.performMemoryCleanup();
    
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('メモリクリーンアップを実行しました'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
    
    _loadStatistics();
  }
  
  void _toggleMemoryMonitoring() {
    if (_isMemoryMonitoring) {
      _memoryService.stopMemoryMonitoring();
      setState(() {
        _isMemoryMonitoring = false;
      });
    } else {
      _memoryService.startMemoryMonitoring();
      setState(() {
        _isMemoryMonitoring = true;
      });
    }
  }
  
  void _generatePerformanceReport() {
    final report = _performanceService.generatePerformanceReport();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('パフォーマンスレポート'),
        content: SingleChildScrollView(
          child: Text(
            report,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UP:UIパフォーマンス最適化'),
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatistics,
            tooltip: '統計更新',
          ),
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: _generatePerformanceReport,
            tooltip: 'レポート生成',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_warnings.isNotEmpty) _buildWarningsSection(),
            _buildPerformanceSection(),
            const SizedBox(height: 16),
            _buildAnimationSection(),
            const SizedBox(height: 16),
            _buildMemorySection(),
            const SizedBox(height: 16),
            _buildDemoSection(),
            const SizedBox(height: 16),
            _buildEventsSection(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildWarningsSection() {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.15),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 8),
            Text(
                   'パフォーマンス警告',
                   style: TextStyle(
                     fontSize: 18,
                     fontWeight: FontWeight.bold,
                     color: Theme.of(context).colorScheme.secondary,
                   ),
                 ),
              ],
            ),
            const SizedBox(height: 12),
            ..._warnings.map((warning) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
                 children: [
                   Icon(Icons.error_outline, size: 16, color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(warning)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPerformanceSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'レンダリングパフォーマンス',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_performanceStats != null) ...[
              _buildPerformanceStats(),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildPerformanceStats() {
    return Column(
      children: [
        _buildStatRow('平均フレーム時間', '${_performanceStats!['averageFrameTime']?.toStringAsFixed(2)}μs'),
        _buildStatRow('最悪フレーム時間', '${_performanceStats!['worstFrameTime']?.toStringAsFixed(2)}μs'),
        _buildStatRow('フレームドロップ率', '${(_performanceStats!['frameDropRate'] * 100).toStringAsFixed(2)}%'),
        _buildStatRow('平均レンダリング時間', '${_performanceStats!['averageRenderTime']?.toStringAsFixed(2)}ms'),
        _buildStatRow('ウィジェット数', '${_performanceStats!['widgetCount']}'),
        _buildStatRow('イベント数', '${_performanceStats!['eventCount']}'),
        const SizedBox(height: 12),
        _buildPerformanceChart(),
      ],
    );
  }
  
  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const Text(': '),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPerformanceChart() {
    return Container(
      height: 100,
  decoration: BoxDecoration(
         border: Border.all(color: Theme.of(context).colorScheme.outline),
         borderRadius: BorderRadius.circular(4),
       ),
       child: Center(
         child: Text(
           'パフォーマンスチャート\n(実装予定)',
           style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
  
  Widget _buildAnimationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'アニメーション最適化',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_animationStats != null) ...[
              _buildAnimationStats(),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildAnimationStats() {
    return Column(
      children: [
        _buildStatRow('総アニメーション数', '${_animationStats!['totalAnimations']}'),
        _buildStatRow('平均アニメーション時間', '${_animationStats!['averageDuration']?.toStringAsFixed(2)}ms'),
        _buildStatRow('アクティブコントローラー', '${_animationStats!['activeControllers']}'),
        const SizedBox(height: 12),
        Row(
          children: [
          ElevatedButton.icon(
               onPressed: _startDemoAnimation,
               icon: const Icon(Icons.play_arrow),
               label: const Text('デモアニメーション'),
               style: ElevatedButton.styleFrom(
                 backgroundColor: Theme.of(context).colorScheme.primary,
                 foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                _animationService.disposeAllControllers();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('すべてのアニメーションを破棄しました')),
                );
              },
              icon: const Icon(Icons.delete),
              label: const Text('すべて破棄'),
            style: ElevatedButton.styleFrom(
                 backgroundColor: Theme.of(context).colorScheme.error,
                 foregroundColor: Theme.of(context).colorScheme.onError,
               ),
             ),
           ],
         ),
       ],
     );
    }
    
    Widget _buildMemorySection() {
     return Card(
       child: Padding(
         padding: const EdgeInsets.all(16),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             const Text(
               'メモリ最適化',
               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
             ),
             const SizedBox(height: 12),
             if (_memoryStats != null) ...[
               _buildMemoryStats(),
             ],
           ],
         ),
       ),
     );
   }
   
   Widget _buildMemoryStats() {
    return Column(
      children: [
        _buildStatRow('平均メモリ使用量', '${(_memoryStats!['averageMemoryUsage'] / 1024).toStringAsFixed(1)}KB'),
        _buildStatRow('ピークメモリ使用量', '${(_memoryStats!['peakMemoryUsage'] / 1024).toStringAsFixed(1)}KB'),
        _buildStatRow('現在メモリ使用量', '${(_memoryStats!['currentMemoryUsage'] / 1024).toStringAsFixed(1)}KB'),
        _buildStatRow('メモリ効率', '${(_memoryStats!['memoryEfficiency'] * 100).toStringAsFixed(1)}%'),
        const SizedBox(height: 12),
        Row(
          children: [
         ElevatedButton.icon(
               onPressed: _performMemoryCleanup,
               icon: const Icon(Icons.cleaning_services),
               label: const Text('メモリクリーンアップ'),
               style: ElevatedButton.styleFrom(
                 backgroundColor: Theme.of(context).colorScheme.primary,
                 foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _toggleMemoryMonitoring,
              icon: Icon(_isMemoryMonitoring ? Icons.stop : Icons.play_arrow),
              label: Text(_isMemoryMonitoring ? '監視停止' : '監視開始'),
            style: ElevatedButton.styleFrom(
                 backgroundColor: _isMemoryMonitoring ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
                 foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildMemoryChart(),
      ],
    );
  }
  
  Widget _buildMemoryChart() {
    if (_memorySnapshots == null || _memorySnapshots!.isEmpty) {
    return Container(
         height: 100,
         decoration: BoxDecoration(
           border: Border.all(color: Theme.of(context).colorScheme.outline),
           borderRadius: BorderRadius.circular(4),
         ),
         child: Center(
           child: Text(
             'メモリ使用量チャート\n(監視開始後に表示)',
             style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    
  return Container(
       height: 100,
       decoration: BoxDecoration(
         border: Border.all(color: Theme.of(context).colorScheme.outline),
         borderRadius: BorderRadius.circular(4),
       ),
       child: Center(
         child: Text(
           'メモリ使用量チャート\n(実装予定)',
           style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
  
  Widget _buildDemoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'パフォーマンスデモ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            AnimatedBuilder(
              animation: _demoAnimation,
              builder: (context, child) {
                return Container(
                  width: double.infinity,
                  height: 60,
                 decoration: BoxDecoration(
                     gradient: LinearGradient(
                       colors: [
                         Theme.of(context).colorScheme.primary.withValues(alpha: _demoAnimation.value),
                         Theme.of(context).colorScheme.tertiary.withValues(alpha: _demoAnimation.value),
                       ],
                     ),
                     borderRadius: BorderRadius.circular(8),
                   ),
                   child: Center(
                     child: Text(
                       'アニメーション進行: ${(_demoAnimation.value * 100).toStringAsFixed(0)}%',
                       style: TextStyle(
                         color: Theme.of(context).colorScheme.onTertiary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
           ElevatedButton.icon(
                   onPressed: _startDemoAnimation,
                   icon: const Icon(Icons.animation),
                   label: const Text('アニメーション実行'),
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Theme.of(context).colorScheme.tertiary,
                     foregroundColor: Theme.of(context).colorScheme.onTertiary,
                  ),
                ),
                const SizedBox(width: 8),
           ElevatedButton.icon(
                   onPressed: () {
                     _performanceService.startTimer('demo_operation');
                     Future.delayed(const Duration(milliseconds: 500), () {
                       _performanceService.stopTimer('demo_operation');
                     });
                   },
                   icon: const Icon(Icons.timer),
                   label: const Text('パフォーマンステスト'),
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Theme.of(context).colorScheme.secondary,
                     foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEventsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'パフォーマンスイベント',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_performanceEvents == null || _performanceEvents!.isEmpty)
              const Center(
                child: Text('パフォーマンスイベントがありません'),
              )
            else
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: _performanceEvents!.length,
                  itemBuilder: (context, index) {
                    final event = _performanceEvents![_performanceEvents!.length - 1 - index];
                    return _buildEventItem(event);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEventItem(PerformanceEvent event) {
    Color color;
    IconData icon;
    
  switch (event.type) {
       case 'timer':
         color = Theme.of(context).colorScheme.primary;
         icon = Icons.timer;
         break;
       default:
         color = Theme.of(context).colorScheme.onSurfaceVariant;
        icon = Icons.info;
    }
    
    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        event.key,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    subtitle: Text(
         '${event.duration.toStringAsFixed(2)}ms',
         style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
       ),
       trailing: Text(
         _formatTime(event.timestamp),
         style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      dense: true,
    );
  }
  
  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}:'
           '${dateTime.second.toString().padLeft(2, '0')}';
  }
}
