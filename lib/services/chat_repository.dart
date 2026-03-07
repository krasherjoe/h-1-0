import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import 'database_helper.dart';

class ChatRepository {
  ChatRepository();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();

  Future<Database> _db() => _dbHelper.database;

  Future<List<ChatMessage>> listMessages({int limit = 200}) async {
    final db = await _db();
    final rows = await db.query(
      'chat_messages',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(_fromRow).toList().reversed.toList();
  }

  Future<void> addOutbound({
    required String clientId,
    required String body,
    int? sequence,
    String? payloadType,
    String? signature,
  }) async {
    final db = await _db();
    final now = DateTime.now().toUtc();
    await db.insert(
      'chat_messages',
      {
        'message_id': _uuid.v4(),
        'client_id': clientId,
        'direction': 'outbound',
        'body': body,
        'created_at': now.millisecondsSinceEpoch,
        'synced': 0,
        'sequence': sequence,
        'payload_type': payloadType,
        'signature': signature,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertInbound(ChatMessage message) async {
    final db = await _db();
    await db.insert(
      'chat_messages',
      {
        'message_id': message.messageId,
        'client_id': message.clientId,
        'direction': 'inbound',
        'body': message.body,
        'created_at': message.createdAt.millisecondsSinceEpoch,
        'synced': 1,
        'delivered_at': DateTime.now().toUtc().millisecondsSinceEpoch,
        'sequence': message.sequence,
        'payload_type': message.payloadType,
        'signature': message.signature,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ChatMessage>> pendingOutbound() async {
    final db = await _db();
    final rows = await db.query('chat_messages', where: 'direction = ? AND synced = 0', whereArgs: ['outbound'], orderBy: 'created_at ASC');
    return rows.map(_fromRow).toList();
  }

  Future<void> markSynced(List<String> messageIds) async {
    if (messageIds.isEmpty) return;
    final db = await _db();
    await db.update(
      'chat_messages',
      {'synced': 1},
      where: 'message_id IN (${List.filled(messageIds.length, '?').join(',')})',
      whereArgs: messageIds,
    );
  }

  ChatMessage _fromRow(Map<String, dynamic> row) {
    return ChatMessage(
      id: row['id'] as int?,
      messageId: row['message_id'] as String,
      clientId: row['client_id'] as String,
      direction: (row['direction'] as String) == 'outbound' ? ChatDirection.outbound : ChatDirection.inbound,
      body: row['body'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int, isUtc: true),
      synced: (row['synced'] as int? ?? 1) == 1,
      deliveredAt: row['delivered_at'] != null ? DateTime.fromMillisecondsSinceEpoch(row['delivered_at'] as int, isUtc: true) : null,
      sequence: row['sequence'] as int?,
      payloadType: row['payload_type'] as String?,
      signature: row['signature'] as String?,
    );
  }
}
