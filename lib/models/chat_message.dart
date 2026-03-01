enum ChatDirection { outbound, inbound }

class ChatMessage {
  ChatMessage({
    this.id,
    required this.messageId,
    required this.clientId,
    required this.direction,
    required this.body,
    required this.createdAt,
    this.synced = true,
    this.deliveredAt,
  });

  final int? id;
  final String messageId;
  final String clientId;
  final ChatDirection direction;
  final String body;
  final DateTime createdAt;
  final bool synced;
  final DateTime? deliveredAt;

  ChatMessage copyWith({
    int? id,
    String? messageId,
    String? clientId,
    ChatDirection? direction,
    String? body,
    DateTime? createdAt,
    bool? synced,
    DateTime? deliveredAt,
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
    );
  }
}
