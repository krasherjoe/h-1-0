import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'sync_preferences.dart';

/// Gmailを経由して送受信する同期メッセージのエンベロープ。
/// JSON → gzip → base64Url でエンコードし、1通ごとにハッシュ/シーケンスを付与する。
class GmailSyncEnvelope {
  GmailSyncEnvelope({
    required this.version,
    required this.sequence,
    required this.messageId,
    required this.clientId,
    required this.payloadType,
    required this.payload,
    required this.createdAt,
    required this.checksum,
    this.signature,
  });

  final int version;
  final int sequence;
  final String messageId;
  final String clientId;
  final String payloadType;
  final Map<String, dynamic> payload;
  final int createdAt;
  final String checksum;
  final String? signature;

  Map<String, dynamic> toMap() => {
        'version': version,
        'sequence': sequence,
        'messageId': messageId,
        'clientId': clientId,
        'payloadType': payloadType,
        'payload': payload,
        'createdAt': createdAt,
        'checksum': checksum,
        if (signature != null) 'signature': signature,
      };

  String encode(GmailEnvelopeEncoding encoding) {
    final jsonStr = jsonEncode(toMap());
    switch (encoding) {
      case GmailEnvelopeEncoding.plainJson:
        return jsonStr;
      case GmailEnvelopeEncoding.base64Only:
        return base64Url.encode(utf8.encode(jsonStr));
      case GmailEnvelopeEncoding.gzipBase64:
      default:
        final compressed = gzip.encode(utf8.encode(jsonStr));
        return base64Url.encode(compressed);
    }
  }

  static GmailSyncEnvelope decode(String encoded, GmailEnvelopeEncoding encoding) {
    String jsonStr;
    switch (encoding) {
      case GmailEnvelopeEncoding.plainJson:
        jsonStr = encoded;
        break;
      case GmailEnvelopeEncoding.base64Only:
        jsonStr = utf8.decode(base64Url.decode(encoded));
        break;
      case GmailEnvelopeEncoding.gzipBase64:
      default:
        Uint8List decodedBytes;
        try {
          decodedBytes = base64Url.decode(encoded);
        } on FormatException {
          decodedBytes = base64.decode(encoded);
        }
        jsonStr = utf8.decode(gzip.decode(decodedBytes));
        break;
    }
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return GmailSyncEnvelope(
      version: (map['version'] as num?)?.toInt() ?? 1,
      sequence: (map['sequence'] as num).toInt(),
      messageId: map['messageId'] as String,
      clientId: map['clientId'] as String,
      payloadType: map['payloadType'] as String,
      payload: (map['payload'] as Map).cast<String, dynamic>(),
      createdAt: (map['createdAt'] as num).toInt(),
      checksum: map['checksum'] as String,
      signature: map['signature'] as String?,
    );
  }

  static GmailSyncEnvelope build({
    required int version,
    required int sequence,
    required String messageId,
    required String clientId,
    required String payloadType,
    required Map<String, dynamic> payload,
    required int createdAt,
    String? signature,
  }) {
    final checksum = _calcChecksum(payload, messageId: messageId, sequence: sequence);
    return GmailSyncEnvelope(
      version: version,
      sequence: sequence,
      messageId: messageId,
      clientId: clientId,
      payloadType: payloadType,
      payload: payload,
      createdAt: createdAt,
      checksum: checksum,
      signature: signature,
    );
  }

  static String _calcChecksum(Map<String, dynamic> payload, {required String messageId, required int sequence}) {
    final payloadJson = jsonEncode(payload);
    final digest = sha256.convert(utf8.encode('$sequence|$messageId|$payloadJson'));
    return digest.toString();
  }
}
