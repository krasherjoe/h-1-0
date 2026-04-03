import 'dart:async';
import 'package:flutter/material.dart';

/// UIパフォーマンス最適化サービス
class UIPerformanceService {
  static UIPerformanceService? _instance;
  static UIPerformanceService get instance => _instance ??= UIPerformanceService._();
  
  UIPerformanceService._();
  
  final Map<String, Stopwatch> _performanceTimers = {};
  final List<FrameMetrics> _frameMetrics = [];
  final Map<String, double> _renderTimes = {};
  final Map<String, int> _widgetCounts = {};
  final List<PerformanceEvent> _performanceEvents = [];
  
  /// パフォーマンス監視を開始
  void startPerformanceMonitoring() {
    // フレームレート監視
    WidgetsBinding.instance.addPostFrameCallback(_onFrameEnd);
    
    // レンダリングパフォーマンス監視
    _startRenderPerformanceMonitoring();
    
    debugPrint('UIパフォーマンス監視を開始しました');
  }
  
  /// フレーム終了時のコールバック
  void _onFrameEnd(Duration timestamp) {
    final frameMetrics = FrameMetrics(
      timestamp: DateTime.now(),
      frameTime: timestamp.inMicroseconds.toDouble(),
    );
    
    _frameMetrics.add(frameMetrics);
    
    // フレームメトリクスのサイズ制限
    if (_frameMetrics.length > 1000) {
      _frameMetrics.removeAt(0);
    }
    
    // 次のフレームを監視
    WidgetsBinding.instance.addPostFrameCallback(_onFrameEnd);
  }
  
  /// レンダリングパフォーマンス監視を開始
  void _startRenderPerformanceMonitoring() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      _collectRenderMetrics();
    });
  }
  
  /// レンダリングメトリクスを収集
  void _collectRenderMetrics() {
    // 実際の実装ではレンダリング時間を測定
    // ここではシミュレーション
    final renderTime = 16.0 + (DateTime.now().millisecond % 10);
    _renderTimes['main'] = renderTime;
    
    // ウィジェット数をカウント（シミュレーション）
    final widgetCount = 100 + (DateTime.now().millisecond % 50);
    _widgetCounts['main'] = widgetCount;
  }
  
  /// パフォーマンスタイマーを開始
  void startTimer(String key) {
    _performanceTimers[key] = Stopwatch()..start();
  }
  
  /// パフォーマンスタイマーを停止
  void stopTimer(String key) {
    final timer = _performanceTimers[key];
    if (timer != null && timer.isRunning) {
      timer.stop();
      
      final event = PerformanceEvent(
        type: 'timer',
        key: key,
        duration: timer.elapsedMilliseconds.toDouble(),
        timestamp: DateTime.now(),
      );
      
      _performanceEvents.add(event);
      
      // イベント履歴のサイズ制限
      if (_performanceEvents.length > 500) {
        _performanceEvents.removeAt(0);
      }
      
      debugPrint('パフォーマンスタイマー $key: ${timer.elapsedMilliseconds}ms');
    }
  }
  
  /// ウィジェットレンダリング時間を測定
  Future<T> measureWidgetRenderTime<T>(
    String widgetName,
    Future<T> Function() widgetBuilder,
  ) async {
    startTimer(widgetName);
    
    try {
      final result = await widgetBuilder();
      return result;
    } finally {
      stopTimer(widgetName);
    }
  }
  
  /// パフォーマンス統計を取得
  Map<String, dynamic> getPerformanceStatistics() {
    if (_frameMetrics.isEmpty) {
      return {
        'averageFrameTime': 0.0,
        'worstFrameTime': 0.0,
        'bestFrameTime': 0.0,
        'frameDropCount': 0,
        'averageRenderTime': 0.0,
        'widgetCount': 0,
        'eventCount': _performanceEvents.length,
      };
    }
    
    final frameTimes = _frameMetrics.map((m) => m.frameTime).toList();
    frameTimes.sort();
    
    final averageFrameTime = frameTimes.reduce((a, b) => a + b) / frameTimes.length;
    final worstFrameTime = frameTimes.last;
    final bestFrameTime = frameTimes.first;
    
    // フレームドロップを計算（16.67msを超えるフレーム）
    final frameDropCount = frameTimes.where((time) => time > 16670).length;
    
    final averageRenderTime = _renderTimes.values.isEmpty 
        ? 0.0 
        : _renderTimes.values.reduce((a, b) => a + b) / _renderTimes.values.length;
    
    final totalWidgetCount = _widgetCounts.values.isEmpty 
        ? 0 
        : _widgetCounts.values.reduce((a, b) => a + b);
    
    return {
      'averageFrameTime': averageFrameTime,
      'worstFrameTime': worstFrameTime,
      'bestFrameTime': bestFrameTime,
      'frameDropCount': frameDropCount,
      'frameDropRate': frameDropCount / frameTimes.length,
      'averageRenderTime': averageRenderTime,
      'widgetCount': totalWidgetCount,
      'eventCount': _performanceEvents.length,
      'totalEvents': _performanceEvents.length,
    };
  }
  
  /// パフォーマンスイベントを取得
  List<PerformanceEvent> getPerformanceEvents() => List.unmodifiable(_performanceEvents);
  
  /// フレームメトリクスを取得
  List<FrameMetrics> getFrameMetrics() => List.unmodifiable(_frameMetrics);
  
  /// パフォーマンスレポートを生成
  String generatePerformanceReport() {
    final stats = getPerformanceStatistics();
    final buffer = StringBuffer();
    
    buffer.writeln('=== UIパフォーマンスレポート ===');
    buffer.writeln('生成時刻: ${DateTime.now().toIso8601String()}');
    buffer.writeln('');
    
    buffer.writeln('フレームパフォーマンス:');
    buffer.writeln('  平均フレーム時間: ${stats['averageFrameTime']?.toStringAsFixed(2)}μs');
    buffer.writeln('  最悪フレーム時間: ${stats['worstFrameTime']?.toStringAsFixed(2)}μs');
    buffer.writeln('  最高フレーム時間: ${stats['bestFrameTime']?.toStringAsFixed(2)}μs');
    buffer.writeln('  フレームドロップ数: ${stats['frameDropCount']}');
    buffer.writeln('  フレームドロップ率: ${(stats['frameDropRate'] * 100).toStringAsFixed(2)}%');
    buffer.writeln('');
    
    buffer.writeln('レンダリングパフォーマンス:');
    buffer.writeln('  平均レンダリング時間: ${stats['averageRenderTime']?.toStringAsFixed(2)}ms');
    buffer.writeln('  ウィジェット数: ${stats['widgetCount']}');
    buffer.writeln('');
    
    buffer.writeln('イベント統計:');
    buffer.writeln('  総イベント数: ${stats['eventCount']}');
    
    return buffer.toString();
  }
  
  /// パフォーマンス警告をチェック
  List<String> checkPerformanceWarnings() {
    final warnings = <String>[];
    final stats = getPerformanceStatistics();
    
    if (stats['averageFrameTime'] > 16670) {
      warnings.add('平均フレーム時間が60fpsを下回っています');
    }
    
    if (stats['frameDropRate'] > 0.1) {
      warnings.add('フレームドロップ率が10%を超えています');
    }
    
    if (stats['averageRenderTime'] > 16.0) {
      warnings.add('平均レンダリング時間が16msを超えています');
    }
    
    if (stats['widgetCount'] > 500) {
      warnings.add('ウィジェット数が500を超えています');
    }
    
    return warnings;
  }
}

