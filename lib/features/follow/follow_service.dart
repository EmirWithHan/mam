import '../../services/rate_limit_service.dart';
import '../../services/supabase_service.dart';
import 'follow_models.dart';

class FollowService {
  const FollowService({
    RateLimitService rateLimitService = const RateLimitService(),
  }) : _rateLimitService = rateLimitService;

  final RateLimitService _rateLimitService;

  String? get currentUserId => SupabaseService.client.auth.currentUser?.id;

  Future<FollowStats> fetchFollowStats(String targetUserId) async {
    final userId = currentUserId;
    if (userId == null) {
      throw StateError('You must be signed in to view follow stats.');
    }

    try {
      final data = await SupabaseService.client.rpc(
        'get_public_profile_detail',
        params: {'p_user_id': targetUserId},
      );
      final row = _firstRow(data);
      if (row != null) {
        return FollowStats(
          targetUserId: targetUserId,
          followerCount: (row['followers_count'] as num?)?.toInt() ?? 0,
          followingCount: (row['following_count'] as num?)?.toInt() ?? 0,
          isFollowedByMe: row['is_following'] as bool? ?? false,
          isMe: userId == targetUserId,
          isPrivate: row['is_private'] as bool? ?? false,
          hasPendingRequestByMe:
              row['pending_follow_request_by_me'] as bool? ?? false,
        );
      }
    } catch (_) {
      // Older databases may not expose the extended public profile RPC yet.
    }

    final followerCount = await _countRows(
      column: 'following_id',
      value: targetUserId,
    );
    final followingCount = await _countRows(
      column: 'follower_id',
      value: targetUserId,
    );
    final isMe = userId == targetUserId;
    final isFollowedByMe = isMe
        ? false
        : await _isFollowing(followerId: userId, followingId: targetUserId);

    return FollowStats(
      targetUserId: targetUserId,
      followerCount: followerCount,
      followingCount: followingCount,
      isFollowedByMe: isFollowedByMe,
      isMe: isMe,
    );
  }

  Future<FollowActionResult> followUser(String targetUserId) async {
    final userId = currentUserId;
    if (userId == null) {
      throw StateError('You must be signed in to follow members.');
    }
    if (userId == targetUserId) {
      throw StateError('You cannot follow yourself.');
    }

    await _rateLimitService.followRequest(targetUserId: targetUserId);

    final data = await SupabaseService.client.rpc(
      'follow_or_request_user',
      params: {'p_target_user_id': targetUserId},
    );
    final row = _firstRow(data);
    if (row == null) {
      return const FollowActionResult(status: 'following');
    }
    return FollowActionResult.fromJson(row);
  }

  Future<void> cancelFollowRequest(String targetUserId) async {
    final userId = currentUserId;
    if (userId == null) {
      throw StateError('You must be signed in to manage follow requests.');
    }

    await SupabaseService.client.rpc(
      'cancel_follow_request',
      params: {'p_target_user_id': targetUserId},
    );
  }

  Future<void> unfollowUser(String targetUserId) async {
    final userId = currentUserId;
    if (userId == null) {
      throw StateError('You must be signed in to unfollow members.');
    }

    await SupabaseService.client
        .from('follows')
        .delete()
        .eq('follower_id', userId)
        .eq('following_id', targetUserId);
  }

  Future<FollowActionResult?> toggleFollow({
    required String targetUserId,
    required bool currentlyFollowing,
    bool requestPending = false,
  }) async {
    if (currentlyFollowing) {
      await unfollowUser(targetUserId);
      return const FollowActionResult(status: 'not_following');
    }

    if (requestPending) {
      await cancelFollowRequest(targetUserId);
      return const FollowActionResult(status: 'cancelled');
    }

    return followUser(targetUserId);
  }
}

Map<String, dynamic>? _firstRow(Object? data) {
  if (data is List && data.isNotEmpty) {
    return Map<String, dynamic>.from(data.first as Map);
  }
  if (data is Map) return Map<String, dynamic>.from(data);
  return null;
}

Future<int> _countRows({required String column, required String value}) async {
  final data = await SupabaseService.client
      .from('follows')
      .select('id')
      .eq(column, value);

  return data.length;
}

Future<bool> _isFollowing({
  required String followerId,
  required String followingId,
}) async {
  final data = await SupabaseService.client
      .from('follows')
      .select('id')
      .eq('follower_id', followerId)
      .eq('following_id', followingId)
      .maybeSingle();

  return data != null;
}
