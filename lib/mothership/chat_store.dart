import 'dart:convert';
import 'dart:io';

class ChatEnvelope {
  ChatEnvelope({required this.messageId, required this.body, required this.createdAt});

  final String messageId;
  final String body;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'messageId': messageId,
        'body': body,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory ChatEnvelope.fromJson(Map<String, dynamic> json) {
    return ChatEnvelope(
      messageId: json['messageId'] as String,
      body: json['body'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int, isUtc: true),
    );
  }
}

class MothershipChatStore {
  MothershipChatStore(this.rootDir);

  final Directory rootDir;

  Future<void> init() async {
    if (!await rootDir.exists()) {
      await rootDir.create(recursive: true);
    }
  }

  Future<void> appendInbound(String clientId, List<ChatEnvelope> messages) async {
    if (messages.isEmpty) return;
    final file = await _logFile(clientId);
    final sink = file.openWrite(mode: FileMode.append);
    for (final message in messages) {
      sink.writeln(jsonEncode(message.toJson()));
    }
    await sink.flush();
    await sink.close();
  }

  Future<List<ChatEnvelope>> pendingOutbound(String clientId) async {
    final file = await _outboxFile(clientId);
    if (!await file.exists()) return [];
    try {
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => ChatEnvelope.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> enqueueOutbound(String clientId, List<ChatEnvelope> messages) async {
    if (messages.isEmpty) return;
    final current = await pendingOutbound(clientId);
    final combined = [...current, ...messages];
    final file = await _outboxFile(clientId);
    await file.writeAsString(jsonEncode(combined.map((e) => e.toJson()).toList()));
  }

  Future<void> acknowledge(String clientId, List<String> messageIds) async {
    if (messageIds.isEmpty) return;
    final file = await _outboxFile(clientId);
    if (!await file.exists()) return;
    final current = await pendingOutbound(clientId);
    final filtered = current.where((m) => !messageIds.contains(m.messageId)).toList();
    if (filtered.isEmpty) {
      await file.delete();
    } else {
      await file.writeAsString(jsonEncode(filtered.map((e) => e.toJson()).toList()));
    }
  }

  Future<File> _logFile(String clientId) async {
    final dir = Directory('${rootDir.path}/$clientId');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}/log.jsonl');
  }

  Future<File> _outboxFile(String clientId) async {
    final dir = Directory('${rootDir.path}/$clientId');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}/outbox.json');
  }
}
