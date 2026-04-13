import 'package:flutter/foundation.dart';

class BuildExpiryInfo {
  BuildExpiryInfo._(this.buildTimestamp, this.lifespan, this._hasValidTimestamp);

  factory BuildExpiryInfo.fromEnvironment({Duration? lifespan}) {
    const rawTimestamp = String.fromEnvironment('APP_BUILD_TIMESTAMP');
    const rawLifespanDays = String.fromEnvironment('APP_BUILD_LIFESPAN_DAYS');
    
    // 環境変数で寿命を設定（優先）
    if (rawLifespanDays.isNotEmpty) {
      final days = int.tryParse(rawLifespanDays);
      if (days != null && days > 0) {
        lifespan = Duration(days: days);
        debugPrint('[BuildExpiry] Lifespan set to $days days from environment variable.');
      }
    }
    
    // デフォルトは90日
    lifespan ??= const Duration(days: 90);
    
    if (rawTimestamp.isEmpty) {
      debugPrint('[BuildExpiry] APP_BUILD_TIMESTAMP is missing; expiry guard disabled.');
      return BuildExpiryInfo._(null, lifespan, false);
    }

    final parsed = DateTime.tryParse(rawTimestamp);
    if (parsed == null) {
      debugPrint('[BuildExpiry] Invalid APP_BUILD_TIMESTAMP: $rawTimestamp. Expiry guard disabled.');
      return BuildExpiryInfo._(null, lifespan, false);
    }

    return BuildExpiryInfo._(parsed.toUtc(), lifespan, true);
  }

  final DateTime? buildTimestamp;
  final Duration lifespan;
  final bool _hasValidTimestamp;

  bool get isEnforced => _hasValidTimestamp && buildTimestamp != null;

  DateTime? get expiryTimestamp => buildTimestamp?.add(lifespan);

  bool get isExpired {
    if (!isEnforced || expiryTimestamp == null) return false;
    return DateTime.now().toUtc().isAfter(expiryTimestamp!);
  }

  Duration? get remaining {
    if (!isEnforced || expiryTimestamp == null) return null;
    return expiryTimestamp!.difference(DateTime.now().toUtc());
  }
}
