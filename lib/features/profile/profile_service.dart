import 'package:flutter/foundation.dart';

import '../../core/utils/user_handle.dart';
import '../../core/utils/pagination.dart';
import '../../services/storage_service.dart';
import '../../services/supabase_service.dart';
import 'profile_badges.dart';
import 'profile_models.dart';
import 'public_profile_models.dart';
import 'public_profile_service.dart';

class ProfileService {
  const ProfileService({StorageService storageService = const StorageService()})
    : _storageService = storageService;

  static final Map<String, Future<Profile>> _profileBootstrapInFlight = {};

  final StorageService _storageService;

  Future<Profile?> getMyProfile() async {
    final userId = _currentUserId();
    try {
      final data = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (data == null) {
        debugPrint('[Profile] own profile query returned no row');
        return null;
      }
      debugPrint('[Profile] own profile query returned row');
      return Profile.fromJson(data);
    } catch (error) {
      _logProfileError('own profile query failed', error);
      rethrow;
    }
  }

  Future<Profile> createEmptyProfileIfMissing() async {
    final userId = _currentUserId();
    final existingBootstrap = _profileBootstrapInFlight[userId];
    if (existingBootstrap != null) {
      debugPrint('[Profile] awaiting in-flight profile bootstrap');
      return existingBootstrap;
    }

    final bootstrap = _createEmptyProfileIfMissing(userId);
    _profileBootstrapInFlight[userId] = bootstrap;
    try {
      return await bootstrap;
    } finally {
      _profileBootstrapInFlight.remove(userId);
    }
  }

