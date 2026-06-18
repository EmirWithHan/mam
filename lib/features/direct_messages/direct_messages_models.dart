class DirectParticipant {
  const DirectParticipant({
    required this.userId,
    this.username,
    this.firstName,
    this.avatarUrl,
    this.lastReadAt,
    this.lastReadMessageId,
  });

  final String userId;
  final String? username;
  final String? firstName;
  final String? avatarUrl;
  final DateTime? lastReadAt;
  final String? lastReadMessageId;

  String get displayName {
    final first = firstName?.trim();
    if (first != null && first.isNotEmpty) return first;
    final user = username?.trim();
    if (user != null && user.isNotEmpty) return user;
    return 'Katılımcı';
  }

  factory DirectParticipant.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return DirectParticipant(
      userId: json['user_id'] as String,
      username: profile?['username'] as String?,
      firstName: profile?['first_name'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
      lastReadAt: json['last_read_at'] != null
          ? DateTime.tryParse(json['last_read_at'].toString())
          : null,
      lastReadMessageId: json['last_read_message_id']?.toString(),
    );
  }

  DirectParticipant copyWith({
    String? username,
    String? firstName,
    String? avatarUrl,
  }) {
    return DirectParticipant(
      userId: userId,
      username: username ?? this.username,
      firstName: firstName ?? this.firstName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastReadAt: lastReadAt,
      lastReadMessageId: lastReadMessageId,
    );
  }
}

class DirectConversation {
  const DirectConversation({
    required this.id,
    required this.pairKey,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.lastMessageAt,
    this.lastMessagePreview,
    required this.participants,
  });

  final String id;
  final String pairKey;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastMessageAt;
  final String? lastMessagePreview;
  final List<DirectParticipant> participants;

  DirectParticipant? getOtherParticipant(String? currentUserId) {
    if (currentUserId == null) return null;
    for (final p in participants) {
      if (p.userId != currentUserId) return p;
    }
    return null;
  }

  bool hasUnread(String? currentUserId) {
    if (currentUserId == null) return false;
    DirectParticipant? me;
    for (final p in participants) {
      if (p.userId == currentUserId) {
        me = p;
        break;
      }
    }
    if (me == null) return false;
    final myLastReadAt = me.lastReadAt;
    if (myLastReadAt == null) return lastMessagePreview != null;
    return lastMessageAt.isAfter(myLastReadAt);
  }

  factory DirectConversation.fromJson(Map<String, dynamic> json) {
    final parts = (json['direct_conversation_participants'] as List? ?? [])
        .map((p) => DirectParticipant.fromJson(Map<String, dynamic>.from(p)))
        .toList();

    return DirectConversation(
      id: json['id'] as String,
      pairKey: json['pair_key'] as String,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'].toString()),
      updatedAt: DateTime.parse(json['updated_at'].toString()),
      lastMessageAt: DateTime.parse(json['last_message_at'].toString()),
      lastMessagePreview: json['last_message_preview'] as String?,
      participants: parts,
    );
  }

  DirectConversation copyWith({List<DirectParticipant>? participants}) {
    return DirectConversation(
      id: id,
      pairKey: pairKey,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastMessageAt: lastMessageAt,
      lastMessagePreview: lastMessagePreview,
      participants: participants ?? this.participants,
    );
  }
}

class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.conversationId,
    required this.senderUserId,
    required this.body,
    required this.createdAt,
    this.replyToMessageId,
  });

  final String id;
  final String conversationId;
  final String senderUserId;
  final String body;
  final DateTime createdAt;
  final String? replyToMessageId;

  bool isMine(String? currentUserId) {
    return currentUserId != null && senderUserId == currentUserId;
  }

  factory DirectMessage.fromJson(Map<String, dynamic> json) {
    return DirectMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderUserId: json['sender_user_id'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'].toString()),
      replyToMessageId: json['reply_to_message_id']?.toString(),
    );
  }
}
