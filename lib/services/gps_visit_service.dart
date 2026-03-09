import 'dart:async';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';

/// GPS訪問記録サービス
class GpsVisitService {
  static final GpsVisitService _instance = GpsVisitService._internal();
  factory GpsVisitService() => _instance;
  GpsVisitService._internal();
  
  final DatabaseHelper _dbHelper = DatabaseHelper();
  StreamSubscription<Position>? _positionStreamSubscription;
  Position? _lastKnownPosition;
  Timer? _visitCheckTimer;
  final List<String> _visitedClients = <String>[];
  final double _visitRadius = 50.0; // 訪問判定半径（メートル）
  
  // GPSサービスの初期化
  Future<bool> initialize() async {
    try {
      // 位置情報権限の確認
      final permission = await Permission.location.request();
      if (permission != PermissionStatus.granted) {
        return false;
      }
      
      // 位置情報サービスの確認
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }
      
      // 最後の既知位置を取得
      _lastKnownPosition = await Geolocator.getLastKnownPosition();
      
      // 位置情報ストリームの開始
      _startLocationTracking();
      
      // 訪問チェックタイマーの開始
      _startVisitCheckTimer();
      
      return true;
    } catch (e) {
      print('GPSサービス初期化エラー: $e');
      return false;
    }
  }
  
  // 位置情報トラッキングの開始
  void _startLocationTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // 10メートル移動ごとに更新
    );
    
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        _lastKnownPosition = position;
        _checkNearbyClients(position);
      },
      onError: (error) {
        print('位置情報取得エラー: $error');
      },
    );
  }
  
  // 訪問チェックタイマーの開始
  void _startVisitCheckTimer() {
    _visitCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_lastKnownPosition != null) {
        _checkNearbyClients(_lastKnownPosition!);
      }
    });
  }
  
  // 近くの顧客チェック
  Future<void> _checkNearbyClients(Position currentPosition) async {
    try {
      final db = await _dbHelper.database;
      
      // すべてのアクティブ顧客を取得
      final clients = await db.query(
        'clients',
        where: 'is_active = 1 AND latitude IS NOT NULL AND longitude IS NOT NULL',
      );
      
      for (final client in clients) {
        final clientId = client['id'] as String;
        final clientName = client['name'] as String;
        final clientLat = double.tryParse(client['latitude'].toString()) ?? 0.0;
        final clientLng = double.tryParse(client['longitude'].toString()) ?? 0.0;
        
        // 距離計算
        final distance = Geolocator.distanceBetween(
          currentPosition.latitude,
          currentPosition.longitude,
          clientLat,
          clientLng,
        );
        
        // 訪問範囲内かつ今日まだ訪問記録がない場合
        if (distance <= _visitRadius && !_visitedClients.contains(clientId)) {
          await _recordClientVisit(client, currentPosition);
          _visitedClients.add(clientId);
        }
      }
    } catch (e) {
      print('顧客訪問チェックエラー: $e');
    }
  }
  
  // 顧客訪問記録
  Future<void> _recordClientVisit(
    Map<String, dynamic> client,
    Position position,
  ) async {
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now();
      
      // 訪問記録の挿入
      await db.insert('client_visits', {
        'id': _generateId(),
        'client_id': client['id'],
        'client_name': client['name'],
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'visit_time': now.toIso8601String(),
        'created_at': now.toIso8601String(),
      });
      
      // 最終訪問日時の更新
      await db.update(
        'clients',
        {'last_visit_at': now.toIso8601String()},
        where: 'id = ?',
        whereArgs: [client['id']],
      );
      
      print('顧客訪問を記録しました: ${client['name']}');
    } catch (e) {
      print('顧客訪問記録エラー: $e');
    }
  }
  
  // 手動訪問記録
  Future<bool> recordManualVisit({
    required String clientId,
    String? notes,
  }) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      final db = await _dbHelper.database;
      final client = await db.query(
        'clients',
        where: 'id = ?',
        whereArgs: [clientId],
        limit: 1,
      );
      
      if (client.isEmpty) {
        return false;
      }
      
      final now = DateTime.now();
      
      // 訪問記録の挿入
      await db.insert('client_visits', {
        'id': _generateId(),
        'client_id': clientId,
        'client_name': client.first['name'],
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'visit_time': now.toIso8601String(),
        'notes': notes,
        'is_manual': 1,
        'created_at': now.toIso8601String(),
      });
      
      // 最終訪問日時の更新
      await db.update(
        'clients',
        {'last_visit_at': now.toIso8601String()},
        where: 'id = ?',
        whereArgs: [clientId],
      );
      
      return true;
    } catch (e) {
      print('手動訪問記録エラー: $e');
      return false;
    }
  }
  
  // 訪問記録の取得
  Future<List<Map<String, dynamic>>> getVisitRecords({
    String? clientId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    final db = await _dbHelper.database;
    
    String whereClause = '1=1';
    List<dynamic> whereArgs = [];
    
    if (clientId != null) {
      whereClause += ' AND client_id = ?';
      whereArgs.add(clientId);
    }
    
    if (startDate != null) {
      whereClause += ' AND visit_time >= ?';
      whereArgs.add(startDate.toIso8601String());
    }
    
    if (endDate != null) {
      whereClause += ' AND visit_time <= ?';
      whereArgs.add(endDate.toIso8601String());
    }
    
    return await db.query(
      'client_visits',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'visit_time DESC',
      limit: limit,
    );
  }
  
  // 今日の訪問記録
  Future<List<Map<String, dynamic>>> getTodayVisits() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    return await getVisitRecords(
      startDate: startOfDay,
      endDate: endOfDay,
    );
  }
  
  // 今週の訪問記録
  Future<List<Map<String, dynamic>>> getThisWeekVisits() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    
    return await getVisitRecords(startDate: startOfDay);
  }
  
  // 今月の訪問記録
  Future<List<Map<String, dynamic>>> getThisMonthVisits() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    
    return await getVisitRecords(startDate: startOfMonth);
  }
  
  // 訪問統計
  Future<Map<String, dynamic>> getVisitStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _dbHelper.database;
    
    String whereClause = '1=1';
    List<dynamic> whereArgs = [];
    
    if (startDate != null) {
      whereClause += ' AND visit_time >= ?';
      whereArgs.add(startDate.toIso8601String());
    }
    
    if (endDate != null) {
      whereClause += ' AND visit_time <= ?';
      whereArgs.add(endDate.toIso8601String());
    }
    
    // 総訪問数
    final totalVisitsResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM client_visits WHERE $whereClause',
      whereArgs,
    );
    final totalVisits = totalVisitsResult.first['count'] as int;
    
    // ユニーク顧客数
    final uniqueClientsResult = await db.rawQuery(
      'SELECT COUNT(DISTINCT client_id) as count FROM client_visits WHERE $whereClause',
      whereArgs,
    );
    final uniqueClients = uniqueClientsResult.first['count'] as int;
    
    // 手動訪問数
    final manualVisitsResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM client_visits WHERE $whereClause AND is_manual = 1',
      whereArgs,
    );
    final manualVisits = manualVisitsResult.first['count'] as int;
    
    // 自動訪問数
    final autoVisits = totalVisits - manualVisits;
    
    // 日別訪問数
    final dailyVisitsResult = await db.rawQuery('''
      SELECT 
        DATE(visit_time) as date,
        COUNT(*) as visits,
        COUNT(DISTINCT client_id) as unique_clients
      FROM client_visits
      WHERE $whereClause
      GROUP BY DATE(visit_time)
      ORDER BY date DESC
      LIMIT 30
    ''', whereArgs);
    
    // 顧客別訪問数
    final clientVisitsResult = await db.rawQuery('''
      SELECT 
        client_id,
        client_name,
        COUNT(*) as visits,
        MAX(visit_time) as last_visit
      FROM client_visits
      WHERE $whereClause
      GROUP BY client_id, client_name
      ORDER BY visits DESC
      LIMIT 20
    ''', whereArgs);
    
    return {
      'totalVisits': totalVisits,
      'uniqueClients': uniqueClients,
      'manualVisits': manualVisits,
      'autoVisits': autoVisits,
      'dailyVisits': dailyVisitsResult,
      'clientVisits': clientVisitsResult,
    };
  }
  
  // 近くの顧客検索
  Future<List<Map<String, dynamic>>> findNearbyClients({
    double radius = 500.0, // 検索半径（メートル）
    int limit = 20,
  }) async {
    if (_lastKnownPosition == null) {
      return [];
    }
    
    final db = await _dbHelper.database;
    final position = _lastKnownPosition!;
    
    // 簡易的な距離計算（実際のアプリではより正確な計算を使用）
    final clients = await db.query(
      'clients',
      where: 'is_active = 1 AND latitude IS NOT NULL AND longitude IS NOT NULL',
      orderBy: 'last_visit_at ASC', // 久しぶりの顧客を優先
      limit: 100,
    );
    
    final nearbyClients = <Map<String, dynamic>>[];
    
    for (final client in clients) {
      final clientLat = double.tryParse(client['latitude'].toString()) ?? 0.0;
      final clientLng = double.tryParse(client['longitude'].toString()) ?? 0.0;
      
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        clientLat,
        clientLng,
      );
      
      if (distance <= radius) {
        nearbyClients.add({
          ...client,
          'distance': distance,
          'isNear': distance <= _visitRadius,
        });
      }
    }
    
    // 距離でソート
    nearbyClients.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
    
    return nearbyClients.take(limit).toList();
  }
  
  // 顧客位置情報の更新
  Future<bool> updateClientLocation({
    required String clientId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final db = await _dbHelper.database;
      
      await db.update(
        'clients',
        {
          'latitude': latitude,
          'longitude': longitude,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [clientId],
      );
      
      return true;
    } catch (e) {
      print('顧客位置情報更新エラー: $e');
      return false;
    }
  }
  
  // 現在位置の取得
  Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      print('現在位置取得エラー: $e');
      return null;
    }
  }
  
  // 位置情報精度のチェック
  bool isPositionAccurate(Position position) {
    return position.accuracy <= 100.0; // 100メートル以内を高精度と判定
  }
  
  // 訪問ルートの生成
  Future<List<Map<String, dynamic>>> generateVisitRoute({
    required List<String> clientIds,
    String? startPoint, // 開始地点の住所
  }) async {
    final db = await _dbHelper.database;
    
    // 顧客情報取得
    final clients = <Map<String, dynamic>>[];
    for (final clientId in clientIds) {
      final client = await db.query(
        'clients',
        where: 'id = ? AND latitude IS NOT NULL AND longitude IS NOT NULL',
        whereArgs: [clientId],
        limit: 1,
      );
      
      if (client.isNotEmpty) {
        clients.add(client.first);
      }
    }
    
    if (clients.isEmpty) {
      return [];
    }
    
    // 現在位置を開始点として使用
    Position? currentPosition = _lastKnownPosition ?? await getCurrentPosition();
    
    if (currentPosition == null) {
      return [];
    }
    
    // 簡易的なルート生成（実際のアプリでは最適化アルゴリズムを使用）
    final route = <Map<String, dynamic>>[];
    final remainingClients = List<Map<String, dynamic>>.from(clients);
    var currentLat = currentPosition.latitude;
    var currentLng = currentPosition.longitude;
    
    while (remainingClients.isNotEmpty) {
      // 最も近い顧客を検索
      Map<String, dynamic>? nearestClient;
      double minDistance = double.infinity;
      
      for (final client in remainingClients) {
        final clientLat = double.tryParse(client['latitude'].toString()) ?? 0.0;
        final clientLng = double.tryParse(client['longitude'].toString()) ?? 0.0;
        
        final distance = Geolocator.distanceBetween(
          currentLat,
          currentLng,
          clientLat,
          clientLng,
        );
        
        if (distance < minDistance) {
          minDistance = distance;
          nearestClient = client;
        }
      }
      
      if (nearestClient != null) {
        route.add({
          'client': nearestClient,
          'distanceFromPrevious': minDistance,
          'estimatedTime': (minDistance / 1000 * 3).round(), // 時速3kmで換算
        });
        
        currentLat = double.tryParse(nearestClient['latitude'].toString()) ?? 0.0;
        currentLng = double.tryParse(nearestClient['longitude'].toString()) ?? 0.0;
        remainingClients.remove(nearestClient);
      } else {
        break;
      }
    }
    
    return route;
  }
  
  // 訪問記録のエクスポート
  Future<void> exportVisitRecords({
    DateTime? startDate,
    DateTime? endDate,
    String format = 'csv', // 'csv' or 'json'
  }) async {
    final visits = await getVisitRecords(
      startDate: startDate,
      endDate: endDate,
      limit: 10000,
    );
    
    final now = DateTime.now();
    final fileName = 'visits_${DateFormat('yyyyMMdd_HHmmss').format(now)}.$format';
    
    if (format == 'csv') {
      final csvData = _convertToCsv(visits);
      final file = File('/tmp/$fileName');
      await file.writeAsString(csvData);
    } else {
      final jsonData = _convertToJson(visits);
      final file = File('/tmp/$fileName');
      await file.writeAsString(jsonData);
    }
  }
  
  // CSV変換
  String _convertToCsv(List<Map<String, dynamic>> visits) {
    final buffer = StringBuffer();
    
    // ヘッダー
    buffer.writeln('訪問日時,顧客名,緯度,経度,精度,備考,手動記録');
    
    // データ
    for (final visit in visits) {
      buffer.writeln([
        visit['visit_time'],
        visit['client_name'],
        visit['latitude'],
        visit['longitude'],
        visit['accuracy'],
        visit['notes'] ?? '',
        visit['is_manual'] == 1 ? 'はい' : 'いいえ',
      ].join(','));
    }
    
    return buffer.toString();
  }
  
  // JSON変換
  String _convertToJson(List<Map<String, dynamic>> visits) {
    return visits.map((visit) => {
      'visit_time': visit['visit_time'],
      'client_id': visit['client_id'],
      'client_name': visit['client_name'],
      'latitude': visit['latitude'],
      'longitude': visit['longitude'],
      'accuracy': visit['accuracy'],
      'notes': visit['notes'],
      'is_manual': visit['is_manual'] == 1,
    }).toList().toString();
  }
  
  // GPSサービスの停止
  void stop() {
    _positionStreamSubscription?.cancel();
    _visitCheckTimer?.cancel();
  }
  
  // ID生成
  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
  
  // 破棄
  void dispose() {
    stop();
  }
}
