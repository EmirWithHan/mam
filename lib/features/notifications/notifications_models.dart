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

  bool get canOpenEntity =>
      opensEvent || opensProfile || opensDirectMessage || opensEventChat;

  bool get opensEvent {
    return entityId?.trim().isNotEmpty == true &&
        entityType?.trim().toLowerCase() == 'event' &&
        type.trim().toLowerCase() != 'message';
  }

  bool get opensProfile {
    final entity = entityType?.trim().toLowerCase();
    return entityId?.trim().isNotEmpty == true &&
        (entity == 'profile' || entity == 'user' || entity == 'profile/user');
  }

  bool get opensDirectMessage {
    return entityId?.trim().isNotEmpty == true &&
        entityType?.trim().toLowerCase() == 'direct_message';
  }

  bool get opensEventChat {
    return entityId?.trim().isNotEmpty == true &&
        type.trim().toLowerCase() == 'message' &&
        entityType?.trim().toLowerCase() == 'event';
  }

  bool get isFollowRequest {
    return type.trim().toLowerCase() == 'follow_request' &&
        entityId?.trim().isNotEmpty == true;
  }

  String get followRequestStatus {
    final value = metadata['request_status'] ?? metadata['status'];
    return value?.toString().trim().toLowerCase() ?? 'pending';
  }

  bool get canRespondToFollowRequest {
    return isFollowRequest && followRequestStatus == 'pending';
  }

  bool get isBusinessEventConfirmRequired {
    return type.trim().toLowerCase() == 'business_event_confirm_required' &&
        opensEvent;
  }

  String get displayTitle {
    return switch (type.trim().toLowerCase()) {
      'event_join_request' => 'Yeni katılım isteği',
      'business_event_confirm_required' => 'Katılımını doğrula',
      'event_join_approved' => 'Katılım isteğin onaylandı',
      'event_join_rejected' => 'Katılım isteğin reddedildi',
      'event_join_cancelled' => 'Katılım isteği iptal edildi',
      'event_left' => 'Bir katılımcı etkinlikten ayrıldı',
      'follow' => 'Yeni takipçi',
      'follow_request' => 'Takip isteği',
      'follow_request_approved' => 'Takip isteğin onaylandı',
      'follow_request_rejected' => 'Takip isteğin reddedildi',
      'system' => 'Sistem bildirimi',
      'message' => title.trim().isEmpty ? 'Yeni Mesaj' : title.trim(),
      _ => title.trim().isEmpty ? 'Bildirim' : title.trim(),
    };
  }

  String get displayBody {
    final cleanBody = body?.trim() ?? '';
    if (cleanBody.isNotEmpty) return cleanBody;

    return switch (type.trim().toLowerCase()) {
      'event_join_request' => 'Etkinliğin için yeni bir katılım isteği var.',
      'business_event_confirm_required' =>
        'İşletme etkinliğine katılımın onaylandı. Yerini ayırmak için katılımını doğrula.',
      'event_join_approved' =>
        'Katılım isteğin ev sahibi tarafından onaylandı.',
      'event_join_rejected' =>
        'Katılım isteğin ev sahibi tarafından reddedildi.',
      'event_join_cancelled' => 'Bir katılım isteği iptal edildi.',
      'event_left' => 'Onaylı bir katılımcı etkinlikten ayrıldı.',
      'follow' => 'Seni takip etmeye başlayan yeni biri var.',
      'follow_request' => 'Yeni bir takip isteğin var.',
      'follow_request_approved' => 'Takip isteğin onaylandı.',
      'follow_request_rejected' => 'Takip isteğin reddedildi.',
      'system' => 'Akanzi güncellemesi.',
      'message' => 'Yeni bir mesajın var.',
      _ => '',
    };
  }

  String get typeLabel {
    return switch (type.trim().toLowerCase()) {
      'event_join_request' => 'Katılım',
      'business_event_confirm_required' => 'Etkinlik',
      'event_join_approved' ||
      'event_join_rejected' ||
      'event_join_cancelled' ||
      'event_left' => 'Etkinlik',
      'follow' => 'Sosyal',
      'follow_request' ||
      'follow_request_approved' ||
      'follow_request_rejected' => 'Sosyal',
      'system' => 'Akanzi',
      _ => 'Bildirim',
    };
  }

  AppNotification copyWith({bool? isRead, Map<String, dynamic>? metadata}) {
    return AppNotification(
      id: id,
      recipientId: recipientId,
      actorId: actorId,
      type: type,
      title: title,
      body: body,
      entityType: entityType,
      entityId: entityId,
      metadata: metadata ?? this.metadata,
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
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class PushTokenRegistration {
  const PushTokenRegistration({required this.token, required this.platform});

  final String token;
  final String platform;

  bool get isValid {
    return token.trim().length > 20 &&
        (platform == 'android' || platform == 'ios' || platform == 'web');
  }

  Map<String, dynamic> toUpsertJson({required String userId}) {
    return {
      'user_id': userId,
      'token': token.trim(),
      'platform': platform,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
