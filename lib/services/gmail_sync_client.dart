import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;

import '../models/chat_message.dart';
import '../models/gmail_sync_envelope.dart';
import '../models/invoice_sync_payload.dart';
import '../models/sync_preferences.dart';
import 'app_settings_repository.dart';
import 'chat_repository.dart';
import 'google_api_service_base.dart';
import 'invoice_repository.dart';
import 'mothership_client.dart';

class GmailSyncClient extends GoogleApiServiceBase {
  GmailSyncClient({
    ChatRepository? chatRepository,
    AppSettingsRepository? settingsRepository,
    MothershipClient? nodeIdProvider,
    InvoiceRepository? invoiceRepository,
  })  : _chatRepository = chatRepository ?? ChatRepository(),
        _settingsRepository = settingsRepository ?? AppSettingsRepository(),
        _nodeIdProvider = nodeIdProvider ?? MothershipClient(),
        _invoiceRepository = invoiceRepository ?? InvoiceRepository();

  static const _userId = 'me';
  static const _defaultSubjectPrefix = '[Sync:v1]';
  static const _payloadTypeChat = 'chat_message';
  static const _payloadTypeInvoiceSnapshot = 'invoice_snapshot';
  static const _encodingHeader = 'X-Envelope-Encoding';

  final ChatRepository _chatRepository;
  final AppSettingsRepository _settingsRepository;
  final MothershipClient _nodeIdProvider;
  final InvoiceRepository _invoiceRepository;

  static const _syncQuery = 'subject:"$_defaultSubjectPrefix" is:unread';

  Future<void> sync({bool chats = true, bool invoices = true}) async {
    if (!chats && !invoices) return;
    try {
      await withClient((client) async {
        final transport = await _settingsRepository.getSyncTransportMode();
        if (transport == SyncTransportMode.directOnly) {
          debugPrint('[GmailSync] transport=directOnly → Gmail同期をスキップ');
          return;
        }
        final api = gmail.GmailApi(client);
        final labelId = await _ensureSyncLabel(api);
        final clientId = await _nodeIdProvider.ensureClientId();
        final encoding = await _settingsRepository.getGmailEnvelopeEncoding();
        final tasks = <Future<void>>[];
        if (chats) {
          tasks.add(_pushPendingChats(api, clientId, encoding));
        }
        if (invoices) {
          tasks.add(_pushPendingInvoices(api, clientId, encoding));
        }
        tasks.add(_fetchInbound(
          api,
          labelId,
          clientId,
          encoding,
          allowChatPayload: chats,
          allowInvoicePayload: invoices,
        ));
        await Future.wait(tasks);
      });
    } catch (err, stack) {
      debugPrint('[GmailSync] sync failed: $err');
      debugPrint('$stack');
    }
  }

  Future<void> _pushPendingChats(gmail.GmailApi api, String clientId, GmailEnvelopeEncoding encoding) async {
    final pending = await _chatRepository.pendingOutbound();
    if (pending.isEmpty) return;

    final bccAddress = await _settingsRepository.getGmailSyncBccAddress();
    if (bccAddress == null || bccAddress.isEmpty) {
      debugPrint('[GmailSync] skip push: BCCアドレス未設定');
      return;
    }

    final successes = <String>[];

    for (final message in pending) {
      final payloadMap = message.toJson();
      final raw = await _buildEnvelopeRaw(
        bccAddress: bccAddress,
        clientId: clientId,
        messageId: message.messageId,
        payloadType: _payloadTypeChat,
        payload: payloadMap,
        createdAtMs: message.createdAt.millisecondsSinceEpoch,
        encoding: encoding,
      );
      try {
        final response = await api.users.messages.send(
          gmail.Message()..raw = raw,
          _userId,
        );
        successes.add(message.messageId);
        if (response.id != null) {
          await _tagMessage(api, response.id!, labelId: await _settingsRepository.getGmailSyncLabelId());
        }
      } catch (err) {
        debugPrint('[GmailSync] push ${message.messageId} failed: $err');
        break;
      }
    }

    if (successes.isNotEmpty) {
      await _chatRepository.markSynced(successes);
      debugPrint('[GmailSync] pushed ${successes.length} chat messages');
    }
  }

