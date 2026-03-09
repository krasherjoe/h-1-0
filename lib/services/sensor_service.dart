import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// センサー活用サービス
class SensorService {
  static SensorService? _instance;
  static SensorService get instance => _instance ??= SensorService._();
  
  SensorService._();
  
  StreamSubscription<Position>? _positionStream;
  Position? _currentPosition;
  final List<Position> _positionHistory = [];
  
  /// 位置情報権限を確認
  Future<bool> checkLocationPermission() async {
    final permission = await Permission.location.status;
    return permission.isGranted;
  }
  
  /// 位置情報権限をリクエスト
  Future<bool> requestLocationPermission() async {
    final permission = await Permission.location.request();
    return permission.isGranted;
  }
  
  /// 位置情報サービスを開始
  Future<void> startLocationService({
    Duration interval = const Duration(seconds: 10),
    double distanceFilter = 10.0,
  }) async {
    if (!await checkLocationPermission()) {
      if (!await requestLocationPermission()) {
        throw Exception('位置情報権限が拒否されました');
      }
    }
    
    // 位置情報サービスが有効か確認
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('位置情報サービスが無効です');
    }
    
    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter.toInt(),
        timeLimit: const Duration(minutes: 5),
      ),
    ).listen(
      (Position position) {
        _currentPosition = position;
        _positionHistory.add(position);
        
        // 履歴を100件に制限
        if (_positionHistory.length > 100) {
          _positionHistory.removeAt(0);
        }
        
        debugPrint('位置情報更新: ${position.latitude}, ${position.longitude}');
      },
      onError: (error) {
        debugPrint('位置情報エラー: $error');
      },
    );
  }
  
  /// 位置情報サービスを停止
  void stopLocationService() {
    _positionStream?.cancel();
    _positionStream = null;
  }
  
  /// 現在位置を取得
  Position? getCurrentPosition() => _currentPosition;
  
  /// 位置情報履歴を取得
  List<Position> getPositionHistory() => List.unmodifiable(_positionHistory);
  
  /// 指定した範囲内の位置情報履歴を取得
  List<Position> getPositionsInRadius(
    double centerLatitude,
    double centerLongitude,
    double radiusInMeters,
  ) {
    return _positionHistory.where((position) {
      final distance = Geolocator.distanceBetween(
        centerLatitude,
        centerLongitude,
        position.latitude,
        position.longitude,
      );
      return distance <= radiusInMeters;
    }).toList();
  }
  
  /// 2点間の距離を計算
  double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }
}

/// マイクサービス
class AudioService {
  static AudioService? _instance;
  static AudioService get instance => _instance ??= AudioService._();
  
  AudioService._();
  
  bool _isRecording = false;
  String? _currentRecordingPath;
  
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
  
  /// 録音を開始
  Future<String> startRecording() async {
    if (!await checkMicrophonePermission()) {
      if (!await requestMicrophonePermission()) {
        throw Exception('マイク権限が拒否されました');
      }
    }
    
    if (_isRecording) {
      throw Exception('すでに録音中です');
    }
    
    try {
      // 録音ファイルのパスを生成
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '/tmp/recording_$timestamp.wav';
      
      // 実際の録音処理（ここではシミュレーション）
      _isRecording = true;
      
      debugPrint('録音開始: $_currentRecordingPath');
      return _currentRecordingPath!;
    } catch (e) {
      debugPrint('録音開始エラー: $e');
      rethrow;
    }
  }
  
  /// 録音を停止
  Future<String?> stopRecording() async {
    if (!_isRecording) {
      throw Exception('録音中ではありません');
    }
    
    try {
      // 実際の録音停止処理（ここではシミュレーション）
      _isRecording = false;
      
      debugPrint('録音停止: $_currentRecordingPath');
      return _currentRecordingPath;
    } catch (e) {
      debugPrint('録音停止エラー: $e');
      rethrow;
    }
  }
  
  /// 録音中かどうかを確認
  bool get isRecording => _isRecording;
  
  /// 現在の録音ファイルパスを取得
  String? get currentRecordingPath => _currentRecordingPath;
}

/// 画像処理サービス
class ImageProcessingService {
  static ImageProcessingService? _instance;
  static ImageProcessingService get instance => _instance ??= ImageProcessingService._();
  
  ImageProcessingService._();
  
  /// 画像をリサイズ
  Future<File> resizeImage(
    File imageFile,
    int maxWidth,
    int maxHeight, {
    int quality = 85,
  }) async {
    try {
      // 実際の画像リサイズ処理（ここではシミュレーション）
      final resizedPath = '${imageFile.path}_resized.jpg';
      final resizedFile = File(resizedPath);
      
      // 元のファイルをコピー（シミュレーション）
      await imageFile.copy(resizedPath);
      
      debugPrint('画像リサイズ完了: $resizedPath');
      return resizedFile;
    } catch (e) {
      debugPrint('画像リサイズエラー: $e');
      rethrow;
    }
  }
  
