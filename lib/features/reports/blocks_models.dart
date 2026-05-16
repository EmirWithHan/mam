class Block {
  const Block({
    required this.id,
    required this.blockerId,
    required this.blockedId,
    required this.createdAt,
  });

  final String id;
  final String blockerId;
  final String blockedId;
  final DateTime createdAt;

  String get blockedUserId => blockedId;

  factory Block.fromJson(Map<String, dynamic> json) {
    return Block(
      id: json['id'] as String,
      blockerId: json['blocker_id'] as String,
      blockedId: json['blocked_id'] as String,
      createdAt: DateTime.parse(json['created_at'].toString()),
    );
  }
}

class UserBlockState {
  const UserBlockState({
    required this.targetUserId,
    required this.isBlockedByMe,
    required this.isMe,
  });

  final String targetUserId;
  final bool isBlockedByMe;
  final bool isMe;
}
