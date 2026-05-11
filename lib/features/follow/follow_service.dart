import '../../services/supabase_service.dart';
import 'follow_models.dart';

class FollowService {
  const FollowService();

  String? get currentUserId => SupabaseService.client.auth.currentUser?.id;

  Future<FollowStats> fetchFollowStats(String targetUserId) async {
    final userId = currentUserId;
    if (userId == null) {
      throw StateError('You must be signed in to view follow stats.');
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

  Future<void> followUser(String targetUserId) async {
    final userId = currentUserId;
    if (userId == null) {
      throw StateError('You must be signed in to follow members.');
    }
    if (userId == targetUserId) {
      throw StateError('You cannot follow yourself.');
    }

    final alreadyFollowing = await _isFollowing(
      followerId: userId,
      followingId: targetUserId,
    );
    if (alreadyFollowing) return;

    await SupabaseService.client.from('follows').insert({
      'follower_id': userId,
      'following_id': targetUserId,
    });
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

  Future<void> toggleFollow({
    required String targetUserId,
    required bool currentlyFollowing,
  }) async {
    if (currentlyFollowing) {
      await unfollowUser(targetUserId);
      return;
    }

    await followUser(targetUserId);
  }
}

Future<int> _countRows({
  required String column,
  required String value,
}) async {
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
