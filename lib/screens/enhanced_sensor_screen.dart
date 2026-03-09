import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/enhanced_location_service.dart';
import '../services/enhanced_audio_service.dart';

/// 拡張センサー活用画面
class EnhancedSensorScreen extends StatefulWidget {
  const EnhancedSensorScreen({super.key});

  @override
  State<EnhancedSensorScreen> createState() => _EnhancedSensorScreenState();
}

class _EnhancedSensorScreenState extends State<EnhancedSensorScreen> {
  final EnhancedLocationService _locationService = EnhancedLocationService.instance;
  final EnhancedAudioService _audioService = EnhancedAudioService.instance;
  final MapIntegrationService _mapService = MapIntegrationService.instance;
  final AudioProcessingService _audioProcessing = AudioProcessingService.instance;
  
  Map<String, dynamic>? _locationStats;
  Map<String, dynamic>? _audioStats;
  List<LocationEvent>? _locationEvents;
  List<AudioEvent>? _audioEvents;
  bool _isLocationActive = false;
  bool _isAudioRecording = false;
  
  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }
  
  Future<void> _loadStatistics() async {
    final locationStats = _locationService.getLocationStatistics();
    final audioStats = _audioService.getAudioStatistics();
    final locationEvents = _locationService.getLocationEvents();
    final audioEvents = _audioService.getAudioEvents();
    
    setState(() {
      _locationStats = locationStats;
      _audioStats = audioStats;
      _locationEvents = locationEvents;
      _audioEvents = audioEvents;
    });
  }
  
  Future<void> _startLocationService() async {
    setState(() {
      _isLocationActive = true;
    });
    
    try {
      await _locationService.startEnhancedLocationService(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10.0,
        updateInterval: const Duration(seconds: 10),
        enableGeofencing: true,
        enableMovementTracking: true,
      );
      
      // 現在位置マーカーを追加
      _mapService.addCurrentLocationMarker();
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('拡張位置情報サービスを開始しました'),
          backgroundColor: Colors.green,
        ),
      );
      
      // 定期的に統計を更新
      Timer.periodic(const Duration(seconds: 5), (_) => _loadStatistics());
    } catch (e) {
      setState(() {
        _isLocationActive = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('位置情報サービス起動に失敗しました: $e')),
        );
      }
    }
  }
  
  Future<void> _stopLocationService() async {
    _locationService.stopLocationService();
    setState(() {
      _isLocationActive = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('位置情報サービスを停止しました'),
        backgroundColor: Colors.blue,
      ),
    );
  }
  
  Future<void> _startAudioRecording() async {
    setState(() {
      _isAudioRecording = true;
    });
    
    try {
      await _audioService.startRecording(
        sampleRate: 44100,
        bitRate: 128000,
        channels: 1,
        format: 'wav',
        maxDuration: const Duration(minutes: 10),
        enableNoiseReduction: true,
        enableVoiceActivation: true,
        voiceActivationThreshold: -40.0,
      );
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('拡張音声録音を開始しました'),
          backgroundColor: Colors.green,
        ),
      );
      
      // 定期的に統計を更新
      Timer.periodic(const Duration(seconds: 2), (_) => _loadStatistics());
    } catch (e) {
      setState(() {
        _isAudioRecording = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('音声録音開始に失敗しました: $e')),
        );
      }
    }
  }
  
  Future<void> _stopAudioRecording() async {
    try {
      final recording = await _audioService.stopRecording();
      
      setState(() {
        _isAudioRecording = false;
      });
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('音声録音を停止しました (${recording?.duration?.inSeconds ?? 0}秒)'),
          backgroundColor: Colors.blue,
        ),
      );
      
      // 音声品質を評価
      if (recording != null) {
        _evaluateAudioQuality(recording.filePath);
      }
    } catch (e) {
      setState(() {
        _isAudioRecording = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('音声録音停止に失敗しました: $e')),
        );
      }
    }
  }
  
  Future<void> _evaluateAudioQuality(String filePath) async {
    try {
      final quality = await _audioProcessing.evaluateAudioQuality(filePath);
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('音声品質評価'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SN比: ${quality.signalToNoiseRatio.toStringAsFixed(1)} dB'),
              Text('ピークレベル: ${quality.peakLevel.toStringAsFixed(1)} dB'),
              Text('平均レベル: ${quality.averageLevel.toStringAsFixed(1)} dB'),
              Text('ダイナミックレンジ: ${quality.dynamicRange.toStringAsFixed(1)} dB'),
              Text('歪み: ${(quality.distortion * 100).toStringAsFixed(2)}%'),
              Text('総合品質: ${(quality.overallQuality * 100).toStringAsFixed(1)}%'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('音声品質評価に失敗しました: $e')),
        );
      }
    }
  }
  
  Future<void> _createRouteFromHistory() async {
    _mapService.createRouteFromHistory(
      routeName: '位置情報履歴ルート',
      startTime: DateTime.now().subtract(const Duration(hours: 1)),
      endTime: DateTime.now(),
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('位置情報履歴からルートを作成しました'),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  Future<void> _exportData() async {
    try {
      final locationData = await _locationService.exportLocationHistory();
      final audioData = await _audioService.exportAudioData();
      final mapData = _mapService.exportMapData();
      
      // 実際の実装ではファイルに保存
      debugPrint('位置情報データ: ${locationData.length}文字');
      debugPrint('音声データ: ${audioData.length}文字');
      debugPrint('地図データ: ${mapData.toString().length}文字');
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('センサーデータをエクスポートしました'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('データエクスポートに失敗しました: $e')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('S4:拡張センサー'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatistics,
            tooltip: '統計更新',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportData,
            tooltip: 'データエクスポート',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLocationSection(),
            const SizedBox(height: 16),
            _buildAudioSection(),
            const SizedBox(height: 16),
            _buildMapSection(),
            const SizedBox(height: 16),
            _buildEventsSection(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLocationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '拡張位置情報サービス',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  _isLocationActive ? Icons.location_on : Icons.location_off,
                  color: _isLocationActive ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  _isLocationActive ? 'サービス実行中' : 'サービス停止中',
                  style: TextStyle(
                    color: _isLocationActive ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (!_isLocationActive)
                  ElevatedButton.icon(
                    onPressed: _startLocationService,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('開始'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _stopLocationService,
                    icon: const Icon(Icons.stop),
                    label: const Text('停止'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_locationStats != null) ...[
              _buildLocationStats(),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildLocationStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '位置情報統計',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _buildStatChip('位置数', '${_locationStats!['totalPositions']}', Icons.gps_fixed),
            _buildStatChip('平均精度', '${_locationStats!['averageAccuracy']?.toStringAsFixed(1)}m', Icons.gps_fixed),
            _buildStatChip('総距離', '${(_locationStats!['totalDistance'] / 1000).toStringAsFixed(2)}km', Icons.straighten),
            _buildStatChip('最高速度', '${_locationStats!['maxSpeed']?.toStringAsFixed(1)}m/s', Icons.speed),
            _buildStatChip('イベント', '${_locationStats!['eventCount']}', Icons.event),
          ],
        ),
      ],
    );
  }
  
  Widget _buildAudioSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '拡張音声サービス',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  _isAudioRecording ? Icons.mic : Icons.mic_none,
                  color: _isAudioRecording ? Colors.red : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  _isAudioRecording ? '録音中' : '待機中',
                  style: TextStyle(
                    color: _isAudioRecording ? Colors.red : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (!_isAudioRecording)
                  ElevatedButton.icon(
                    onPressed: _startAudioRecording,
                    icon: const Icon(Icons.mic),
                    label: const Text('録音開始'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _stopAudioRecording,
                    icon: const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    label: const Text('録音停止'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_audioStats != null) ...[
              _buildAudioStats(),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildAudioStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '音声統計',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _buildStatChip('録音数', '${_audioStats!['totalRecordings']}', Icons.mic),
            _buildStatChip('総時間', '${_audioStats!['totalDuration']}秒', Icons.timer),
            _buildStatChip('平均時間', '${_audioStats!['averageDuration']}秒', Icons.timer),
            _buildStatChip('総サイズ', '${(_audioStats!['totalFileSize'] / 1024).toStringAsFixed(1)}KB', Icons.storage),
            _buildStatChip('イベント', '${_audioStats!['eventCount']}', Icons.event),
          ],
        ),
      ],
    );
  }
  
  Widget _buildMapSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '地図連携',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _createRouteFromHistory,
                  icon: const Icon(Icons.map),
                  label: const Text('履歴ルート作成'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    _mapService.addCurrentLocationMarker();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('現在位置マーカーを追加しました')),
                    );
                  },
                  icon: const Icon(Icons.location_on),
                  label: const Text('現在地マーカー'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    _mapService.clearMarkers();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('すべてのマーカーをクリアしました')),
                    );
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('マーカークリア'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatChip('マーカー', '${_mapService.getMarkers().length}', Icons.place),
                const SizedBox(width: 8),
                _buildStatChip('ルート', '${_mapService.getRoutes().length}', Icons.alt_route),
                const SizedBox(width: 8),
                _buildStatChip('領域', '${_mapService.getRegions().length}', Icons.crop_square),
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
              'イベントログ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: '位置情報イベント'),
                      Tab(text: '音声イベント'),
                    ],
                  ),
                  SizedBox(
                    height: 200,
                    child: TabBarView(
                      children: [
                        _buildLocationEventsList(),
                        _buildAudioEventsList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLocationEventsList() {
    if (_locationEvents == null || _locationEvents!.isEmpty) {
      return const Center(child: Text('位置情報イベントがありません'));
    }
    
    return ListView.builder(
      itemCount: _locationEvents!.length,
      itemBuilder: (context, index) {
        final event = _locationEvents![_locationEvents!.length - 1 - index];
        return _buildLocationEventItem(event);
      },
    );
  }
  
  Widget _buildLocationEventItem(LocationEvent event) {
    Color color;
    IconData icon;
    
    switch (event.type) {
      case 'info':
        color = Colors.blue;
        icon = Icons.info;
        break;
      case 'warning':
        color = Colors.orange;
        icon = Icons.warning;
        break;
      case 'error':
        color = Colors.red;
        icon = Icons.error;
        break;
      case 'position_update':
        color = Colors.green;
        icon = Icons.gps_fixed;
        break;
      case 'movement':
        color = Colors.purple;
        icon = Icons.directions_run;
        break;
      default:
        color = Colors.grey;
        icon = Icons.info;
    }
    
    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        event.message,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        _formatDateTime(event.timestamp),
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      dense: true,
    );
  }
  
  Widget _buildAudioEventsList() {
    if (_audioEvents == null || _audioEvents!.isEmpty) {
      return const Center(child: Text('音声イベントがありません'));
    }
    
    return ListView.builder(
      itemCount: _audioEvents!.length,
      itemBuilder: (context, index) {
        final event = _audioEvents![_audioEvents!.length - 1 - index];
        return _buildAudioEventItem(event);
      },
    );
  }
  
  Widget _buildAudioEventItem(AudioEvent event) {
    Color color;
    IconData icon;
    
    switch (event.type) {
      case 'info':
        color = Colors.blue;
        icon = Icons.info;
        break;
      case 'warning':
        color = Colors.orange;
        icon = Icons.warning;
        break;
      case 'error':
        color = Colors.red;
        icon = Icons.error;
        break;
      case 'recording_start':
        color = Colors.green;
        icon = Icons.mic;
        break;
      case 'recording_stop':
        color = Colors.red;
        icon = Icons.mic_off;
        break;
      case 'voice_activation':
        color = Colors.purple;
        icon = Icons.hearing;
        break;
      default:
        color = Colors.grey;
        icon = Icons.info;
    }
    
    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        event.message,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        _formatDateTime(event.timestamp),
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      dense: true,
    );
  }
  
  Widget _buildStatChip(String label, String value, IconData icon) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text('$label: $value'),
      backgroundColor: Colors.purple.shade50,
    );
  }
  
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}:'
           '${dateTime.second.toString().padLeft(2, '0')}';
  }
}
