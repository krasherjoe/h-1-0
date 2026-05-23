/// 販売アシスト 1号 サーバーモード（Linuxヘッドレス起動用）
///
/// 使用方法:
///   flutter run -d linux -t lib/main_server.dart
///   または
///   flutter build linux --target lib/main_server.dart
///   ./build/linux/x64/release/bundle/main_server
///
/// 環境変数:
///   HOST (default: 0.0.0.0)
///   PORT (default: 8080)
///   API_KEY (default: changeme)
///   DB_PATH (default: ./h-1_server.db)

import 'dart:io';

import 'package:flutter/material.dart';
import 'server/api_handler.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final host = Platform.environment['HOST'] ?? '0.0.0.0';
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final apiKey = Platform.environment['API_KEY'] ?? 'changeme';

  print('=== 販売アシスト 1号 サーバーモード ===');
  print('Host: $host');
  print('Port: $port');
  print('Starting...');

  final server = AppServer(apiKey, dbPath: Platform.environment['DB_PATH']);
  final httpServer = await server.start(host, port);

  print('Server listening on http://$host:$port');
  print('Health: http://$host:$port/health');

  // シグナルハンドリング
  ProcessSignal.sigint.watch().listen((_) async {
    print('\nShutting down...');
    await httpServer.close(force: true);
    exit(0);
  });

  // ヘッドレスで待機（Flutterのイベントループを維持）
  await Future.delayed(const Duration(days: 365));
}
