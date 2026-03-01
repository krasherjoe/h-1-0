import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import 'chat_repository.dart';
import 'mothership_client.dart';

class MothershipChatClient {
  MothershipChatClient({ChatRepository? repository, MothershipClient? baseClient, http.Client? httpClient})
      : _repository = repository ?? ChatRepository(),
        _baseClient = baseClient ?? MothershipClient(),
        _httpClient = httpClient;

  final ChatRepository _repository;
  final MothershipClient _baseClient;
  final http.Client? _httpClient;

  Future<void> sync() async {
    await Future.wait([_pushPending(), _fetchInbound()]);
  }

  Future<void> _pushPending() async {
    final config = await _baseClient.loadConfig();
    if (config == null) {
      debugPrint('[ChatSync] skip push: config missing');
      return;
    }
    final clientId = await _baseClient.ensureClientId();
    final pending = await _repository.pendingOutbound();
    if (pending.isEmpty) return;
    final client = _httpClient ?? http.Client();
    try {
      final payload = {
        'clientId': clientId,
        'messages': pending
            .map((m) => {
                  'messageId': m.messageId,
                  'body': m.body,
                  'createdAt': m.createdAt.millisecondsSinceEpoch,
                })
            .toList(),
      };
      final res = await client.post(
        config.chatSendUri,
        headers: {
          'content-type': 'application/json',
          'x-api-key': config.apiKey,
        },
        body: jsonEncode(payload),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        await _repository.markSynced(pending.map((e) => e.messageId).toList());
        debugPrint('[ChatSync] pushed ${pending.length} msgs');
      } else {
        debugPrint('[ChatSync] push failed ${res.statusCode} ${res.body}');
      }
    } catch (err) {
      debugPrint('[ChatSync] push error $err');
    } finally {
      if (_httpClient == null) client.close();
    }
  }

  Future<void> _fetchInbound() async {
    final config = await _baseClient.loadConfig();
    if (config == null) return;
    final clientId = await _baseClient.ensureClientId();
    final client = _httpClient ?? http.Client();
    try {
      final uri = config.chatPendingUri.replace(queryParameters: {'clientId': clientId});
      final res = await client.get(uri, headers: {'x-api-key': config.apiKey});
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        final messages = (decoded['messages'] as List?) ?? [];
        final ackIds = <String>[];
        for (final raw in messages.cast<Map>()) {
          final msg = ChatMessage(
            messageId: raw['messageId'] as String,
            clientId: clientId,
            direction: ChatDirection.inbound,
            body: raw['body'] as String,
            createdAt: DateTime.fromMillisecondsSinceEpoch((raw['createdAt'] as int?) ?? 0, isUtc: true),
            synced: true,
          );
          await _repository.upsertInbound(msg);
          ackIds.add(msg.messageId);
        }
        if (ackIds.isNotEmpty) {
          await _ack(config, clientId, ackIds);
        }
      } else {
        debugPrint('[ChatSync] fetch failed ${res.statusCode} ${res.body}');
      }
    } catch (err) {
      debugPrint('[ChatSync] fetch error $err');
    } finally {
      if (_httpClient == null) client.close();
    }
  }

  Future<void> _ack(MothershipEndpointConfig config, String clientId, List<String> ids) async {
    final client = _httpClient ?? http.Client();
    try {
      await client.post(
        config.chatAckUri,
        headers: {
          'content-type': 'application/json',
          'x-api-key': config.apiKey,
        },
        body: jsonEncode({'clientId': clientId, 'delivered': ids}),
      );
    } catch (err) {
      debugPrint('[ChatSync] ack error $err');
    } finally {
      if (_httpClient == null) client.close();
    }
  }
}
