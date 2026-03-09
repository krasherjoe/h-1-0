import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// 拡張位置情報サービス
class EnhancedLocationService {
  static EnhancedLocationService? _instance;
  static EnhancedLocationService get instance => _instance ??= EnhancedLocationService._();
  
  EnhancedLocationService._();
  
  StreamSubscription<Position>? _positionStream;
  Position? _currentPosition;
  final List<Position> _positionHistory = [];
  final List<LocationEvent> _locationEvents = [];
  final Map<String, dynamic> _locationSettings = {
    'accuracy': LocationAccuracy.high,
    'distanceFilter': 10.0,
    'updateInterval': const Duration(seconds: 10),
    'maxHistorySize': 1000,
    'enableGeofencing': true,
    'enableMovementTracking': true,
  };
  
  /// 位置情報権限を確認
  Future<bool> checkLocationPermission() async {
    final permission = await Permission.location.status;
    return permission.isGranted;
  }
  
  /// 位置情報権限をリクエスト（常に許可を要求）
  Future<bool> requestLocationPermission() async {
    final permission = await Permission.location.request();
    return permission.isGranted;
  }
  
  /// 位置情報サービスを開始（拡張機能付き）
  Future<void> startEnhancedLocationService({
    LocationAccuracy accuracy = LocationAccuracy.high,
    double distanceFilter = 10.0,
    Duration updateInterval = const Duration(seconds: 10),
    bool enableGeofencing = true,
    bool enableMovementTracking = true,
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
    
    // 設定を更新
    _locationSettings.updateAll((key, value) {
      switch (key) {
        case 'accuracy':
          return accuracy;
        case 'distanceFilter':
          return distanceFilter;
        case 'updateInterval':
          return updateInterval;
        case 'enableGeofencing':
          return enableGeofencing;
        case 'enableMovementTracking':
          return enableMovementTracking;
        default:
          return value;
      }
    });
    
    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter.toInt(),
        timeLimit: const Duration(minutes: 5),
      ),
    ).listen(
      (Position position) {
        _onPositionUpdate(position);
      },
      onError: (error) {
        debugPrint('位置情報エラー: $error');
        _addLocationEvent(LocationEvent.error('位置情報取得エラー', {'error': error.toString()}));
      },
    );
    
