import 'dart:typed_data';

import '../../services/storage_service.dart';
import '../../services/supabase_service.dart';
import 'profile_models.dart';
import 'public_profile_models.dart';
import 'public_profile_service.dart';

class ProfileService {
  const ProfileService({StorageService storageService = const StorageService()})
    : _storageService = storageService;

  final StorageService _storageService;

  Future<Profile?> getMyProfile() async {
    final userId = _currentUserId();
    final data = await SupabaseService.client
        .from('profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (data == null) return null;
    return Profile.fromJson(data);
  }

  Future<Profile> createEmptyProfileIfMissing() async {
    final userId = _currentUserId();
    final existingProfile = await getMyProfile();
    if (existingProfile != null) return existingProfile;

    final data = await SupabaseService.client
        .from('profiles')
        .insert({'user_id': userId})
        .select()
        .single();

    return Profile.fromJson(data);
  }

  Future<Profile> updateMyProfile(ProfileFormData formData) async {
    final userId = _currentUserId();
    final data = await SupabaseService.client
        .from('profiles')
        .update(formData.toUpdateJson())
        .eq('user_id', userId)
        .select()
        .single();

    return Profile.fromJson(data);
  }

  Future<Profile> updateMyProfilePrivacy({required bool isPrivate}) async {
    final userId = _currentUserId();
    final data = await SupabaseService.client
        .from('profiles')
        .update({
          'is_private': isPrivate,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', userId)
        .select()
        .single();

    return Profile.fromJson(data);
  }

  Future<void> updateGalleryPostControls({
    required String postId,
    bool? commentsHidden,
    bool? isArchived,
  }) async {
    _currentUserId();
    await SupabaseService.client.rpc(
      'update_my_gallery_post_controls',
      params: {
        'p_post_id': postId,
        'p_comments_hidden': commentsHidden,
        'p_is_archived': isArchived,
      },
    );
  }

  Future<void> deleteMyGalleryPost(String postId) async {
    _currentUserId();
    await SupabaseService.client.rpc(
      'delete_my_post',
      params: {'p_post_id': postId},
    );
  }

  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
    String? contentType,
  }) {
    return _storageService.uploadAvatar(
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );
  }

  Future<PublicProfileDetail?> fetchPublicProfileDetail(String userId) async {
    final data = await SupabaseService.client.rpc(
      'get_public_profile_detail',
      params: {'p_user_id': userId},
    );
    final row = _firstRow(data);
    if (row == null) return null;
    return PublicProfileDetail.fromJson(row);
  }

  Future<List<PublicProfileGalleryItem>> fetchPublicProfileGallery(
    String userId,
  ) async {
    final data = await SupabaseService.client.rpc(
      'get_public_profile_gallery',
      params: {'p_user_id': userId},
    );
    return _rows(
      data,
    ).map(PublicProfileGalleryItem.fromJson).toList(growable: false);
  }

  Future<List<PublicProfileEventHistoryItem>> fetchPublicProfileEventHistory(
    String userId,
  ) async {
    final data = await SupabaseService.client.rpc(
      'get_public_profile_event_history',
      params: {'p_user_id': userId},
    );
    return _rows(
      data,
    ).map(PublicProfileEventHistoryItem.fromJson).toList(growable: false);
  }

  Future<List<PublicProfileFollowListItem>> fetchFollowers(
    String userId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final data = await SupabaseService.client.rpc(
        'get_public_profile_followers',
        params: {'p_user_id': userId, 'p_limit': limit, 'p_offset': offset},
      );
      return _rows(
        data,
      ).map(PublicProfileFollowListItem.fromJson).toList(growable: false);
    } catch (_) {
      return _fetchFollowListFallback(
        userId: userId,
        idColumn: 'follower_id',
        filterColumn: 'following_id',
        limit: limit,
        offset: offset,
      );
    }
  }

  Future<List<PublicProfileFollowListItem>> fetchFollowing(
    String userId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final data = await SupabaseService.client.rpc(
        'get_public_profile_following',
        params: {'p_user_id': userId, 'p_limit': limit, 'p_offset': offset},
      );
      return _rows(
        data,
      ).map(PublicProfileFollowListItem.fromJson).toList(growable: false);
    } catch (_) {
      return _fetchFollowListFallback(
        userId: userId,
        idColumn: 'following_id',
        filterColumn: 'follower_id',
        limit: limit,
        offset: offset,
      );
    }
  }

  Future<List<PublicProfileFollowListItem>> _fetchFollowListFallback({
    required String userId,
    required String idColumn,
    required String filterColumn,
    required int limit,
    required int offset,
  }) async {
    final currentUserId = _currentUserId();
    final rows = await SupabaseService.client
        .from('follows')
        .select(idColumn)
        .eq(filterColumn, userId)
        .range(offset, offset + limit - 1);

    final targetUserIds = rows
        .whereType<Map>()
        .map((row) => row[idColumn]?.toString())
        .where((value) => value != null && value.isNotEmpty)
        .cast<String>()
        .toList();

    if (targetUserIds.isEmpty) return const [];

    final previews = await const PublicProfileService()
        .fetchPublicProfilePreviews(targetUserIds);

    final items = <PublicProfileFollowListItem>[];
    for (final targetUserId in targetUserIds) {
      final preview = previews[targetUserId];
      if (preview == null) continue;

      items.add(
        PublicProfileFollowListItem(
          userId: preview.userId,
          username: preview.usernameTag ?? preview.username,
          fullName: _previewFullName(preview),
          avatarUrl: preview.avatarUrl,
          city: preview.city,
          trustScore: preview.trustScore,
          followerCount: await _countFollowRows(
            column: 'following_id',
            value: preview.userId,
          ),
          followingCount: await _countFollowRows(
            column: 'follower_id',
            value: preview.userId,
          ),
          isFollowingByMe: currentUserId == preview.userId
              ? false
              : await _hasFollow(
                  followerId: currentUserId,
                  followingId: preview.userId,
                ),
          followsMe: currentUserId == preview.userId
              ? false
              : await _hasFollow(
                  followerId: preview.userId,
                  followingId: currentUserId,
                ),
          pendingFollowRequestByMe: currentUserId == preview.userId
              ? false
              : await _hasPendingFollowRequest(
                  requesterId: currentUserId,
                  targetUserId: preview.userId,
                ),
        ),
      );
    }

    return items;
  }

  String _currentUserId() {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to manage your profile.');
    }
    return userId;
  }

  Map<String, dynamic>? _firstRow(Object? data) {
    if (data is List && data.isNotEmpty) {
      return Map<String, dynamic>.from(data.first as Map);
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  List<Map<String, dynamic>> _rows(Object? data) {
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }
}

String? _previewFullName(PublicProfilePreview preview) {
  final first = preview.firstName?.trim();
  final last = preview.lastName?.trim();
  final parts = [
    first,
    last,
  ].where((part) => part != null && part.isNotEmpty).cast<String>().toList();
  if (parts.isEmpty) return null;
  return parts.join(' ');
}

Future<int> _countFollowRows({
  required String column,
  required String value,
}) async {
  final data = await SupabaseService.client
      .from('follows')
      .select('id')
      .eq(column, value);

  return data.length;
}

Future<bool> _hasFollow({
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

Future<bool> _hasPendingFollowRequest({
  required String requesterId,
  required String targetUserId,
}) async {
  try {
    final data = await SupabaseService.client
        .from('follow_requests')
        .select('id')
        .eq('requester_id', requesterId)
        .eq('target_user_id', targetUserId)
        .eq('status', 'pending')
        .maybeSingle();

    return data != null;
  } catch (_) {
    return false;
  }
}
