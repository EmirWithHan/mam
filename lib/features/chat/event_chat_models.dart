class EventMessage {
  const EventMessage({
    required this.id,
    required this.eventId,
    required this.senderId,
    required this.message,
    required this.createdAt,
    this.replyToMessageId,
    this.metadata = const {},
  });

  final String id;
  final String eventId;
  final String senderId;
  final String message;
  final DateTime createdAt;
  final String? replyToMessageId;
  final Map<String, dynamic> metadata;

  bool isMine(String? currentUserId) {
    return currentUserId != null && senderId == currentUserId;
  }

  factory EventMessage.fromJson(Map<String, dynamic> json) {
    return EventMessage(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      senderId: json['sender_id'] as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['created_at'].toString()),
      replyToMessageId: json['reply_to_message_id']?.toString(),
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const {},
    );
  }

  static Map<String, dynamic> createPayload({
    required String eventId,
    required String senderId,
    required String message,
    String? replyToMessageId,
    Map<String, dynamic>? metadata,
  }) {
    return {
      'event_id': eventId,
      'sender_id': senderId,
      'message': message.trim(),
      if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
      if (metadata != null) 'metadata': metadata,
    };
  }

  static List<EventMessage> chronological(List<EventMessage> messages) {
    return [...messages]..sort((a, b) {
      final createdAtOrder = a.createdAt.compareTo(b.createdAt);
      if (createdAtOrder != 0) return createdAtOrder;
      return a.id.compareTo(b.id);
    });
  }
}

class EventChatAccess {
  const EventChatAccess({
    required this.canRead,
    required this.canWrite,
    this.reason,
  });

  const EventChatAccess.denied({this.reason})
    : canRead = false,
      canWrite = false;

  final bool canRead;
  final bool canWrite;
  final String? reason;
}
