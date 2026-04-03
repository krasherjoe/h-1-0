import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// 拡張音声サービス
class EnhancedAudioService {
  static EnhancedAudioService? _instance;
  static EnhancedAudioService get instance => _instance ??= EnhancedAudioService._();
  
  EnhancedAudioService._();
  
  bool _isRecording = false;
  String? _currentRecordingPath;
  final List<AudioRecording> _recordings = [];
  final List<AudioEvent> _audioEvents = [];
  final Map<String, dynamic> _audioSettings = {
    'sampleRate': 44100,
    'bitRate': 128000,
    'channels': 1,
    'format': 'wav',
    'maxRecordingDuration': const Duration(minutes: 30),
    'enableNoiseReduction': true,
    'enableVoiceActivation': false,
    'voiceActivationThreshold': -40.0,
  };
  
  /// マイク権限を確認
  Future<bool> checkMicrophonePermission() async {
    final permission = await Permission.microphone.status;
    return permission.isGranted;
  }
  
  /// マイク権限をリクエスト
  Future<bool> requestMicrophonePermission() async {
    final permission = await Permission.microphone.request();
    return permission.isGranted;
  }
  
  /// 録音を開始（拡張機能付き）
  Future<String> startRecording({
    int sampleRate = 44100,
    int bitRate = 128000,
    int channels = 1,
    String format = 'wav',
    Duration? maxDuration,
    bool enableNoiseReduction = true,
    bool enableVoiceActivation = false,
    double voiceActivationThreshold = -40.0,
  }) async {
    if (!await checkMicrophonePermission()) {
      if (!await requestMicrophonePermission()) {
        throw Exception('マイク権限が拒否されました');
      }
    }
    
    if (_isRecording) {
      throw Exception('すでに録音中です');
    }
    
    // 設定を更新
    _audioSettings.updateAll((key, value) {
      switch (key) {
        case 'sampleRate':
          return sampleRate;
        case 'bitRate':
          return bitRate;
        case 'channels':
          return channels;
        case 'format':
          return format;
        case 'maxRecordingDuration':
          return maxDuration ?? _audioSettings['maxRecordingDuration'];
        case 'enableNoiseReduction':
          return enableNoiseReduction;
        case 'enableVoiceActivation':
          return enableVoiceActivation;
        case 'voiceActivationThreshold':
          return voiceActivationThreshold;
        default:
          return value;
      }
    });
    
    try {
      // 録音ファイルのパスを生成
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '/tmp/recording_${timestamp}.${format}';
      
      // 実際の録音処理（ここではシミュレーション）
      _isRecording = true;
      
      final recording = AudioRecording(
        id: timestamp.toString(),
        filePath: _currentRecordingPath!,
        startTime: DateTime.now(),
        sampleRate: sampleRate,
        bitRate: bitRate,
        channels: channels,
        format: format,
        enableNoiseReduction: enableNoiseReduction,
        enableVoiceActivation: enableVoiceActivation,
        voiceActivationThreshold: voiceActivationThreshold,
      );
      
      _recordings.add(recording);
      _addAudioEvent(AudioEvent.recordingStart('録音開始', recording.id));
      
      debugPrint('録音開始: $_currentRecordingPath');
      
      // 最大録音時間のタイマーを設定
      final maxDurationSetting = _audioSettings['maxRecordingDuration'] as Duration;
      Timer(maxDurationSetting, () {
        if (_isRecording) {
          stopRecording();
        }
      });
      
      // 音声アクティベーションのシミュレーション
      if (enableVoiceActivation) {
        _simulateVoiceActivation(recording);
      }
      
      return _currentRecordingPath!;
    } catch (e) {
      debugPrint('録音開始エラー: $e');
      rethrow;
    }
  }
  
