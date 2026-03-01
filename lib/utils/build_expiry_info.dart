import 'package:flutter/foundation.dart';

class BuildExpiryInfo {
  BuildExpiryInfo._(this.buildTimestamp, this.lifespan, this._hasValidTimestamp);

  factory BuildExpiryInfo.fromEnvironment({Duration lifespan = const Duration(days: 90)}) {
    const rawTimestamp = String.fromEnvironment('APP_BUILD_TIMESTAMP');
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