  Future<void> _pushPendingInvoices(gmail.GmailApi api, String clientId, GmailEnvelopeEncoding encoding) async {
    final pending = await _invoiceRepository.pendingSyncSnapshots(limit: 5);
    if (pending.isEmpty) return;

    final bccAddress = await _settingsRepository.getGmailSyncBccAddress();
    if (bccAddress == null || bccAddress.isEmpty) {
      debugPrint('[GmailSync] skip invoice push: BCCアドレス未設定');
      return;
    }

    final synced = <String>[];

    for (final snapshot in pending) {
      final payload = snapshot.toPayload();
      final raw = await _buildEnvelopeRaw(
        bccAddress: bccAddress,
        clientId: clientId,
        messageId: 'invoice:${payload.recordId}:${snapshot.updatedAtMs}',
        payloadType: _payloadTypeInvoiceSnapshot,
        payload: payload.toJson(),
        createdAtMs: snapshot.updatedAtMs,
        encoding: encoding,
      );
      try {
        final response = await api.users.messages.send(
          gmail.Message()..raw = raw,
          _userId,
        );
        synced.add(payload.recordId);
        if (response.id != null) {
          await _tagMessage(api, response.id!, labelId: await _settingsRepository.getGmailSyncLabelId());
        }
      } catch (err) {
        debugPrint('[GmailSync] invoice push ${payload.recordId} failed: $err');
        break;
      }
    }

    if (synced.isNotEmpty) {
      await _invoiceRepository.markSynced(synced);
      debugPrint('[GmailSync] pushed ${synced.length} invoices');
    }
  }

  Future<void> _fetchInbound(
    gmail.GmailApi api,
    String labelId,
    String clientId,
    GmailEnvelopeEncoding defaultEncoding, {
    required bool allowChatPayload,
    required bool allowInvoicePayload,
  }) async {
    final messages = await _listPendingMessages(api);
    if (messages.isEmpty) {
      return;
    }

    final processedIds = <String>[];
    for (final meta in messages) {
      if (meta.id == null) continue;
      try {
        final full = await api.users.messages.get(
          _userId,
          meta.id!,
          format: 'full',
        );
        final handled = await _handleEnvelope(
          full,
          localClientId: clientId,
          defaultEncoding: defaultEncoding,
          allowChatPayload: allowChatPayload,
          allowInvoicePayload: allowInvoicePayload,
        );
        if (handled) {
          processedIds.add(meta.id!);
        }
      } catch (err) {
        debugPrint('[GmailSync] fetch ${meta.id} failed: $err');
      }
    }

    if (processedIds.isNotEmpty) {
      await _ackMessages(api, processedIds, labelId);
      final lastHistoryId = messages.last.historyId;
      if (lastHistoryId != null) {
        await _settingsRepository.setGmailSyncHistoryId(lastHistoryId);
      }
    }
  }

  Future<String> _ensureSyncLabel(gmail.GmailApi api) async {
    final cachedId = await _settingsRepository.getGmailSyncLabelId();
    if (cachedId != null && cachedId.isNotEmpty) {
      return cachedId;
    }
    final labelName = await _settingsRepository.getGmailSyncLabelName();
    final labels = await api.users.labels.list(_userId);
    final existing = labels.labels?.firstWhere(
      (label) => label.name == labelName,
      orElse: () => gmail.Label(),
    );
    if (existing != null && existing.id != null && existing.id!.isNotEmpty) {
      await _settingsRepository.setGmailSyncLabelId(existing.id!);
      return existing.id!;
    }
    final created = await api.users.labels.create(
      gmail.Label()
        ..name = labelName
        ..labelListVisibility = 'labelShow'
        ..messageListVisibility = 'show',
      _userId,
    );
    final labelId = created.id ?? 'Label_1';
    await _settingsRepository.setGmailSyncLabelId(labelId);
    return labelId;
  }

  Future<List<gmail.Message>> _listPendingMessages(gmail.GmailApi api) async {
    final results = <gmail.Message>[];
    String? pageToken;
    do {
      final res = await api.users.messages.list(
        _userId,
        labelIds: ['INBOX'],
        includeSpamTrash: false,
        maxResults: 20,
        pageToken: pageToken,
        q: _syncQuery,
      );
      final messages = res.messages;
      if (messages == null || messages.isEmpty) {
        break;
      }
      results.addAll(messages);
      pageToken = res.nextPageToken;
    } while (pageToken != null);
    return results;
  }

  Future<void> _ackMessages(gmail.GmailApi api, List<String> messageIds, String labelId) async {
    final request = gmail.ModifyMessageRequest()
      ..addLabelIds = [labelId]
      ..removeLabelIds = ['INBOX', 'UNREAD'];
    await Future.wait(
      messageIds.map(
        (id) => api.users.messages.modify(request, _userId, id),
      ),
    );
  }

