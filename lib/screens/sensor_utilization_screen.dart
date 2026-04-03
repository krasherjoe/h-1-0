import 'package:flutter/material.dart';
import '../services/sensor_service.dart';

/// センサー活用画面
class SensorUtilizationScreen extends StatefulWidget {
  const SensorUtilizationScreen({super.key});

  @override
  State<SensorUtilizationScreen> createState() => _SensorUtilizationScreenState();
}

class _SensorUtilizationScreenState extends State<SensorUtilizationScreen> {
  final SensorIntegrationService _sensorService = SensorIntegrationService.instance;
  
  Map<String, dynamic>? _serviceStatus;
  bool _isInitializing = false;
  bool _isScanning = false;
  bool _isRecording = false;
  String? _lastImagePath;
  String? _lastRecordingPath;
  
  @override
  void initState() {
    super.initState();
    _initializeServices();
  }
  
  Future<void> _initializeServices() async {
    setState(() {
      _isInitializing = true;
    });
    
    try {
      await _sensorService.initializeAllServices();
      _updateServiceStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('センサー初期化に失敗しました: $e')),
        );
      }
    } finally {
      setState(() {
        _isInitializing = false;
      });
    }
  }
  
  void _updateServiceStatus() {
    setState(() {
      _serviceStatus = _sensorService.getServiceStatus();
    });
  }
  
  Future<void> _scanDocument() async {
    setState(() {
      _isScanning = true;
    });
    
    try {
      // ドキュメントスキャン機能はカメラ依存のため未実装
      await Future.delayed(const Duration(seconds: 1));
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ドキュメントスキャン機能は準備中です'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('スキャンに失敗しました: $e')),
        );
      }
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }
  
  Future<void> _recordVoiceMemo() async {
    setState(() {
      _isRecording = true;
    });
    
    try {
      final result = await _sensorService.recordVoiceMemo();
      
      if (!mounted) return;
      
      setState(() {
        _lastRecordingPath = result['audio']?['path'];
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('音声録音を開始しました'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('録音に失敗しました: $e')),
        );
      }
    } finally {
      setState(() {
        _isRecording = false;
      });
    }
  }
  
  Future<void> _takeGeotaggedPhoto() async {
    setState(() {
      _isScanning = true;
    });
    
    try {
      // 位置情報付き写真機能はカメラ依存のため未実装
      await Future.delayed(const Duration(seconds: 1));
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('位置情報付き写真機能は準備中です'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('写真撮影に失敗しました: $e')),
        );
      }
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('S2:センサー活用'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _updateServiceStatus,
            tooltip: '更新',
          ),
        ],
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSensorActions(),
                  const SizedBox(height: 16),
                  _buildServiceStatus(),
                  const SizedBox(height: 16),
                  _buildRecentActivity(),
                ],
              ),
            ),
    );
  }
  
  Widget _buildSensorActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'センサー機能',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: _isScanning ? null : _scanDocument,
                  icon: const Icon(Icons.document_scanner),
                  label: const Text('ドキュメントスキャン'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isScanning ? null : _takeGeotaggedPhoto,
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('位置情報付き写真'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isRecording ? null : _recordVoiceMemo,
                  icon: _isRecording 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.mic),
                  label: Text(_isRecording ? '録音中...' : '音声メモ'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildServiceStatus() {
    if (_serviceStatus == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('サービス状態がありません')),
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
              'サービス状態',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildLocationStatus(),
            const SizedBox(height: 12),
            _buildCameraStatus(),
            const SizedBox(height: 12),
            _buildAudioStatus(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLocationStatus() {
    final location = _serviceStatus!['location'];
    final isActive = location['isActive'] ?? false;
    final currentPosition = location['currentPosition'];
    final historyCount = location['historyCount'] ?? 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isActive ? Icons.location_on : Icons.location_off,
              color: isActive ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 8),
            const Text(
              '位置情報サービス',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (currentPosition != null) ...[
          Text('緯度: ${currentPosition['latitude']}'),
          Text('経度: ${currentPosition['longitude']}'),
          Text('精度: ${currentPosition['accuracy']}m'),
        ],
        Text('履歴数: $historyCount'),
      ],
    );
  }
  
  Widget _buildCameraStatus() {
    final camera = _serviceStatus!['camera'];
    final isInitialized = camera['isInitialized'] ?? false;
    final availableCameras = camera['availableCameras'] ?? 0;
    final currentCameraIndex = camera['currentCameraIndex'] ?? 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isInitialized ? Icons.camera : Icons.camera_alt_outlined,
              color: isInitialized ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 8),
            const Text(
              'カメラサービス',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('状態: ${isInitialized ? "利用可能" : "未初期化"}'),
        Text('利用可能カメラ: $availableCameras'),
        Text('現在のカメラ: $currentCameraIndex'),
      ],
    );
  }
  
  Widget _buildAudioStatus() {
    final audio = _serviceStatus!['audio'];
    final isRecording = audio['isRecording'] ?? false;
    final currentRecordingPath = audio['currentRecordingPath'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isRecording ? Icons.mic : Icons.mic_none,
              color: isRecording ? Colors.red : Colors.grey,
            ),
            const SizedBox(width: 8),
            const Text(
              '音声サービス',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('状態: ${isRecording ? "録音中" : "待機中"}'),
        if (currentRecordingPath != null)
          Text('録音ファイル: $currentRecordingPath'),
      ],
    );
  }
  
  Widget _buildRecentActivity() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '最近のアクティビティ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_lastImagePath != null) ...[
              const Text(
                '最後の画像',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(_lastImagePath!),
              const SizedBox(height: 12),
            ],
            if (_lastRecordingPath != null) ...[
              const Text(
                '最後の録音',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(_lastRecordingPath!),
              const SizedBox(height: 12),
            ],
            if (_lastImagePath == null && _lastRecordingPath == null)
              const Text('アクティビティがありません'),
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _sensorService.disposeAllServices();
    super.dispose();
  }
}
