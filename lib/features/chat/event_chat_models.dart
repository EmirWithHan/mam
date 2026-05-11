class EventMessage {
  const EventMessage({
    required this.id,
    required this.eventId,
    required this.senderId,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String eventId;
  final String senderId;
  final String message;
  final DateTime createdAt;

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
    );
  }

  static Map<String, dynamic> createPayload({
    required String eventId,
    required String senderId,
    required String message,
  }) {
    return {
      'event_id': eventId,
      'sender_id': senderId,
      'message': message.trim(),
    };
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
