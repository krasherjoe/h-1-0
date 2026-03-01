import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../utils/build_expiry_info.dart';
import 'app_settings_repository.dart';

class MothershipClient {
  MothershipClient({AppSettingsRepository? settingsRepository, http.Client? httpClient})
      : _settingsRepository = settingsRepository ?? AppSettingsRepository(),
        _httpClient = httpClient;

  final AppSettingsRepository _settingsRepository;
  final http.Client? _httpClient;

  static const _clientIdKey = 'mothership_client_id';
  static const _hostSettingKey = 'external_host';
  static const _apiKeySettingKey = 'external_pass';

  Future<void> sendHeartbeat(BuildExpiryInfo expiryInfo) async {
    final config = await loadConfig();
    if (config == null) {
      debugPrint('[Mothership] Heartbeat skipped: config not set');
      return;
    }
    final clientId = await ensureClientId();
    final remaining = expiryInfo.remaining?.inSeconds;
    await _postJson(
      uri: config.heartbeatUri,
      apiKey: config.apiKey,
      payload: {
        'clientId': clientId,
        if (remaining != null) 'remainingLifespanSeconds': remaining,
      },
      logLabel: 'heartbeat',
    );
  }

  Future<void> sendHash(String hash) async {
    final config = await loadConfig();
    if (config == null) {
      debugPrint('[Mothership] Hash push skipped: config not set');
      return;
    }
    final clientId = await ensureClientId();
    await _postJson(
      uri: config.hashUri,
      apiKey: config.apiKey,
      payload: {
        'clientId': clientId,
        'hash': hash,
      },
      logLabel: 'hash',
    );
  }

  Future<MothershipEndpointConfig?> loadConfig() async {
    final host = (await _settingsRepository.getString(_hostSettingKey))?.trim();
    final apiKey = (await _settingsRepository.getString(_apiKeySettingKey))?.trim();
    if (host == null || host.isEmpty || apiKey == null || apiKey.isEmpty) {
      return null;
    }
    try {
      final base = _normalizeBaseUri(host);
      return MothershipEndpointConfig(
        apiKey: apiKey,
        heartbeatUri: base.resolve('/sync/heartbeat'),
        hashUri: base.resolve('/sync/hash'),
        chatSendUri: base.resolve('/chat/send'),
        chatPendingUri: base.resolve('/chat/pending'),
        chatAckUri: base.resolve('/chat/ack'),
      );
    } on FormatException catch (err) {
      debugPrint('[Mothership] Invalid host "$host": $err');
      return null;
    }
  }

  Uri _normalizeBaseUri(String host) {
    var normalized = host.trim();
    if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
      normalized = 'http://$normalized';
    }
    if (!normalized.endsWith('/')) {
      normalized = '$normalized/';
    }
    return Uri.parse(normalized);
  }

  Future<String> ensureClientId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_clientIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final newId = const Uuid().v4();
    await prefs.setString(_clientIdKey, newId);
    return newId;
  }

  Future<void> _postJson({
    required Uri uri,
    required String apiKey,
    required Map<String, dynamic> payload,
    required String logLabel,
  }) async {
    final client = _httpClient ?? http.Client();
    try {
      final response = await client.post(
        uri,
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
          'x-api-key': apiKey,
        },
        body: jsonEncode(payload),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('[Mothership] $logLabel OK (${response.statusCode})');
      } else {
        debugPrint('[Mothership] $logLabel failed: ${response.statusCode} ${response.body}');
      }
    } catch (err, stack) {
      debugPrint('[Mothership] $logLabel error: $err');
      debugPrint('$stack');
    } finally {
      if (_httpClient == null) {
        client.close();
      }
    }
  }
}

class MothershipEndpointConfig {
  MothershipEndpointConfig({
    required this.apiKey,
    required this.heartbeatUri,
    required this.hashUri,
    required this.chatSendUri,
    required this.chatPendingUri,
    required this.chatAckUri,
  });

  final String apiKey;
  final Uri heartbeatUri;
  final Uri hashUri;
  final Uri chatSendUri;
  final Uri chatPendingUri;
  final Uri chatAckUri;
}
