import 'dart:io';

class MothershipConfig {
  MothershipConfig({
    required this.host,
    required this.port,
    required this.apiKey,
    required this.dataDirectory,
  });

  factory MothershipConfig.fromEnv() {
    final env = Platform.environment;
    final host = env['MOTHERSHIP_HOST'] ?? '0.0.0.0';
    final port = int.tryParse(env['MOTHERSHIP_PORT'] ?? '') ?? 8787;
    final apiKey = env['MOTHERSHIP_API_KEY'] ?? 'TEST_MOTHERSHIP_KEY';
    final dataDirPath = env['MOTHERSHIP_DATA_DIR'] ?? 'data/mothership';
    return MothershipConfig(
      host: host,
      port: port,
      apiKey: apiKey,
      dataDirectory: Directory(dataDirPath),
    );
  }

  final String host;
  final int port;
  final String apiKey;
  final Directory dataDirectory;
}
