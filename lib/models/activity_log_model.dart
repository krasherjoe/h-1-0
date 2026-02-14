import 'package:uuid/uuid.dart';

class ActivityLog {
  final String id;
  final String action; // 例: "CREATE", "UPDATE", "DELETE", "GENERATE_PDF"
  final String targetType; // 例: "INVOICE", "CUSTOMER", "PRODUCT"
  final String? targetId;
  final String? details;
  final DateTime timestamp;

  ActivityLog({
    required this.id,
    required this.action,
    required this.targetType,
    this.targetId,
    this.details,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'action': action,
      'target_type': targetType,
      'target_id': targetId,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ActivityLog.fromMap(Map<String, dynamic> map) {
    return ActivityLog(
      id: map['id'],
      action: map['action'],
      targetType: map['target_type'],
      targetId: map['target_id'],
      details: map['details'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }

  static ActivityLog create({
    required String action,
    required String targetType,
    String? targetId,
    String? details,
  }) {
    return ActivityLog(
      id: const Uuid().v4(),
      action: action,
      targetType: targetType,
      targetId: targetId,
      details: details,
    );
  }
}
