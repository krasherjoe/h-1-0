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

  Color getColor(ColorScheme cs) {
    switch (this) {
      case DeliveryStatus.pending:
        return cs.onSurfaceVariant;
      case DeliveryStatus.inProgress:
        return cs.primary;
      case DeliveryStatus.completed:
        return cs.tertiary;
      case DeliveryStatus.cancelled:
        return cs.error;
    }
  }
}