    debugPrint('拡張位置情報サービスを開始しました');
  }
  
  /// 位置情報更新時の処理
  void _onPositionUpdate(Position position) {
    final previousPosition = _currentPosition;
    _currentPosition = position;
    _positionHistory.add(position);
    
    // 履歴サイズ制限
    if (_positionHistory.length > _locationSettings['maxHistorySize']) {
      _positionHistory.removeAt(0);
    }
    
    // イベント記録
    _addLocationEvent(LocationEvent.positionUpdate(
      '位置情報更新',
      position.latitude,
      position.longitude,
      position.accuracy,
    ));
    
    // 移動トラッキング
    if (_locationSettings['enableMovementTracking'] && previousPosition != null) {
      _trackMovement(previousPosition, position);
    }
    
    debugPrint('位置情報更新: ${position.latitude}, ${position.longitude} (精度: ${position.accuracy}m)');
  }
  
  /// 移動トラッキング
  void _trackMovement(Position from, Position to) {
    final distance = Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
    
    final timeDiff = to.timestamp.difference(from.timestamp);
    final speed = timeDiff.inSeconds > 0 ? distance / timeDiff.inSeconds : 0.0;
    
    _addLocationEvent(LocationEvent.movement(
      '移動検出',
      distance,
      speed,
      timeDiff.inSeconds,
    ));
    
    // 急な移動を検出
    if (speed > 20.0) { // 20m/s以上
      _addLocationEvent(LocationEvent.warning('急な移動を検出', {'speed': speed.toStringAsFixed(1)}));
    }
  }
  
  /// 位置情報イベントを追加
  void _addLocationEvent(LocationEvent event) {
    _locationEvents.add(event);
    
    // イベント履歴のサイズ制限
    if (_locationEvents.length > 500) {
      _locationEvents.removeAt(0);
    }
  }
  
  /// 位置情報サービスを停止
  void stopLocationService() {
    _positionStream?.cancel();
    _positionStream = null;
    _addLocationEvent(LocationEvent.info('位置情報サービス停止'));
    debugPrint('位置情報サービスを停止しました');
  }
  
  /// 現在位置を取得
  Position? getCurrentPosition() => _currentPosition;
  
  /// 位置情報履歴を取得
  List<Position> getPositionHistory() => List.unmodifiable(_positionHistory);
  
  /// 位置情報イベントを取得
  List<LocationEvent> getLocationEvents() => List.unmodifiable(_locationEvents);
  
  /// 指定した期間の位置情報を取得
  List<Position> getPositionsInTimeRange(DateTime start, DateTime end) {
    return _positionHistory.where((position) {
      final timestamp = position.timestamp;
      return timestamp.isAfter(start) && timestamp.isBefore(end);
    }).toList();
  }
  
  /// 指定した範囲内の位置情報を取得
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
  
  /// 位置情報統計を取得
  Map<String, dynamic> getLocationStatistics() {
    if (_positionHistory.isEmpty) {
      return {
        'totalPositions': 0,
        'averageAccuracy': 0.0,
        'bestAccuracy': 0.0,
        'worstAccuracy': 0.0,
        'totalDistance': 0.0,
        'averageSpeed': 0.0,
        'maxSpeed': 0.0,
        'eventCount': _locationEvents.length,
      };
    }
    
    final accuracies = _positionHistory.map((p) => p.accuracy).toList();
    accuracies.sort();
    
    double totalDistance = 0.0;
    double maxSpeed = 0.0;
    
    for (int i = 1; i < _positionHistory.length; i++) {
      final from = _positionHistory[i - 1];
      final to = _positionHistory[i];
      final distance = calculateDistance(
        from.latitude,
        from.longitude,
        to.latitude,
        to.longitude,
      );
      totalDistance += distance;
      
      final timeDiff = to.timestamp.difference(from.timestamp).inSeconds;
      if (timeDiff > 0) {
        final speed = distance / timeDiff;
        maxSpeed = speed > maxSpeed ? speed : maxSpeed;
      }
    }
    
    final averageSpeed = _positionHistory.length > 1 
        ? totalDistance / (_positionHistory.last.timestamp.difference(_positionHistory.first.timestamp).inSeconds)
        : 0.0;
    
    return {
      'totalPositions': _positionHistory.length,
      'averageAccuracy': accuracies.reduce((a, b) => a + b) / accuracies.length,
      'bestAccuracy': accuracies.first,
      'worstAccuracy': accuracies.last,
      'totalDistance': totalDistance,
      'averageSpeed': averageSpeed,
      'maxSpeed': maxSpeed,
      'eventCount': _locationEvents.length,
      'firstPositionTime': _positionHistory.first.timestamp.toIso8601String(),
      'lastPositionTime': _positionHistory.last.timestamp.toIso8601String(),
    };
  }
  
  /// 位置情報履歴をエクスポート
  Future<String> exportLocationHistory() async {
    final buffer = StringBuffer();
    buffer.writeln('timestamp,latitude,longitude,accuracy,altitude,speed,heading');
    
    for (final position in _positionHistory) {
      buffer.writeln(
        '${position.timestamp.toIso8601String()},'
        '${position.latitude},'
        '${position.longitude},'
        '${position.accuracy},'
        '${position.altitude},'
        '${position.speed},'
        '${position.heading}',
      );
    }
    
    return buffer.toString();
  }
  
  /// 位置情報設定を更新
  void updateSettings(Map<String, dynamic> newSettings) {
    _locationSettings.addAll(newSettings);
    debugPrint('位置情報設定を更新: $newSettings');
  }
  
  /// 現在の設定を取得
  Map<String, dynamic> getSettings() => Map.unmodifiable(_locationSettings);
}

/// 位置情報イベントクラス
class LocationEvent {
  final String type;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic>? data;
  
  LocationEvent(this.type, this.message, {this.data}) : timestamp = DateTime.now();
  
  factory LocationEvent.info(String message, [Map<String, dynamic>? data]) {
    return LocationEvent('info', message, data: data);
  }
  
  factory LocationEvent.warning(String message, [Map<String, dynamic>? data]) {
    return LocationEvent('warning', message, data: data);
  }
  
  factory LocationEvent.error(String message, [Map<String, dynamic>? data]) {
    return LocationEvent('error', message, data: data);
  }
  
  factory LocationEvent.positionUpdate(
    String message,
    double latitude,
    double longitude,
    double accuracy,
  ) {
    return LocationEvent('position_update', message, data: {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
    });
  }
  
  factory LocationEvent.movement(
    String message,
    double distance,
    double speed,
    int duration,
  ) {
    return LocationEvent('movement', message, data: {
      'distance': distance,
      'speed': speed,
      'duration': duration,
    });
  }
  
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      if (data != null) 'data': data,
    };
  }
}

/// 地図連携サービス
class MapIntegrationService {
  static MapIntegrationService? _instance;
  static MapIntegrationService get instance => _instance ??= MapIntegrationService._();
  
  MapIntegrationService._();
  
  final EnhancedLocationService _locationService = EnhancedLocationService.instance;
  final List<MapMarker> _markers = [];
  final List<MapRoute> _routes = [];
  final List<MapRegion> _regions = [];
  
  /// マーカーを追加
  void addMarker(MapMarker marker) {
    _markers.add(marker);
    debugPrint('マーカーを追加: ${marker.title}');
  }
  
  /// マーカーを削除
  void removeMarker(String markerId) {
    _markers.removeWhere((marker) => marker.id == markerId);
    debugPrint('マーカーを削除: $markerId');
  }
  