  Future<Profile> _createEmptyProfileIfMissing(String userId) async {
    final existingProfile = await getMyProfile();
    if (existingProfile != null) {
      if (UserHandle.isValidTag(existingProfile.tag)) {
        return existingProfile;
      }

      final payload = {
        'tag': _generateProfileTag(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      debugPrint('[Profile] completing profile identity/tag');
      final data = await _updateMyProfileRow(payload, userId);

      return Profile.fromJson(data);
    }

    debugPrint('[Profile] creating empty profile for authenticated user');
    final data = await _insertProfile(_newProfileJson(userId));

    return Profile.fromJson(data);
  }

  Future<Profile> updateMyProfile(ProfileFormData formData) async {
    final userId = _currentUserId();
    final usernameError = ProfileUsername.validate(formData.username);
    if (usernameError != null) {
      throw ProfileSaveException(usernameError);
    }
    final existingProfile = await getMyProfile();
    final payload = formData.toUpdateJson();
    payload['tag'] = UserHandle.isValidTag(existingProfile?.tag)
        ? existingProfile!.tag!.trim()
        : _generateProfileTag();
    final data = await _upsertMyProfileRow(payload, userId);
    final profile = Profile.fromJson(data);
    if (profile.hasEventRequiredFields) {
      await _applyMyTrustScoreEvent(
        eventType: 'profile_event_ready',
        refId: profile.userId,
      );
      return await getMyProfile() ?? profile;
    }

    return profile;
  }

  Future<Profile> updateMyUsername(String username) async {
    final userId = _currentUserId();
    final usernameError = ProfileUsername.validate(username);
    if (usernameError != null) {
      throw ProfileSaveException(usernameError);
    }

    final normalizedUsername = ProfileUsername.normalize(username);
    final existingProfile = await getMyProfile();
    if (await _usernameTakenByAnotherUser(normalizedUsername, userId)) {
      throw const ProfileSaveException('Bu kullanıcı adı zaten alınmış.');
    }

    final existingName = existingProfile?.firstName?.trim();
    final payload = <String, dynamic>{
      'username': normalizedUsername,
      'tag': UserHandle.isValidTag(existingProfile?.tag)
          ? existingProfile!.tag!.trim()
          : _generateProfileTag(),
      if (existingName == null || existingName.isEmpty)
        'first_name': normalizedUsername,
      'is_profile_completed': true,
      'updated_at': DateTime.now().toIso8601String(),
    };

    final data = await _upsertMyProfileRow(payload, userId);
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

  Future<Profile> updateMyAccountType(String accountType) async {
    final userId = _currentUserId();
    if (accountType != ProfileAccountType.user &&
        accountType != ProfileAccountType.business) {
      throw const ProfileSaveException('Hesap tipi güncellenemedi.');
    }

    final data = await SupabaseService.client.rpc(
      'switch_profile_account_type',
      params: {'p_account_type': accountType},
    );
    final row = _firstRow(data);
    if (row == null) {
      return await getMyProfile() ??
          Profile(id: userId, userId: userId, accountType: accountType);
    }
    return Profile.fromJson(row);
  }

  Future<void> requestMyAccountDeletion() async {
    _currentUserId();
    try {
      await SupabaseService.client.rpc('request_my_account_deletion');
    } catch (error) {
      _logProfileError('account deletion request failed', error);
      rethrow;
    }
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
    String userId, {
    int limit = SupabasePageSizes.gallery,
    int offset = 0,
  }) async {
    final data = await SupabaseService.client.rpc(
      'get_public_profile_gallery',
      params: {'p_user_id': userId, 'p_limit': limit, 'p_offset': offset},
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

  Future<List<ProfileBadge>> fetchProfileBadges(String userId) async {
    final data = await SupabaseService.client.rpc(
      'get_profile_badges',
      params: {'p_user_id': userId},
    );

    final badges = _rows(
      data,
    ).map(ProfileBadge.fromJson).toList(growable: false);
    return ProfileBadgeCatalog.withUpcoming(badges);
  }

  Future<List<PublicProfileFollowListItem>> fetchFollowers(
    String userId, {
    int limit = SupabasePageSizes.followList,
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
    int limit = SupabasePageSizes.followList,
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
          username: preview.username,
          tag: preview.tag,
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

  Map<String, dynamic> _newProfileJson(String userId) {
    final metadata =
        SupabaseService.client.auth.currentUser?.userMetadata ?? const {};
    final fullName = _metadataString(metadata, ['full_name', 'name']);
    final avatarUrl = _metadataString(metadata, ['avatar_url', 'picture']);

    final profileJson = <String, dynamic>{
      'user_id': userId,
      'tag': _generateProfileTag(),
      'is_private': true,
    };
    if (fullName != null) profileJson['first_name'] = fullName;
    if (avatarUrl != null) profileJson['avatar_url'] = avatarUrl;

    return profileJson;
  }

  Future<Map<String, dynamic>> _insertProfile(Map<String, dynamic> payload) {
    debugPrint('[Profile] profile insert started');
    return SupabaseService.client
        .from('profiles')
        .insert(payload)
        .select()
        .single()
        .then((data) {
          debugPrint('[Profile] profile insert success');
          return data;
        })
        .catchError((Object error) {
          _logProfileError('profile insert failed', error);
          throw error;
        });
  }

  Future<Map<String, dynamic>> _updateMyProfileRow(
    Map<String, dynamic> payload,
    String userId,
  ) {
    debugPrint('[Profile] profile update started');
    return SupabaseService.client
        .from('profiles')
        .update(payload)
        .eq('user_id', userId)
        .select()
        .single()
        .then((data) {
          debugPrint('[Profile] profile update success');
          return data;
        })
        .catchError((Object error) {
          _logProfileError('profile update failed', error);
          throw error;
        });
  }

  Future<Map<String, dynamic>> _upsertMyProfileRow(
    Map<String, dynamic> payload,
    String userId,
  ) async {
    try {
      return await _updateMyProfileRow(payload, userId);
    } catch (error) {
      if (!_isNoRowsError(error)) rethrow;
      debugPrint('[Profile] profile update found no row, inserting instead');
      return _insertProfile({'user_id': userId, ...payload});
    }
  }

  Future<bool> _usernameTakenByAnotherUser(
    String username,
    String userId,
  ) async {
    final data = await SupabaseService.client
        .from('profiles')
        .select('user_id')
        .eq('username', username)
        .maybeSingle();
    if (data == null) return false;
    return data['user_id']?.toString() != userId;
  }

  bool _isNoRowsError(Object error) {
    final normalized = error.toString().toLowerCase();
    return normalized.contains('pgrst116') ||
        normalized.contains('cannot coerce the result to a single json object');
  }

  String _generateProfileTag() {
    return UserHandle.generateTag();
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

Future<void> _applyMyTrustScoreEvent({
  required String eventType,
  String? refId,
}) async {
  try {
    await SupabaseService.client.rpc(
      'apply_my_trust_score_event',
      params: {'p_event_type': eventType, 'p_ref_id': refId},
    );
  } catch (error) {
    debugPrint('[Profile] trust score event failed: ${error.runtimeType}');
  }
}

void _logProfileError(String label, Object error) {
  final text = error.toString();
  final codeMatch = RegExp(r'code:\s*([^,\)]+)').firstMatch(text);
  final code = codeMatch?.group(1)?.trim();
  debugPrint(
    '[Profile] $label'
    '${code == null ? '' : ' code=$code'}'
    ' type=${error.runtimeType}',
  );
}

String? _previewFullName(PublicProfilePreview preview) {
  final first = preview.firstName?.trim();
  final parts = [
    first,
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

String? _metadataString(Map<String, dynamic> metadata, List<String> keys) {
  for (final key in keys) {
    final value = metadata[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}
