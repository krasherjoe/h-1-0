import 'package:shared_preferences/shared_preferences.dart';

/// クライアント接続設定（サーバーURL / APIキー）
class RemoteConfig {
  static const _kHost = 'remote_host';
  static const _kPort = 'remote_port';
  static const _kApiKey = 'remote_api_key';
  static const _kEnabled = 'remote_enabled';

  String host;
  int port;
  String apiKey;
  bool enabled;

  RemoteConfig({
    this.host = '',
    this.port = 8080,
    this.apiKey = '',
    this.enabled = false,
  });

  String get baseUrl => 'http://$host:$port';
  bool get isValid => host.isNotEmpty && apiKey.isNotEmpty;

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kHost, host);
    await prefs.setInt(_kPort, port);
    await prefs.setString(_kApiKey, apiKey);
    await prefs.setBool(_kEnabled, enabled);
  }

  static Future<RemoteConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    return RemoteConfig(
      host: prefs.getString(_kHost) ?? '',
      port: prefs.getInt(_kPort) ?? 8080,
      apiKey: prefs.getString(_kApiKey) ?? '',
      enabled: prefs.getBool(_kEnabled) ?? false,
    );
  }
}