  /// 録音を停止
  Future<AudioRecording?> stopRecording() async {
    if (!_isRecording) {
      throw Exception('録音中ではありません');
    }
    
    try {
      // 実際の録音停止処理（ここではシミュレーション）
      _isRecording = false;
      
      final recording = _recordings.lastWhere((r) => r.endTime == null);
      recording.endTime = DateTime.now();
      recording.duration = recording.endTime!.difference(recording.startTime);
      recording.fileSize = await _getFileSize(recording.filePath);
      
      _addAudioEvent(AudioEvent.recordingStop('録音停止', recording.id));
      
      debugPrint('録音停止: ${recording.filePath}');
      debugPrint('録音時間: ${recording.duration?.inSeconds}秒');
      
      return recording;
    } catch (e) {
      debugPrint('録音停止エラー: $e');
      rethrow;
    }
  }
  
  /// 音声アクティベーションのシミュレーション
  void _simulateVoiceActivation(AudioRecording recording) {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }
      
      // 音声レベルのシミュレーション（実際にはマイクから取得）
      final simulatedLevel = -60.0 + (DateTime.now().millisecond % 40);
      final threshold = _audioSettings['voiceActivationThreshold'] as double;
      
      if (simulatedLevel > threshold) {
        _addAudioEvent(AudioEvent.voiceActivation(
          '音声検出',
          recording.id,
          simulatedLevel,
        ));
      }
    });
  }
  
  /// ファイルサイズを取得
  Future<int> _getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (e) {
      debugPrint('ファイルサイズ取得エラー: $e');
    }
    return 0;
  }
  
  /// 音声イベントを追加
  void _addAudioEvent(AudioEvent event) {
    _audioEvents.add(event);
    
    // イベント履歴のサイズ制限
    if (_audioEvents.length > 500) {
      _audioEvents.removeAt(0);
    }
  }
  
  /// 録音中かどうかを確認
  bool get isRecording => _isRecording;
  
  /// 現在の録音ファイルパスを取得
  String? get currentRecordingPath => _currentRecordingPath;
  
  /// すべての録音を取得
  List<AudioRecording> getRecordings() => List.unmodifiable(_recordings);
  
  /// 音声イベントを取得
  List<AudioEvent> getAudioEvents() => List.unmodifiable(_audioEvents);
  
  /// 指定した録音を削除
  Future<void> deleteRecording(String recordingId) async {
    try {
      final recording = _recordings.firstWhere((r) => r.id == recordingId);
      final file = File(recording.filePath);
      
      if (await file.exists()) {
        await file.delete();
      }
      
      _recordings.removeWhere((r) => r.id == recordingId);
      _addAudioEvent(AudioEvent.info('録音削除', recordingId));
      
      debugPrint('録音を削除: $recordingId');
    } catch (e) {
      debugPrint('録音削除エラー: $e');
      rethrow;
    }
  }
  
  /// 音声統計を取得
  Map<String, dynamic> getAudioStatistics() {
    if (_recordings.isEmpty) {
      return {
        'totalRecordings': 0,
        'totalDuration': 0,
        'averageDuration': 0,
        'totalFileSize': 0,
        'averageFileSize': 0,
        'eventCount': _audioEvents.length,
      };
    }
    
    final completedRecordings = _recordings.where((r) => r.endTime != null).toList();
    final totalDuration = completedRecordings.fold<Duration>(
      Duration.zero,
      (sum, recording) => sum + (recording.duration ?? Duration.zero),
    );
    
    final totalFileSize = completedRecordings.fold<int>(
      0,
      (sum, recording) => sum + (recording.fileSize ?? 0),
    );
    
    return {
      'totalRecordings': _recordings.length,
      'completedRecordings': completedRecordings.length,
      'totalDuration': totalDuration.inSeconds,
      'averageDuration': completedRecordings.isEmpty 
          ? 0 
          : (totalDuration.inSeconds / completedRecordings.length).round(),
      'totalFileSize': totalFileSize,
      'averageFileSize': completedRecordings.isEmpty 
          ? 0 
          : (totalFileSize / completedRecordings.length).round(),
      'eventCount': _audioEvents.length,
      'firstRecordingTime': _recordings.first.startTime.toIso8601String(),
      'lastRecordingTime': _recordings.last.startTime.toIso8601String(),
    };
  }
  
  /// 音声設定を更新
  void updateSettings(Map<String, dynamic> newSettings) {
    _audioSettings.addAll(newSettings);
    debugPrint('音声設定を更新: $newSettings');
  }
  
  /// 現在の設定を取得
  Map<String, dynamic> getSettings() => Map.unmodifiable(_audioSettings);
  
  /// 音声データをエクスポート
  Future<String> exportAudioData() async {
    final buffer = StringBuffer();
    buffer.writeln('id,filePath,startTime,endTime,duration,fileSize,sampleRate,bitRate,channels,format');
    
    for (final recording in _recordings) {
      buffer.writeln(
        '${recording.id},'
        '${recording.filePath},'
        '${recording.startTime.toIso8601String()},'
        '${recording.endTime?.toIso8601String() ?? ''},'
        '${recording.duration?.inSeconds ?? 0},'
        '${recording.fileSize ?? 0},'
        '${recording.sampleRate},'
        '${recording.bitRate},'
        '${recording.channels},'
        '${recording.format}',
      );
    }
    
    return buffer.toString();
  }
}

