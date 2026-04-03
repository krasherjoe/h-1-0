import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';

/// パフォーマンス測定サービス
class PerformanceService {
  static PerformanceService? _instance;
  static PerformanceService get instance => _instance ??= PerformanceService._();
  
  PerformanceService._();

  final Map<String, Stopwatch> _timers = {};
  final Map<String, List<int>> _memorySnapshots = {};
  final Map<String, List<double>> _cpuSnapshots = {};
  
  /// 処理時間の計測を開始
  void startTimer(String key) {
    _timers[key] = Stopwatch()..start();
  }
  
  /// 処理時間の計測を停止
  void stopTimer(String key) {
    final timer = _timers[key];
    if (timer != null && timer.isRunning) {
      timer.stop();
      debugPrint('Performance: $key took ${timer.elapsedMilliseconds}ms');
    }
  }
  
  /// 計測結果を取得
  Duration? getElapsedTime(String key) {
    return _timers[key]?.elapsed;
  }
  
  /// メモリ使用量を記録
  void recordMemoryUsage(String key) {
    final memoryUsage = getCurrentMemoryUsage();
    _memorySnapshots[key] ??= [];
    _memorySnapshots[key]!.add(memoryUsage);
    debugPrint('Memory: $key - ${memoryUsage} bytes');
  }
  
  /// CPU使用率を記録
  void recordCpuUsage(String key) {
    final cpuUsage = getCurrentCpuUsage();
    _cpuSnapshots[key] ??= [];
    _cpuSnapshots[key]!.add(cpuUsage);
    debugPrint('CPU: $key - ${cpuUsage.toStringAsFixed(1)}%');
  }
  
  /// 現在のメモリ使用量を取得
  int getCurrentMemoryUsage() {
    // 実際の実装ではプラットフォーム固有のAPIを使用
    return 0; // プレースホルダー
  }
  
  /// 現在のCPU使用率を取得
  double getCurrentCpuUsage() {
    // 実際の実装ではプラットフォーム固有のAPIを使用
    return 0.0; // プレースホルダー
  }
  
  /// パフォーマンスレポートを生成
  Map<String, dynamic> generateReport() {
    final report = <String, dynamic>{};
    
    // タイマー結果
    for (final entry in _timers.entries) {
      report['timer_${entry.key}'] = entry.value.elapsedMilliseconds;
    }
    
    // メモリ使用量統計
    for (final entry in _memorySnapshots.entries) {
      if (entry.value.isNotEmpty) {
        final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
        final max = entry.value.reduce((a, b) => a > b ? a : b);
        final min = entry.value.reduce((a, b) => a < b ? a : b);
        
        report['memory_${entry.key}'] = {
          'average': avg,
          'max': max,
          'min': min,
          'samples': entry.value.length,
        };
      }
    }
    
    // CPU使用率統計
    for (final entry in _cpuSnapshots.entries) {
      if (entry.value.isNotEmpty) {
        final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
        final max = entry.value.reduce((a, b) => a > b ? a : b);
        final min = entry.value.reduce((a, b) => a < b ? a : b);
        
        report['cpu_${entry.key}'] = {
          'average': avg,
          'max': max,
          'min': min,
          'samples': entry.value.length,
        };
      }
    }
    
    return report;
  }
  
  /// 計測データをクリア
  void clear() {
    _timers.clear();
    _memorySnapshots.clear();
    _cpuSnapshots.clear();
  }
  
  /// ボトルネックを分析
  List<String> analyzeBottlenecks() {
    final bottlenecks = <String>[];
    
    // 遅い処理を特定
    for (final entry in _timers.entries) {
      if (entry.value.elapsedMilliseconds > 1000) { // 1秒以上
        bottlenecks.add('Slow operation: ${entry.key} (${entry.value.elapsedMilliseconds}ms)');
      }
    }
    
    // メモリ使用量が多い処理を特定
    for (final entry in _memorySnapshots.entries) {
      if (entry.value.isNotEmpty) {
        final max = entry.value.reduce((a, b) => a > b ? a : b);
        if (max > 100 * 1024 * 1024) { // 100MB以上
          bottlenecks.add('High memory usage: ${entry.key} (${max} bytes)');
        }
      }
    }
    
    return bottlenecks;
  }
}

/// Isolateタスク管理サービス
class IsolateService {
  static IsolateService? _instance;
  static IsolateService get instance => _instance ??= IsolateService._();
  
  IsolateService._();
  
  final Map<String, Isolate> _isolates = {};
  final Map<String, ReceivePort> _receivePorts = {};
  
