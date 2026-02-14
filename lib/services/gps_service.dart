import 'package:geolocator/geolocator.dart';
import 'database_helper.dart';

class GpsService {
  final _dbHelper = DatabaseHelper();

  /// 現在地の取得（権限チェック含む）
  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    
    if (permission == LocationPermission.deniedForever) return null;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// 現在地を履歴としてデータベースに記録
  Future<void> logLocation() async {
    final pos = await getCurrentLocation();
    if (pos == null) return;

    final db = await _dbHelper.database;
    await db.insert('app_gps_history', {
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// 指定件数のGPS履歴を取得
  Future<List<Map<String, dynamic>>> getHistory({int limit = 10}) async {
    final db = await _dbHelper.database;
    return await db.query('app_gps_history', orderBy: 'timestamp DESC', limit: limit);
  }
}