  Future<void> _tagMessage(gmail.GmailApi api, String messageId, {String? labelId}) async {
    if (labelId == null || labelId.isEmpty) return;
    final request = gmail.ModifyMessageRequest()
      ..addLabelIds = [labelId];
    try {
      await api.users.messages.modify(request, _userId, messageId);
    } catch (err) {
      debugPrint('[GmailSync] label assign failed: $err');
    }
  }

  Future<bool> _handleEnvelope(
    gmail.Message message, {
    required String localClientId,
    required GmailEnvelopeEncoding defaultEncoding,
    required bool allowChatPayload,
    required bool allowInvoicePayload,
  }) async {
    final data = _extractBody(message);
    if (data == null || data.isEmpty) return false;
    try {
      final encoding = _encodingFromHeader(message) ?? defaultEncoding;
      final envelope = GmailSyncEnvelope.decode(data, encoding);
      if (envelope.clientId == localClientId) {
        return false;
      }
      switch (envelope.payloadType) {
        case _payloadTypeChat:
          if (!allowChatPayload) {
            return false;
          }
          final chat = ChatMessage.fromJson(envelope.payload)
              .copyWith(direction: ChatDirection.inbound, synced: true, sequence: envelope.sequence);
          await _chatRepository.upsertInbound(chat);
          return true;
        case _payloadTypeInvoiceSnapshot:
          if (!allowInvoicePayload) {
            return false;
          }
          final payload = InvoiceSyncPayload.fromJson(envelope.payload);
          await _invoiceRepository.applyInboundSnapshot(payload);
          return true;
        default:
          debugPrint('[GmailSync] unknown payload type ${envelope.payloadType}');
          return false;
      }
    } catch (err) {
      debugPrint('[GmailSync] envelope parse failed: $err');
      return false;
    }
  }

  String? _extractBody(gmail.Message message) {
    final payload = message.payload;
    if (payload == null) return null;
    final data = _decodePart(payload);
    if (data != null && data.isNotEmpty) {
      return data;
    }
    if (payload.parts != null) {
      for (final part in payload.parts!) {
        final partData = _decodePart(part);
        if (partData != null && partData.isNotEmpty) {
          return partData;
        }
      }
    }
    return null;
  }

  String? _decodePart(gmail.MessagePart part) {
    final body = part.body;
    final data = body?.data;
    if (data == null || data.isEmpty) return null;
    final normalized = data.replaceAll('-', '+').replaceAll('_', '/');
    var padding = normalized.length % 4;
    var buffer = normalized;
    if (padding > 0) {
      padding = 4 - padding;
      buffer += '=' * padding;
    }
    final bytes = base64.decode(buffer);
    return utf8.decode(bytes);
  }

  Future<String> _buildEnvelopeRaw({
    required String bccAddress,
    required String clientId,
    required String messageId,
    required String payloadType,
    required Map<String, dynamic> payload,
    required int createdAtMs,
    required GmailEnvelopeEncoding encoding,
  }) async {
    final sequence = await _settingsRepository.nextGmailSequence();
    final envelope = GmailSyncEnvelope.build(
      version: 1,
      sequence: sequence,
      messageId: messageId,
      clientId: clientId,
      payloadType: payloadType,
      payload: payload,
      createdAt: createdAtMs,
    );
    final encoded = envelope.encode(encoding);
    final subject = '$_defaultSubjectPrefix $messageId#$sequence';
    const crlf = '\r\n';
    final buffer = StringBuffer()
      ..write('To: $bccAddress$crlf')
      ..write('Bcc: $bccAddress$crlf')
      ..write('Subject: $subject$crlf')
      ..write('X-Client-Id: $clientId$crlf')
      ..write('X-Sequence: $sequence$crlf')
      ..write('$_encodingHeader: ${encoding.headerValue}$crlf')
      ..write('Content-Type: text/plain; charset="UTF-8"$crlf')
      ..write(crlf)
      ..write(encoded);
    return base64Url.encode(utf8.encode(buffer.toString()));
  }

  GmailEnvelopeEncoding? _encodingFromHeader(gmail.Message message) {
    final headers = message.payload?.headers;
    if (headers == null) return null;
    for (final header in headers) {
      final name = header.name?.toLowerCase();
      if (name == null) continue;
      if (name == _encodingHeader.toLowerCase()) {
        return GmailEnvelopeEncodingExt.fromHeader(header.value);
      }
    }
    return null;
  }
}