  /// 重い処理をIsolateで実行
  Future<T> runInIsolate<T, P>(
    String taskName,
    Future<T> Function(P) function,
    P parameter, {
    Duration? timeout,
  }) async {
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(
      _isolateEntry<T, P>,
      _IsolateTaskData<T, P>(
        taskName: taskName,
        function: function,
        parameter: parameter,
        sendPort: receivePort.sendPort,
      ),
      debugName: taskName,
    );
    
    _isolates[taskName] = isolate;
    _receivePorts[taskName] = receivePort;
    
    try {
      final result = await receivePort.first.timeout(
        timeout ?? const Duration(minutes: 5),
      );
      
      if (result is Exception) {
        throw result;
      }
      
      return result as T;
    } finally {
      await _cleanupIsolate(taskName);
    }
  }
  
  /// Isolateのエントリーポイント
  static void _isolateEntry<T, P>(_IsolateTaskData<T, P> data) async {
    try {
      final result = await data.function(data.parameter);
      data.sendPort.send(result);
    } catch (e) {
      data.sendPort.send(e as Exception);
    }
  }
  
  /// Isolateをクリーンアップ
  Future<void> _cleanupIsolate(String taskName) async {
    final isolate = _isolates[taskName];
    final receivePort = _receivePorts[taskName];
    
    if (isolate != null) {
      isolate.kill(priority: Isolate.immediate);
      _isolates.remove(taskName);
    }
    
    if (receivePort != null) {
      receivePort.close();
      _receivePorts.remove(taskName);
    }
  }
  
  /// すべてのIsolateをクリーンアップ
  Future<void> cleanupAll() async {
    for (final taskName in _isolates.keys.toList()) {
      await _cleanupIsolate(taskName);
    }
  }
  
  /// アクティブなIsolateの数を取得
  int get activeIsolateCount => _isolates.length;
}

/// Isolateタスクデータ
class _IsolateTaskData<T, P> {
  final String taskName;
  final Future<T> Function(P) function;
  final P parameter;
  final SendPort sendPort;
  
  _IsolateTaskData({
    required this.taskName,
    required this.function,
    required this.parameter,
    required this.sendPort,
  });
}

/// バックグラウンドタスクサービス
class BackgroundTaskService {
  static BackgroundTaskService? _instance;
  static BackgroundTaskService get instance => _instance ??= BackgroundTaskService._();
  
  BackgroundTaskService._();
  
  final List<Future<void> Function()> _taskQueue = [];
  bool _isProcessing = false;
  
  /// バックグラウンドタスクを追加
  void addTask(Future<void> Function() task) {
    _taskQueue.add(task);
    _processQueue();
  }
  
  /// タスクキューを処理
  Future<void> _processQueue() async {
    if (_isProcessing || _taskQueue.isEmpty) return;
    
    _isProcessing = true;
    
    while (_taskQueue.isNotEmpty) {
      final task = _taskQueue.removeAt(0);
      
      try {
        await task();
      } catch (e) {
        debugPrint('Background task failed: $e');
      }
    }
    
    _isProcessing = false;
  }
  
  /// キューが空かどうかを確認
  bool get isQueueEmpty => _taskQueue.isEmpty;
  
  /// 処理中かどうかを確認
  bool get isProcessing => _isProcessing;
}

/// パフォーマンス最適化ユーティリティ
class PerformanceOptimizer {
  /// 画像を最適化
  static Future<Uint8List> optimizeImage(
    Uint8List imageBytes, {
    int maxWidth = 1024,
    int maxHeight = 1024,
    int quality = 85,
  }) async {
    // 実際の実装では画像処理ライブラリを使用
    // ここではプレースホルダーとして元のデータを返す
    return imageBytes;
  }
  
  /// リストをバッチ処理
  static Future<List<T>> processBatch<T, P>(
    List<P> items,
    Future<T> Function(P) processor, {
    int batchSize = 10,
  }) async {
    final results = <T>[];
    
    for (int i = 0; i < items.length; i += batchSize) {
      final batch = items.skip(i).take(batchSize).toList();
      final batchResults = await Future.wait(
        batch.map(processor),
      );
      results.addAll(batchResults);
    }
    
    return results;
  }
  
  /// メモリ使用量を監視
  static void monitorMemoryUsage() {
    final memoryUsage = PerformanceService.instance.getCurrentMemoryUsage();
    if (memoryUsage > 500 * 1024 * 1024) { // 500MB以上
      debugPrint('Warning: High memory usage detected: ${memoryUsage} bytes');
    }
  }
  
  /// キャッシュをクリア
  static void clearCache() {
    // 実際の実装ではキャッシュをクリアする処理
    // PaintingBinding.instance.imageCache.clear();
  }
  
  /// 不要なリソースを解放
  static void releaseResources() {
    clearCache();
    // その他のリソース解放処理
  }
}
