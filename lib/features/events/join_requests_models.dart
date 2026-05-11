class EventJoinRequest {
  const EventJoinRequest({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String eventId;
  final String userId;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isCancelled => status == 'cancelled';

  factory EventJoinRequest.fromJson(Map<String, dynamic> json) {
    return EventJoinRequest(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      userId: json['user_id'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'].toString()),
      updatedAt: DateTime.parse(json['updated_at'].toString()),
    );
  }
}

class HostJoinRequestView {
  const HostJoinRequestView({required this.request});

  final EventJoinRequest request;
}
