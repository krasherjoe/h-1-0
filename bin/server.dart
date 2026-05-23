/// 販売アシスト 1号 サーバーモード
/// dart run bin/server.dart
///
/// 同一コードベースでサーバーとして稼働。
/// クライアント（Android）からREST API経由でデータ操作を行う。
///
/// 環境変数:
///   HOST (default: 0.0.0.0)
///   PORT (default: 8080)
///   API_KEY (default: changeme)
///   DB_PATH (default: ./h-1_server.db)
library;

import 'dart:io';

import 'package:h_1/server/api_handler.dart';

Future<void> main(List<String> args) async {
  final host = Platform.environment['HOST'] ?? '0.0.0.0';
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final apiKey = Platform.environment['API_KEY'] ?? 'changeme';

  stdout.writeln('=== 販売アシスト 1号 サーバーモード ===');
  stdout.writeln('Host: $host');
  stdout.writeln('Port: $port');
  stdout.writeln('Starting...');

  final server = AppServer(apiKey, dbPath: Platform.environment['DB_PATH']);
  final httpServer = await server.start(host, port);

  stdout.writeln('Server listening on http://$host:$port');
  stdout.writeln('Health: http://$host:$port/health');
  stdout.writeln('Tables: http://$host:$port/tables');
  stdout.writeln('');

  ProcessSignal.sigint.watch().listen((_) async {
    stdout.writeln('\nShutting down...');
    await httpServer.close(force: true);
    exit(0);
  });
}