/// フレームメトリクスクラス
class FrameMetrics {
  final DateTime timestamp;
  final double frameTime;
  
  FrameMetrics({
    required this.timestamp,
    required this.frameTime,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'frameTime': frameTime,
    };
  }
}

/// パフォーマンスイベントクラス
class PerformanceEvent {
  final String type;
  final String key;
  final double duration;
  final DateTime timestamp;
  
  PerformanceEvent({
    required this.type,
    required this.key,
    required this.duration,
    required this.timestamp,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'key': key,
      'duration': duration,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// アニメーション最適化サービス
class AnimationOptimizationService {
  static AnimationOptimizationService? _instance;
  static AnimationOptimizationService get instance => _instance ??= AnimationOptimizationService._();
  
  AnimationOptimizationService._();
  
  final Map<String, AnimationController> _controllers = {};
  final List<AnimationMetrics> _animationMetrics = [];
  
  /// 最適化されたアニメーションコントローラーを作成
  AnimationController createOptimizedController({
    required String name,
    required TickerProvider vsync,
    Duration duration = const Duration(milliseconds: 300),
    String? debugLabel,
  }) {
    final controller = AnimationController(
      duration: duration,
      vsync: vsync,
      debugLabel: debugLabel ?? name,
    );
    
    _controllers[name] = controller;
    
    // パフォーマンス監視
    controller.addListener(() {
      _trackAnimationPerformance(name, controller);
    });
    
    return controller;
  }
  
  /// アニメーションパフォーマンスを追跡
  void _trackAnimationPerformance(String name, AnimationController controller) {
    if (controller.status == AnimationStatus.completed ||
        controller.status == AnimationStatus.dismissed) {
      
      final metrics = AnimationMetrics(
        name: name,
        duration: controller.duration!.inMilliseconds.toDouble(),
        actualDuration: DateTime.now().millisecondsSinceEpoch.toDouble(),
        status: controller.status.toString(),
      );
      
      _animationMetrics.add(metrics);
      
      // メトリクスのサイズ制限
      if (_animationMetrics.length > 100) {
        _animationMetrics.removeAt(0);
      }
    }
  }
  
  /// アニメーションコントローラーを取得
  AnimationController? getController(String name) {
    return _controllers[name];
  }
  
  /// すべてのアニメーションコントローラーを破棄
  void disposeAllControllers() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    debugPrint('すべてのアニメーションコントローラーを破棄しました');
  }
  
  /// アニメーションメトリクスを取得
  List<AnimationMetrics> getAnimationMetrics() => List.unmodifiable(_animationMetrics);
  
  /// アニメーション統計を取得
  Map<String, dynamic> getAnimationStatistics() {
    if (_animationMetrics.isEmpty) {
      return {
        'totalAnimations': 0,
        'averageDuration': 0.0,
        'activeControllers': _controllers.length,
      };
    }
    
    final durations = _animationMetrics.map((m) => m.duration).toList();
    final averageDuration = durations.reduce((a, b) => a + b) / durations.length;
    
    return {
      'totalAnimations': _animationMetrics.length,
      'averageDuration': averageDuration,
      'activeControllers': _controllers.length,
    };
  }
}

/// アニメーションメトリクスクラス
class AnimationMetrics {
  final String name;
  final double duration;
  final double actualDuration;
  final String status;
  
  AnimationMetrics({
    required this.name,
    required this.duration,
    required this.actualDuration,
    required this.status,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'duration': duration,
      'actualDuration': actualDuration,
      'status': status,
    };
  }
}

/// メモリ最適化サービス
class MemoryOptimizationService {
  static MemoryOptimizationService? _instance;
  static MemoryOptimizationService get instance => _instance ??= MemoryOptimizationService._();
  
  MemoryOptimizationService._();
  
  final List<MemorySnapshot> _memorySnapshots = [];
  Timer? _memoryMonitorTimer;
  
  /// メモリ監視を開始
  void startMemoryMonitoring({Duration interval = const Duration(seconds: 5)}) {
    _memoryMonitorTimer = Timer.periodic(interval, (_) {
      _captureMemorySnapshot();
    });
    
    debugPrint('メモリ監視を開始しました');
  }
  
  /// メモリ監視を停止
  void stopMemoryMonitoring() {
    _memoryMonitorTimer?.cancel();
    _memoryMonitorTimer = null;
    debugPrint('メモリ監視を停止しました');
  }
  
  /// メモリスナップショットを取得
  void _captureMemorySnapshot() {
    // 実際の実装ではメモリ使用量を取得
    // ここではシミュレーション
    final totalMemory = 100000 + (DateTime.now().millisecond * 100);
    final usedMemory = totalMemory ~/ 2 + (DateTime.now().millisecond % 10000);
    
    final snapshot = MemorySnapshot(
      timestamp: DateTime.now(),
      totalMemory: totalMemory,
      usedMemory: usedMemory,
      freeMemory: totalMemory - usedMemory,
    );
    
    _memorySnapshots.add(snapshot);
    
    // スナップショットのサイズ制限
    if (_memorySnapshots.length > 200) {
      _memorySnapshots.removeAt(0);
    }
  }
  
  /// 手動メモリクリーンアップ
  Future<void> performMemoryCleanup() async {
    // 画像キャッシュをクリア
    PaintingBinding.instance.imageCache.clear();
    
    // ガベージコレクションを促進
    await Future.delayed(const Duration(milliseconds: 100));
    
    debugPrint('メモリクリーンアップを実行しました');
  }
  
  /// メモリ統計を取得
  Map<String, dynamic> getMemoryStatistics() {
    if (_memorySnapshots.isEmpty) {
      return {
        'averageMemoryUsage': 0,
        'peakMemoryUsage': 0,
        'currentMemoryUsage': 0,
        'memoryEfficiency': 0.0,
      };
    }
    
    final memoryUsages = _memorySnapshots.map((s) => s.usedMemory).toList();
    memoryUsages.sort();
    
    final averageUsage = memoryUsages.reduce((a, b) => a + b) / memoryUsages.length;
    final peakUsage = memoryUsages.last;
    final currentUsage = _memorySnapshots.last.usedMemory;
    final totalMemory = _memorySnapshots.last.totalMemory;
    
    return {
      'averageMemoryUsage': averageUsage,
      'peakMemoryUsage': peakUsage,
      'currentMemoryUsage': currentUsage,
      'memoryEfficiency': (totalMemory - currentUsage) / totalMemory,
      'totalMemory': totalMemory,
    };
  }
  
  /// メモリスナップショットを取得
  List<MemorySnapshot> getMemorySnapshots() => List.unmodifiable(_memorySnapshots);
  
  /// メモリ警告をチェック
  List<String> checkMemoryWarnings() {
    final warnings = <String>[];
    final stats = getMemoryStatistics();
    
    if (stats['memoryEfficiency'] < 0.2) {
      warnings.add('メモリ使用率が80%を超えています');
    }
    
    if (stats['currentMemoryUsage'] > stats['peakMemoryUsage'] * 0.9) {
      warnings.add('現在のメモリ使用量がピークに近いです');
    }
    
    return warnings;
  }
}

/// メモリスナップショットクラス
class MemorySnapshot {
  final DateTime timestamp;
  final int totalMemory;
  final int usedMemory;
  final int freeMemory;
  
  MemorySnapshot({
    required this.timestamp,
    required this.totalMemory,
    required this.usedMemory,
    required this.freeMemory,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'totalMemory': totalMemory,
      'usedMemory': usedMemory,
      'freeMemory': freeMemory,
    };
  }
}
