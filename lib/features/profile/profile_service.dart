import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/utils/user_handle.dart';
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
    final user = SupabaseService.client.auth.currentUser;
    final existingProfile = await getMyProfile();
    if (existingProfile != null) {
      final shouldCompleteSocial =
          _isSocialUser(user) && !existingProfile.hasCoreIdentity;
      if (!shouldCompleteSocial && UserHandle.isValidTag(existingProfile.tag)) {
        return existingProfile;
      }

      final payload = shouldCompleteSocial
          ? await _socialProfileDefaults(user, existingProfile)
          : {
              'tag': _generateProfileTag(),
              'updated_at': DateTime.now().toIso8601String(),
            };
      debugPrint('[Profile] completing profile identity/tag');
      final data = await _updateMyProfileRow(payload, userId);

      return Profile.fromJson(data);
    }

    if (!_isSocialUser(user)) {
      debugPrint('[Profile] creating empty profile for email user');
      final data = await _insertProfile(_newProfileJson(userId));

      return Profile.fromJson(data);
    }

    debugPrint('[Profile] auto-creating social profile');
    final profileJson = await _socialProfileDefaults(user, null);
    profileJson['user_id'] = userId;
    final data = await _insertGeneratedProfile(profileJson);

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
    };
    if (fullName != null) profileJson['first_name'] = fullName;
    if (avatarUrl != null) profileJson['avatar_url'] = avatarUrl;

    return profileJson;
  }

  Future<Map<String, dynamic>> _insertGeneratedProfile(
    Map<String, dynamic> profileJson,
  ) async {
    var payload = profileJson;
    for (var attempt = 0; attempt < 4; attempt += 1) {
      try {
        debugPrint('[Profile] generated profile insert attempt=${attempt + 1}');
        return await _insertProfile(payload);
      } catch (error) {
        if (_isDuplicateProfileRowError(error)) {
          debugPrint('[Profile] profile row already exists, reloading');
          final existing = await getMyProfile();
          if (existing != null) return _profileToJson(existing);
        }
        if (!_isDuplicateUsernameError(error) || attempt == 3) rethrow;
        debugPrint('[Profile] generated username collision retry');
        final username = await _uniqueGeneratedUsername(
          '${payload['username']}_${_shortSuffix()}',
        );
        payload = {...payload, 'username': username};
      }
    }
    throw StateError('Profile could not be created.');
  }

  Future<Map<String, dynamic>> _socialProfileDefaults(
    supabase.User? user,
    Profile? existingProfile,
  ) async {
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    final fullName = _metadataString(metadata, [
      'full_name',
      'name',
      'display_name',
    ]);
    final avatarUrl = _metadataString(metadata, ['avatar_url', 'picture']);
    final currentName = existingProfile?.firstName?.trim();
    final currentUsername = existingProfile?.username?.trim();
    final username = currentUsername == null || currentUsername.isEmpty
        ? await _uniqueGeneratedUsername(_usernameSeed(user, fullName))
        : ProfileUsername.normalize(currentUsername);
    final tag = UserHandle.isValidTag(existingProfile?.tag)
        ? existingProfile!.tag!.trim()
        : _generateProfileTag();
    debugPrint('[Profile] generated username ready');
    final name = currentName == null || currentName.isEmpty
        ? (fullName ?? username)
        : currentName;

    final profileJson = <String, dynamic>{
      'username': username,
      'tag': tag,
      'first_name': name,
      'is_profile_completed': true,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (avatarUrl != null &&
        existingProfile?.avatarUrl?.trim().isEmpty != false) {
      profileJson['avatar_url'] = avatarUrl;
    }
    if (existingProfile == null) {
      profileJson['is_private'] = false;
    }
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

  String _usernameSeed(supabase.User? user, String? fullName) {
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    final preferred = _metadataString(metadata, [
      'preferred_username',
      'user_name',
      'username',
      'nickname',
    ]);
    return ProfileUsername.socialSeed(
      preferredUsername: preferred,
      email: user?.email,
      fullName: fullName,
      fallbackId: user?.id ?? _shortSuffix(),
    );
  }

  Future<String> _uniqueGeneratedUsername(String seed) async {
    final base = _fitUsername(ProfileUsername.slug(seed));
    var candidate = base;
    for (var attempt = 0; attempt < 6; attempt += 1) {
      final exists = await _usernameExists(candidate);
      if (!exists) return candidate;
      debugPrint('[Profile] generated username exists, adding suffix');
      final suffix = _shortSuffix();
      candidate = ProfileUsername.withSuffix(base, suffix);
    }
    final suffix = _shortSuffix();
    return ProfileUsername.withSuffix(base, suffix);
  }

  Future<bool> _usernameExists(String username) async {
    final data = await SupabaseService.client
        .from('profiles')
        .select('user_id')
        .eq('username', username)
        .maybeSingle();
    return data != null;
  }

  String _fitUsername(
    String value, {
    int maxLength = ProfileUsername.maxLength,
  }) {
    final fallback = value.length >= ProfileUsername.minLength
        ? value
        : 'user_${_shortSuffix()}';
    if (fallback.length <= maxLength) return fallback;
    return fallback.substring(0, maxLength);
  }

  bool _isSocialUser(supabase.User? user) {
    final appMetadata = user?.appMetadata ?? const <String, dynamic>{};
    final provider = appMetadata['provider']?.toString().toLowerCase();
    if (provider == 'google' || provider == 'facebook') return true;

    final providers = appMetadata['providers'];
    if (providers is Iterable) {
      return providers
          .map((item) => item.toString().toLowerCase())
          .any((item) => item == 'google' || item == 'facebook');
    }
    return false;
  }

  bool _isDuplicateUsernameError(Object error) {
    final normalized = error.toString().toLowerCase();
    return (normalized.contains('username') ||
            normalized.contains('profiles_username_key')) &&
        (normalized.contains('duplicate') ||
            normalized.contains('unique') ||
            normalized.contains('23505'));
  }

  bool _isDuplicateProfileRowError(Object error) {
    final normalized = error.toString().toLowerCase();
    return normalized.contains('23505') &&
        (normalized.contains('profiles_pkey') ||
            normalized.contains('profiles_user_id') ||
            normalized.contains('user_id'));
  }

  bool _isNoRowsError(Object error) {
    final normalized = error.toString().toLowerCase();
    return normalized.contains('pgrst116') ||
        normalized.contains('cannot coerce the result to a single json object');
  }

  String _shortSuffix() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
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

Map<String, dynamic> _profileToJson(Profile profile) {
  return {
    'id': profile.id,
    'user_id': profile.userId,
    'username': profile.username,
    'tag': profile.tag,
    'first_name': profile.firstName,
    'birth_date': profile.birthDate?.toIso8601String(),
    'gender': profile.gender,
    'city': profile.city,
    'district': profile.district,
    'phone': profile.phone,
    'phone_number': profile.phoneNumber,
    'phone_verified': profile.phoneVerified,
    'phone_verified_at': profile.phoneVerifiedAt?.toIso8601String(),
    'bio': profile.bio,
    'avatar_url': profile.avatarUrl,
    'trust_score': profile.trustScore,
    'is_private': profile.isPrivate,
    'is_profile_completed': profile.isProfileCompleted,
    'created_at': profile.createdAt?.toIso8601String(),
    'updated_at': profile.updatedAt?.toIso8601String(),
  };
}

void _logProfileError(String label, Object error) {
  final text = error.toString();
  final codeMatch = RegExp(r'code:\s*([^,\)]+)').firstMatch(text);
  final messageMatch = RegExp(r'message:\s*([^,\)]+)').firstMatch(text);
  final code = codeMatch?.group(1)?.trim();
  final message = messageMatch?.group(1)?.trim();
  debugPrint(
    '[Profile] $label'
    '${code == null ? '' : ' code=$code'}'
    '${message == null ? '' : ' message=$message'}',
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
