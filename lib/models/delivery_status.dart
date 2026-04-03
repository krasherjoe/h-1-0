import 'package:flutter/material.dart';

enum DeliveryStatus {
  pending,
  inProgress,
  completed,
  cancelled,
}

extension DeliveryStatusExtension on DeliveryStatus {
  String get displayName {
    switch (this) {
      case DeliveryStatus.pending:
        return '未着手';
      case DeliveryStatus.inProgress:
        return '配送中';
      case DeliveryStatus.completed:
        return '完了';
      case DeliveryStatus.cancelled:
        return 'キャンセル';
    }
  }

  Color get color {
    switch (this) {
      case DeliveryStatus.pending:
        return Colors.grey;
      case DeliveryStatus.inProgress:
        return Colors.blue;
      case DeliveryStatus.completed:
        return Colors.green;
      case DeliveryStatus.cancelled:
        return Colors.red;
    }
  }
}
