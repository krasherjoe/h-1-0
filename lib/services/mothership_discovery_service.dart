import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../models/mothership_location.dart';
import 'app_settings_repository.dart';
import 'database_helper.dart';
import 'gps_service.dart';
import 'mothership_client.dart';

/// お局様サーバーのLAN内検出とGPS位置記憶を担当するサービス
class MothershipDiscoveryService {
  MothershipDiscoveryService({
    MothershipClient? mothershipClient,
    GpsService? gpsService,
    AppSettingsRepository? settingsRepository,
  })  : _mothershipClient = mothershipClient ?? MothershipClient(),
        _gpsService = gpsService ?? GpsService(),
        _settingsRepository = settingsRepository ?? AppSettingsRepository();

  final MothershipClient _mothershipClient;
  final GpsService _gpsService;
  final AppSettingsRepository _settingsRepository;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  static const _defaultDiscoveryRangeMeters = 500.0;

  /// お局様サーバーへの接続性テストを実行し、成功時にGPS位置を記録
  Future<bool> discoverAndRecord() async {
    final config = await _mothershipClient.loadConfig();
    if (config == null) {
      debugPrint('[MothershipDiscovery] 設定未完了のためスキップ');
      return false;
    }

    final reachable = await _testReachability(config.heartbeatUri);
    if (!reachable) {
      debugPrint('[MothershipDiscovery] お局様に到達できません');
      return false;
    }

    final position = await _gpsService.getCurrentLocation();
    if (position == null) {
      debugPrint('[MothershipDiscovery] GPS位置取得失敗 - 位置記録なしで接続可能');
      return true;
    }

    final host = await _settingsRepository.getString('external_host');
    if (host == null || host.isEmpty) {
      return true;
    }

    await _recordLocation(
      host: host,
      latitude: position.latitude,
      longitude: position.longitude,
    );

    debugPrint('[MothershipDiscovery] お局様を記録: $host @ (${position.latitude}, ${position.longitude})');
    return true;
  }

  /// 現在位置から近いお局様を検索し、接続テストを実行
  Future<bool> findNearbyMothership({double rangeMeters = _defaultDiscoveryRangeMeters}) async {
    final position = await _gpsService.getCurrentLocation();
    if (position == null) {
      debugPrint('[MothershipDiscovery] GPS位置取得失敗 - 位置ベース検索不可');
      return false;
    }

    final locations = await _getAllLocations();
    if (locations.isEmpty) {
      debugPrint('[MothershipDiscovery] 記録された位置情報なし');
      return false;
    }

    for (final location in locations) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        location.latitude,
        location.longitude,
      );

      if (distance <= rangeMeters) {
        debugPrint('[MothershipDiscovery] 近くのお局様を発見: ${location.host} (${distance.toStringAsFixed(0)}m)');
        
        final currentHost = await _settingsRepository.getString('external_host');
        if (currentHost != location.host) {
          debugPrint('[MothershipDiscovery] 位置ベースでホストを切替: $currentHost -> ${location.host}');
        }

        final config = await _mothershipClient.loadConfig();
        if (config != null) {
          final reachable = await _testReachability(config.heartbeatUri);
          if (reachable) {
            await _updateLastSeen(location.id!);
            return true;
          }
        }
      }
    }

    debugPrint('[MothershipDiscovery] 範囲内にお局様なし（${rangeMeters}m以内）');
    return false;
  }

  /// 指定URIへの接続性テスト（短時間タイムアウト）
  Future<bool> _testReachability(Uri uri, {Duration timeout = const Duration(seconds: 3)}) async {
    final client = http.Client();
    try {
      final response = await client.get(uri).timeout(timeout);
      client.close();
      return response.statusCode >= 200 && response.statusCode < 500;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } on HttpException {
      return false;
    } catch (err) {
      debugPrint('[MothershipDiscovery] 接続テスト失敗: $err');
      return false;
    } finally {
      client.close();
    }
  }

  /// お局様の位置情報を記録または更新
  Future<void> _recordLocation({
    required String host,
    required double latitude,
    required double longitude,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();

    final existing = await db.query(
      'mothership_locations',
      where: 'host = ?',
      whereArgs: [host],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      await db.update(
        'mothership_locations',
        {
          'latitude': latitude,
          'longitude': longitude,
          'last_seen': now.toIso8601String(),
        },
        where: 'host = ?',
        whereArgs: [host],
      );
    } else {
      await db.insert('mothership_locations', {
        'host': host,
        'latitude': latitude,
        'longitude': longitude,
        'last_seen': now.toIso8601String(),
        'created_at': now.toIso8601String(),
      });
    }
  }

  /// 最終接続時刻を更新
  Future<void> _updateLastSeen(int id) async {
    final db = await _dbHelper.database;
    await db.update(
      'mothership_locations',
      {'last_seen': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 記録された全てのお局様位置情報を取得
  Future<List<MothershipLocation>> _getAllLocations() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'mothership_locations',
      orderBy: 'last_seen DESC',
    );
    return maps.map((m) => MothershipLocation.fromMap(m)).toList();
  }

  /// 記録された位置情報を全て取得（UI表示用）
  Future<List<MothershipLocation>> getRecordedLocations() async {
    return _getAllLocations();
  }

  /// 指定IDの位置情報を削除
  Future<void> deleteLocation(int id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'mothership_locations',
      where: 'id = ?',
      whereArgs: [id],
    );
    debugPrint('[MothershipDiscovery] 位置情報削除: ID=$id');
  }

  /// 検出範囲設定を取得
  Future<double> getDiscoveryRange() async {
    final raw = await _settingsRepository.getString('mothership_discovery_range');
    if (raw == null) return _defaultDiscoveryRangeMeters;
    return double.tryParse(raw) ?? _defaultDiscoveryRangeMeters;
  }

  /// 検出範囲設定を保存
  Future<void> setDiscoveryRange(double meters) async {
    await _settingsRepository.setString('mothership_discovery_range', meters.toString());
  }

  /// 自動検出が有効かどうか
  Future<bool> isAutoDiscoveryEnabled() async {
    return await _settingsRepository.getBool('mothership_auto_discovery', defaultValue: true);
  }

  /// 自動検出の有効/無効を設定
  Future<void> setAutoDiscoveryEnabled(bool enabled) async {
    await _settingsRepository.setBool('mothership_auto_discovery', enabled);
  }
}