/// 録音データクラス
class AudioRecording {
  final String id;
  final String filePath;
  final DateTime startTime;
  DateTime? endTime;
  Duration? duration;
  int? fileSize;
  final int sampleRate;
  final int bitRate;
  final int channels;
  final String format;
  final bool enableNoiseReduction;
  final bool enableVoiceActivation;
  final double voiceActivationThreshold;
  final Map<String, dynamic>? metadata;
  
  AudioRecording({
    required this.id,
    required this.filePath,
    required this.startTime,
    this.endTime,
    this.duration,
    this.fileSize,
    required this.sampleRate,
    required this.bitRate,
    required this.channels,
    required this.format,
    required this.enableNoiseReduction,
    required this.enableVoiceActivation,
    required this.voiceActivationThreshold,
    this.metadata,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filePath': filePath,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'duration': duration?.inSeconds,
      'fileSize': fileSize,
      'sampleRate': sampleRate,
      'bitRate': bitRate,
      'channels': channels,
      'format': format,
      'enableNoiseReduction': enableNoiseReduction,
      'enableVoiceActivation': enableVoiceActivation,
      'voiceActivationThreshold': voiceActivationThreshold,
      if (metadata != null) 'metadata': metadata,
    };
  }
}

/// 音声イベントクラス
class AudioEvent {
  final String type;
  final String message;
  final DateTime timestamp;
  final String? recordingId;
  final Map<String, dynamic>? data;
  
  AudioEvent(this.type, this.message, {this.recordingId, this.data}) : timestamp = DateTime.now();
  
  factory AudioEvent.info(String message, [String? recordingId]) {
    return AudioEvent('info', message, recordingId: recordingId);
  }
  
  factory AudioEvent.warning(String message, [String? recordingId]) {
    return AudioEvent('warning', message, recordingId: recordingId);
  }
  
  factory AudioEvent.error(String message, [String? recordingId]) {
    return AudioEvent('error', message, recordingId: recordingId);
  }
  
  factory AudioEvent.recordingStart(String message, String recordingId) {
    return AudioEvent('recording_start', message, recordingId: recordingId);
  }
  
  factory AudioEvent.recordingStop(String message, String recordingId) {
    return AudioEvent('recording_stop', message, recordingId: recordingId);
  }
  
  factory AudioEvent.voiceActivation(String message, String recordingId, double level) {
    return AudioEvent('voice_activation', message, recordingId: recordingId, data: {'level': level});
  }
  
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      if (recordingId != null) 'recordingId': recordingId,
      if (data != null) 'data': data,
    };
  }
}

