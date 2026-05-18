class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientId,
    this.actorId,
    required this.type,
    required this.title,
    this.body,
    this.entityType,
    this.entityId,
    this.metadata = const {},
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String recipientId;
  final String? actorId;
  final String type;
  final String title;
  final String? body;
  final String? entityType;
  final String? entityId;
  final Map<String, dynamic> metadata;
  final bool isRead;
  final DateTime createdAt;

  bool get isUnread => !isRead;

  bool get canOpenEntity {
    final entity = entityType?.trim().toLowerCase();
    return entityId?.trim().isNotEmpty == true && entity == 'event';
  }

  String get displayTitle {
    final cleanTitle = title.trim();
    if (cleanTitle.isNotEmpty) return cleanTitle;

    switch (type.trim().toLowerCase()) {
      case 'event_join_request':
        return 'Yeni katılım isteği';
      case 'event_join_approved':
        return 'Katılım isteğin onaylandı';
      case 'event_join_rejected':
        return 'Katılım isteğin reddedildi';
      case 'event_join_cancelled':
        return 'Katılım isteği iptal edildi';
      case 'event_left':
        return 'Katılımcı etkinlikten çıktı';
      case 'system':
        return 'Sistem bildirimi';
      default:
        return 'Bildirim';
    }
  }

  String get displayBody => body?.trim() ?? '';

  String get typeLabel {
    switch (type.trim().toLowerCase()) {
      case 'event_join_request':
      case 'event_join_approved':
      case 'event_join_rejected':
      case 'event_join_cancelled':
      case 'event_left':
        return 'Etkinlik';
      case 'follow':
        return 'Topluluk';
      case 'system':
        return 'MaM';
      default:
        return 'Bildirim';
    }
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      recipientId: recipientId,
      actorId: actorId,
      type: type,
      title: title,
      body: body,
      entityType: entityType,
      entityId: entityId,
      metadata: metadata,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final metadataValue = json['metadata'];
    return AppNotification(
      id: json['id'] as String? ?? '',
      recipientId: json['recipient_id'] as String? ?? '',
      actorId: json['actor_id'] as String?,
      type: json['type'] as String? ?? 'system',
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      entityType: json['entity_type'] as String?,
      entityId: json['entity_id'] as String?,
      metadata: metadataValue is Map
          ? Map<String, dynamic>.from(metadataValue)
          : const {},
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
