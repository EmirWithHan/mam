class Follow {
  const Follow({
    required this.id,
    required this.followerId,
    required this.followingId,
    required this.createdAt,
  });

  final String id;
  final String followerId;
  final String followingId;
  final DateTime createdAt;

  factory Follow.fromJson(Map<String, dynamic> json) {
    return Follow(
      id: json['id'] as String,
      followerId: json['follower_id'] as String,
      followingId: json['following_id'] as String,
      createdAt: DateTime.parse(json['created_at'].toString()),
    );
  }
}

class FollowStats {
  const FollowStats({
    required this.targetUserId,
    required this.followerCount,
    required this.followingCount,
    required this.isFollowedByMe,
    required this.isMe,
  });

  final String targetUserId;
  final int followerCount;
  final int followingCount;
  final bool isFollowedByMe;
  final bool isMe;

  FollowStats copyWith({
    String? targetUserId,
    int? followerCount,
    int? followingCount,
    bool? isFollowedByMe,
    bool? isMe,
  }) {
    return FollowStats(
      targetUserId: targetUserId ?? this.targetUserId,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
      isFollowedByMe: isFollowedByMe ?? this.isFollowedByMe,
      isMe: isMe ?? this.isMe,
    );
  }
}
