import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// ストレージ容量監視サービス
class StorageMonitor {
  static final StorageMonitor _instance = StorageMonitor._internal();
  factory StorageMonitor() => _instance;
  StorageMonitor._internal();

  /// 最小必要空き容量（バイト）: 200MB
  static const int minRequiredBytes = 200 * 1024 * 1024;

  /// 警告閾値（バイト）: 500MB
  static const int warningThresholdBytes = 500 * 1024 * 1024;

  /// 現在の空き容量を取得（バイト）
  Future<int> getAvailableSpace() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final stat = directory.statSync();
      
      // Linuxの場合はdf コマンドで取得
      if (Platform.isLinux || Platform.isAndroid) {
        final result = await Process.run('df', ['-B1', directory.path]);
        if (result.exitCode == 0) {
          final lines = (result.stdout as String).split('\n');
          if (lines.length > 1) {
            final parts = lines[1].split(RegExp(r'\s+'));
            if (parts.length >= 4) {
              return int.tryParse(parts[3]) ?? 0;
            }
          }
        }
      }
      
      // フォールバック: ファイルシステムの情報が取れない場合は十分な容量があると仮定
      return minRequiredBytes * 10;
    } catch (e) {
      print('空き容量取得エラー: $e');
      return minRequiredBytes * 10; // エラー時は十分な容量があると仮定
    }
  }

  /// 書き込み可能かチェック
  Future<bool> canWrite() async {
    final available = await getAvailableSpace();
    return available >= minRequiredBytes;
  }

  /// 警告が必要かチェック
  Future<bool> shouldWarn() async {
    final available = await getAvailableSpace();
    return available < warningThresholdBytes && available >= minRequiredBytes;
  }

  /// 容量不足でブロックすべきかチェック
  Future<bool> shouldBlock() async {
    final available = await getAvailableSpace();
    return available < minRequiredBytes;
  }

  /// 空き容量を人間が読める形式で取得
  Future<String> getAvailableSpaceFormatted() async {
    final bytes = await getAvailableSpace();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
