class EventChatGroup {
  const EventChatGroup({
    required this.eventId,
    required this.title,
    required this.sportType,
    required this.city,
    this.district,
    required this.eventDate,
    required this.status,
    required this.role,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  final String eventId;
  final String title;
  final String sportType;
  final String city;
  final String? district;
  final DateTime eventDate;
  final String status;
  final String role;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  bool get isHost => role == 'host';

  bool get isArchived {
    final archiveAt = eventDate.add(const Duration(hours: 24));
    return DateTime.now().isAfter(archiveAt);
  }

  String get locationLabel {
    final districtValue = district?.trim();
    if (districtValue == null || districtValue.isEmpty) return city;
    return '$city / $districtValue';
  }

  String get dateLabel {
    final month = eventDate.month.toString().padLeft(2, '0');
    final day = eventDate.day.toString().padLeft(2, '0');
    final hour = eventDate.hour.toString().padLeft(2, '0');
    final minute = eventDate.minute.toString().padLeft(2, '0');
    return '$day.$month $hour:$minute';
  }

  String get displaySubtitle {
    final message = lastMessage?.trim();
    if (message != null && message.isNotEmpty) return message;
    if (locationLabel.trim().isNotEmpty) return locationLabel;
    return sportType;
  }

  EventChatGroup copyWith({
    String? lastMessage,
    DateTime? lastMessageAt,
  }) {
    return EventChatGroup(
      eventId: eventId,
      title: title,
      sportType: sportType,
      city: city,
      district: district,
      eventDate: eventDate,
      status: status,
      role: role,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount,
    );
  }

  factory EventChatGroup.fromEventJson({
    required Map<String, dynamic> eventJson,
    required String role,
  }) {
    return EventChatGroup(
      eventId: eventJson['id'] as String,
      title: eventJson['title'] as String,
      sportType: eventJson['sport_type'] as String,
      city: eventJson['city'] as String,
      district: eventJson['district'] as String?,
      eventDate: DateTime.parse(eventJson['event_date'].toString()),
      status: eventJson['status'] as String? ?? 'active',
      role: role,
    );
  }
}
