import 'package:flutter/material.dart';

/// ストレージ容量警告ダイアログ
class StorageWarningDialog extends StatelessWidget {
  final String availableSpace;
  final bool isBlocking;

  const StorageWarningDialog({
    super.key,
    required this.availableSpace,
    this.isBlocking = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: Icon(
        isBlocking ? Icons.error : Icons.warning,
        color: isBlocking ? cs.error : cs.secondary,
        size: 48,
      ),
      title: Text(isBlocking ? 'ストレージ容量不足' : 'ストレージ容量警告'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isBlocking
                ? 'ストレージの空き容量が不足しているため、データの保存ができません。'
                : 'ストレージの空き容量が少なくなっています。',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Text(
            '現在の空き容量: $availableSpace',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            '不要なファイルやアプリを削除して、空き容量を確保してください。',
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    );
  }

  /// 警告ダイアログを表示
  static Future<void> showWarning(BuildContext context, String availableSpace) async {
    await showDialog(
      context: context,
      builder: (context) => StorageWarningDialog(
        availableSpace: availableSpace,
        isBlocking: false,
      ),
    );
  }

  /// ブロッキングダイアログを表示
  static Future<void> showBlocking(BuildContext context, String availableSpace) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StorageWarningDialog(
        availableSpace: availableSpace,
        isBlocking: true,
      ),
    );
  }
}

/// DB復旧完了ダイアログ
class DatabaseRecoveryDialog extends StatelessWidget {
  final String backupPath;

  const DatabaseRecoveryDialog({
    super.key,
    required this.backupPath,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: Icon(
        Icons.restore,
        color: cs.primary,
        size: 48,
      ),
      title: const Text('データベース復旧完了'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'データベースに問題が検出されたため、自動的に初期化しました。',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          const Text(
            '破損したデータベースは以下の場所にバックアップされています：',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              backupPath,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'アプリは正常に起動しましたが、以前のデータは失われています。',
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('了解'),
        ),
      ],
    );
  }

  /// 復旧完了ダイアログを表示
  static Future<void> show(BuildContext context, String backupPath) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DatabaseRecoveryDialog(backupPath: backupPath),
    );
  }
}