/// 音声処理サービス
class AudioProcessingService {
  static AudioProcessingService? _instance;
  static AudioProcessingService get instance => _instance ??= AudioProcessingService._();
  
  AudioProcessingService._();
  
  /// 音声レベルを測定
  Future<double> measureAudioLevel(String filePath) async {
    // 実際の実装では音声ファイルからレベルを測定
    // ここではシミュレーション
    await Future.delayed(const Duration(milliseconds: 100));
    return -30.0 + (DateTime.now().millisecond % 50);
  }
  
  /// 音声をノイズリダクション
  Future<String> applyNoiseReduction(String inputPath, String outputPath) async {
    // 実際の実装ではノイズリダクションアルゴリズムを適用
    // ここではシミュレーション
    await Future.delayed(const Duration(seconds: 2));
    
    final inputFile = File(inputPath);
    final outputFile = File(outputPath);
    
    if (await inputFile.exists()) {
      await inputFile.copy(outputPath);
    }
    
    debugPrint('ノイズリダクション適用: $inputPath -> $outputPath');
    return outputPath;
  }
  
  /// 音声フォーマットを変換
  Future<String> convertAudioFormat(
    String inputPath,
    String outputPath,
    String targetFormat,
  ) async {
    // 実際の実装では音声フォーマット変換を行う
    // ここではシミュレーション
    await Future.delayed(const Duration(seconds: 1));
    
    final inputFile = File(inputPath);
    final outputFile = File(outputPath);
    
    if (await inputFile.exists()) {
      await inputFile.copy(outputPath);
    }
    
    debugPrint('音声フォーマット変換: $inputPath -> $outputPath ($targetFormat)');
    return outputPath;
  }
  
  /// 音声をトリミング
  Future<String> trimAudio(
    String inputPath,
    String outputPath,
    Duration startTime,
    Duration endTime,
  ) async {
    // 実際の実装では音声トリミングを行う
    // ここではシミュレーション
    await Future.delayed(const Duration(seconds: 1));
    
    final inputFile = File(inputPath);
    final outputFile = File(outputPath);
    
    if (await inputFile.exists()) {
      await inputFile.copy(outputPath);
    }
    
    debugPrint('音声トリミング: $inputPath -> $outputPath (${startTime}-${endTime})');
    return outputPath;
  }
  
  /// 音声品質を評価
  Future<AudioQualityMetrics> evaluateAudioQuality(String filePath) async {
    // 実際の実装では音声品質分析を行う
    // ここではシミュレーション
    await Future.delayed(const Duration(milliseconds: 500));
    
    return AudioQualityMetrics(
      signalToNoiseRatio: 25.0 + (DateTime.now().millisecond % 20),
      peakLevel: -3.0 - (DateTime.now().millisecond % 10),
      averageLevel: -20.0 - (DateTime.now().millisecond % 15),
      dynamicRange: 40.0 + (DateTime.now().millisecond % 20),
      distortion: 0.01 + (DateTime.now().millisecond % 5) / 1000,
      overallQuality: _calculateOverallQuality(),
    );
  }
  
  /// 総合品質を計算
  double _calculateOverallQuality() {
    // 簡易的な品質計算
    return 0.8 + (DateTime.now().millisecond % 20) / 100.0;
  }
}

/// 音声品質指標クラス
class AudioQualityMetrics {
  final double signalToNoiseRatio;
  final double peakLevel;
  final double averageLevel;
  final double dynamicRange;
  final double distortion;
  final double overallQuality;
  
  AudioQualityMetrics({
    required this.signalToNoiseRatio,
    required this.peakLevel,
    required this.averageLevel,
    required this.dynamicRange,
    required this.distortion,
    required this.overallQuality,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'signalToNoiseRatio': signalToNoiseRatio,
      'peakLevel': peakLevel,
      'averageLevel': averageLevel,
      'dynamicRange': dynamicRange,
      'distortion': distortion,
      'overallQuality': overallQuality,
    };
  }
}