  /// 画像を圧縮
  Future<File> compressImage(
    File imageFile, {
    int quality = 85,
    int maxWidth = 1024,
    int maxHeight = 1024,
  }) async {
    try {
      // 実際の画像圧縮処理（ここではシミュレーション）
      final compressedPath = '${imageFile.path}_compressed.jpg';
      final compressedFile = File(compressedPath);
      
      // 元のファイルをコピー（シミュレーション）
      await imageFile.copy(compressedPath);
      
      debugPrint('画像圧縮完了: $compressedPath');
      return compressedFile;
    } catch (e) {
      debugPrint('画像圧縮エラー: $e');
      rethrow;
    }
  }
  
  /// 画像のEXIF情報を取得
  Future<Map<String, dynamic>?> getImageExif(File imageFile) async {
    try {
      // 実際のEXIF情報取得処理（ここではシミュレーション）
      final exifData = <String, dynamic>{
        'dateTime': DateTime.now().toIso8601String(),
        'width': 1920,
        'height': 1080,
        'make': 'Camera',
        'model': 'Smartphone',
        'gpsLatitude': 35.6762,
        'gpsLongitude': 139.6503,
      };
      
      debugPrint('EXIF情報取得完了: $exifData');
      return exifData;
    } catch (e) {
      debugPrint('EXIF情報取得エラー: $e');
      return null;
    }
  }
  
  /// 画像からテキストを抽出（OCR）
  Future<String> extractTextFromImage(File imageFile) async {
    try {
      // 实际的OCR处理（ここではシミュレーション）
      final extractedText = '''
抽出されたテキストサンプル
請求書番号: INV-2023-001
日付: 2023-03-09
金額: ¥10,000
      ''';
      
      debugPrint('テキスト抽出完了: ${extractedText.length}文字');
      return extractedText;
    } catch (e) {
      debugPrint('テキスト抽出エラー: $e');
      rethrow;
    }
  }
  
  /// 画像の品質を評価
  Future<double> evaluateImageQuality(File imageFile) async {
    try {
      // 実際の画質評価処理（ここではシミュレーション）
      final quality = 0.85; // 0.0 - 1.0
      
      debugPrint('画質評価完了: $quality');
      return quality;
    } catch (e) {
      debugPrint('画質評価エラー: $e');
      return 0.0;
    }
  }
}

/// センサーデータ統合サービス
class SensorIntegrationService {
  static SensorIntegrationService? _instance;
  static SensorIntegrationService get instance => _instance ??= SensorIntegrationService._();
  
  SensorIntegrationService._();
  
  final SensorService _sensorService = SensorService.instance;
  final AudioService _audioService = AudioService.instance;
  
  /// すべてのセンサーサービスを初期化
  Future<void> initializeAllServices() async {
    try {
      // 位置情報サービスを開始
      await _sensorService.startLocationService();
      
      debugPrint('すべてのセンサーサービス初期化完了');
    } catch (e) {
      debugPrint('センサーサービス初期化エラー: $e');
      rethrow;
    }
  }
  
  /// 音声メモを記録
  Future<Map<String, dynamic>> recordVoiceMemo() async {
    final result = <String, dynamic>{};
    
    try {
      // 位置情報を取得
      final position = _sensorService.getCurrentPosition();
      if (position != null) {
        result['location'] = {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'timestamp': position.timestamp.toIso8601String(),
        };
      }
      
      // 録音を開始
      final recordingPath = await _audioService.startRecording();
      
      // 5秒後に自動停止（デモ用）
      Timer(const Duration(seconds: 5), () async {
        await _audioService.stopRecording();
      });
      
      result['audio'] = {
        'path': recordingPath,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      debugPrint('音声メモ記録開始');
      return result;
    } catch (e) {
      debugPrint('音声メモ記録エラー: $e');
      rethrow;
    }
  }
  
  /// すべてのサービスを解放
  Future<void> disposeAllServices() async {
    try {
      _sensorService.stopLocationService();
      
      debugPrint('すべてのセンサーサービス解放完了');
    } catch (e) {
      debugPrint('センサーサービス解放エラー: $e');
    }
  }
  
  /// サービスの状態を取得
  Map<String, dynamic> getServiceStatus() {
    return {
      'location': {
        'isActive': _sensorService._positionStream != null,
        'currentPosition': _sensorService.getCurrentPosition(),
        'historyCount': _sensorService._positionHistory.length,
      },
      'audio': {
        'isRecording': _audioService.isRecording,
        'currentRecordingPath': _audioService.currentRecordingPath,
      },
    };
  }
}
