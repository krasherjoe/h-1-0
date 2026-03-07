enum ChatDirection { outbound, inbound }

class ChatMessage {
  ChatMessage({
    this.id,
    required this.messageId,
    required this.clientId,
    required this.direction,
    required this.body,
    required this.createdAt,
    this.synced = false,
    this.deliveredAt,
    this.sequence,
    this.payloadType,
    this.signature,
  });

  final int? id;
  final String messageId;
  final String clientId;
  final ChatDirection direction;
  final String body;
  final DateTime createdAt;
  final bool synced;
  final DateTime? deliveredAt;
  final int? sequence;
  final String? payloadType;
  final String? signature;

  Map<String, dynamic> toJson() => {
        'messageId': messageId,
        'clientId': clientId,
        'direction': direction.name,
        'body': body,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'sequence': sequence,
        'payloadType': payloadType,
        'signature': signature,
      };

  static ChatMessage fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      messageId: json['messageId'] as String,
      clientId: json['clientId'] as String,
      direction: (json['direction'] as String) == 'outbound' ? ChatDirection.outbound : ChatDirection.inbound,
      body: json['body'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int, isUtc: true),
      sequence: json['sequence'] as int?,
      payloadType: json['payloadType'] as String?,
      signature: json['signature'] as String?,
      synced: (json['synced'] as bool?) ?? true,
    );
  }

  ChatMessage copyWith({
    int? id,
    String? messageId,
    String? clientId,
    ChatDirection? direction,
    String? body,
    DateTime? createdAt,
    bool? synced,
    DateTime? deliveredAt,
    int? sequence,
    String? payloadType,
    String? signature,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      clientId: clientId ?? this.clientId,
      direction: direction ?? this.direction,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      sequence: sequence ?? this.sequence,
      payloadType: payloadType ?? this.payloadType,
      signature: signature ?? this.signature,
    );
  }
}