  /// すべてのマーカーをクリア
  void clearMarkers() {
    _markers.clear();
    debugPrint('すべてのマーカーをクリア');
  }
  
  /// ルートを作成
  void createRoute(MapRoute route) {
    _routes.add(route);
    debugPrint('ルートを作成: ${route.name}');
  }
  
  /// 地図領域を追加
  void addRegion(MapRegion region) {
    _regions.add(region);
    debugPrint('地図領域を追加: ${region.name}');
  }
  
  /// 現在位置にマーカーを追加
  void addCurrentLocationMarker() {
    final currentPos = _locationService.getCurrentPosition();
    if (currentPos != null) {
      addMarker(MapMarker(
        id: 'current_location',
        title: '現在位置',
        latitude: currentPos.latitude,
        longitude: currentPos.longitude,
        icon: 'current_location',
        color: 'blue',
      ));
    }
  }
  
  /// 位置情報履歴からルートを作成
  void createRouteFromHistory({
    String routeName = '位置情報履歴',
    DateTime? startTime,
    DateTime? endTime,
  }) {
    final history = _locationService.getPositionHistory();
    
    List<MapMarker> routePoints = [];
    
    for (final position in history) {
      if (startTime != null && position.timestamp.isBefore(startTime)) continue;
      if (endTime != null && position.timestamp.isAfter(endTime)) continue;
      
      routePoints.add(MapMarker(
        id: position.timestamp.millisecondsSinceEpoch.toString(),
        title: position.timestamp.toString(),
        latitude: position.latitude,
        longitude: position.longitude,
        icon: 'route_point',
        color: 'green',
      ));
    }
    
    if (routePoints.isNotEmpty) {
      createRoute(MapRoute(
        id: routeName,
        name: routeName,
        points: routePoints,
        color: 'blue',
        width: 3.0,
      ));
    }
  }
  
  /// ジオフェンス（仮想境界）をチェック
  List<MapRegion> checkGeofencing(double latitude, double longitude) {
    final activeRegions = <MapRegion>[];
    
    for (final region in _regions) {
      if (_isPointInRegion(latitude, longitude, region)) {
        activeRegions.add(region);
      }
    }
    
    return activeRegions;
  }
  
  /// 点が領域内にあるかチェック
  bool _isPointInRegion(double lat, double lon, MapRegion region) {
    // 簡易的な円形領域チェック
    if (region.type == 'circle') {
      final center = region.center;
      final distance = Geolocator.distanceBetween(
        center.latitude,
        center.longitude,
        lat,
        lon,
      );
      return distance <= region.radius;
    }
    
    // 他の領域タイプのチェックはここに実装
    return false;
  }
  
  /// マーカーを取得
  List<MapMarker> getMarkers() => List.unmodifiable(_markers);
  
  /// ルートを取得
  List<MapRoute> getRoutes() => List.unmodifiable(_routes);
  
  /// 領域を取得
  List<MapRegion> getRegions() => List.unmodifiable(_regions);
  
  /// 地図データをエクスポート
  Map<String, dynamic> exportMapData() {
    return {
      'markers': _markers.map((m) => m.toJson()).toList(),
      'routes': _routes.map((r) => r.toJson()).toList(),
      'regions': _regions.map((r) => r.toJson()).toList(),
      'exportTime': DateTime.now().toIso8601String(),
    };
  }
}

/// マーカークラス
class MapMarker {
  final String id;
  final String title;
  final double latitude;
  final double longitude;
  final String icon;
  final String color;
  final Map<String, dynamic>? metadata;
  
  MapMarker({
    required this.id,
    required this.title,
    required this.latitude,
    required this.longitude,
    this.icon = 'default',
    this.color = 'red',
    this.metadata,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'latitude': latitude,
      'longitude': longitude,
      'icon': icon,
      'color': color,
      if (metadata != null) 'metadata': metadata,
    };
  }
}

/// ルートクラス
class MapRoute {
  final String id;
  final String name;
  final List<MapMarker> points;
  final String color;
  final double width;
  final Map<String, dynamic>? metadata;
  
  MapRoute({
    required this.id,
    required this.name,
    required this.points,
    this.color = 'blue',
    this.width = 2.0,
    this.metadata,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'points': points.map((p) => p.toJson()).toList(),
      'color': color,
      'width': width,
      if (metadata != null) 'metadata': metadata,
    };
  }
}

/// 地図領域クラス
class MapRegion {
  final String id;
  final String name;
  final String type; // circle, rectangle, polygon
  final MapMarker center;
  final double radius; // 円形の場合の半径（メートル）
  final Map<String, dynamic>? metadata;
  
  MapRegion({
    required this.id,
    required this.name,
    required this.type,
    required this.center,
    required this.radius,
    this.metadata,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'center': center.toJson(),
      'radius': radius,
      if (metadata != null) 'metadata': metadata,
    };
  }
}
