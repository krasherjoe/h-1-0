import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

import 'chat_store.dart';
import 'config.dart';
import 'data_store.dart';

class MothershipServer {
  MothershipServer({required this.config, required this.dataStore, required this.chatStore});

  final MothershipConfig config;
  final MothershipDataStore dataStore;
  final MothershipChatStore chatStore;

  Future<HttpServer> start() async {
    final router = Router()
      ..post('/sync/heartbeat', _handleHeartbeat)
      ..post('/sync/hash', _handleHash)
      ..post('/chat/send', _handleChatSend)
      ..get('/chat/pending', _handleChatPending)
      ..post('/chat/ack', _handleChatAck)
      ..get('/status', _handleStatus)
      ..get('/', _handleDashboard);

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_apiKeyMiddleware(config.apiKey))
        .addHandler(router);

    final server = await serve(handler, config.host, config.port);
    return server;
  }

  Middleware _apiKeyMiddleware(String expectedKey) {
    return (innerHandler) {
      return (request) async {
        // Dashboard ('/')は無認証、その他は API キーを要求
        if (request.url.path.isNotEmpty && request.url.path != 'status') {
          final key = request.headers['x-api-key'];
          if (key != expectedKey) {
            return Response(401, body: 'Invalid API key');
          }
        }
        return innerHandler(request);
      };
    };
  }

  Future<Response> _handleHeartbeat(Request request) async {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final clientId = json['clientId'] as String?;
    if (clientId == null || clientId.isEmpty) {
      return Response(400, body: 'clientId is required');
    }
    final remainingSeconds = json['remainingLifespanSeconds'] as int?;
    await dataStore.recordHeartbeat(
      clientId: clientId,
      remaining: remainingSeconds != null ? Duration(seconds: remainingSeconds) : null,
    );
    return Response.ok('ok');
  }

  Future<Response> _handleHash(Request request) async {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final clientId = json['clientId'] as String?;
    final hash = json['hash'] as String?;
    if (clientId == null || hash == null) {
      return Response(400, body: 'clientId and hash are required');
    }
    await dataStore.recordHash(clientId: clientId, hash: hash);
    return Response.ok('ok');
  }

  Future<Response> _handleChatSend(Request request) async {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final clientId = json['clientId'] as String?;
    if (clientId == null || clientId.isEmpty) {
      return Response(400, body: 'clientId is required');
    }
    final messages = (json['messages'] as List?) ?? [];
    final envelopes = messages
        .whereType<Map>()
        .map((e) => ChatEnvelope(
              messageId: e['messageId'] as String,
              body: e['body'] as String,
              createdAt: DateTime.fromMillisecondsSinceEpoch((e['createdAt'] as int?) ?? 0, isUtc: true),
            ))
        .toList();
    await chatStore.appendInbound(clientId, envelopes);
    return Response.ok(jsonEncode({'stored': envelopes.length}), headers: {'content-type': 'application/json'});
  }

  Future<Response> _handleChatPending(Request request) async {
    final clientId = request.url.queryParameters['clientId'];
    if (clientId == null || clientId.isEmpty) {
      return Response(400, body: 'clientId is required');
    }
    final messages = await chatStore.pendingOutbound(clientId);
    final payload = {'messages': messages.map((e) => e.toJson()).toList()};
    return Response.ok(jsonEncode(payload), headers: {'content-type': 'application/json'});
  }

  Future<Response> _handleChatAck(Request request) async {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final clientId = json['clientId'] as String?;
    if (clientId == null || clientId.isEmpty) {
      return Response(400, body: 'clientId is required');
    }
    final delivered = (json['delivered'] as List?)?.cast<String>() ?? [];
    await chatStore.acknowledge(clientId, delivered);
    return Response.ok('ok');
  }

  Future<Response> _handleStatus(Request request) async {
    final status = dataStore.listStatuses().map((e) => e.toJson()).toList();
    return Response.ok(jsonEncode({'clients': status}), headers: {'content-type': 'application/json'});
  }

  Future<Response> _handleDashboard(Request request) async {
    final rows = dataStore.listStatuses().map((status) {
      final lastSync = status.lastSync?.toIso8601String() ?? '-';
      final remaining = status.remainingLifespan != null
          ? '${status.remainingLifespan!.inHours ~/ 24}d ${status.remainingLifespan!.inHours % 24}h'
          : '-';
      return '<tr><td>${status.clientId}</td><td>$lastSync</td><td>${status.lastHash ?? '-'}</td><td>$remaining</td></tr>';
    }).join();

    final html = '''
<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="utf-8" />
  <title>Mothership Dashboard</title>
  <style>
    body { font-family: sans-serif; margin: 24px; }
    table { width: 100%; border-collapse: collapse; }
    th, td { border: 1px solid #ccc; padding: 8px; text-align: left; }
    th { background: #f5f5f5; }
  </style>
</head>
<body>
  <h1>母艦お局様 - ステータス</h1>
  <table>
    <thead>
      <tr>
        <th>Client ID</th>
        <th>Last Sync</th>
        <th>Last Hash</th>
        <th>Remaining</th>
      </tr>
    </thead>
    <tbody>
      $rows
    </tbody>
  </table>
</body>
</html>
''';

    return Response.ok(html, headers: {'content-type': 'text/html; charset=utf-8'});
  }
}
