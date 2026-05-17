import 'dart:typed_data';

import '../../services/storage_service.dart';
import '../../services/supabase_service.dart';
import 'profile_models.dart';

class ProfileService {
  const ProfileService({
    StorageService storageService = const StorageService(),
  }) : _storageService = storageService;

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
    return _rows(data)
        .map(PublicProfileGalleryItem.fromJson)
        .toList(growable: false);
  }

  Future<List<PublicProfileEventHistoryItem>> fetchPublicProfileEventHistory(
    String userId,
  ) async {
    final data = await SupabaseService.client.rpc(
      'get_public_profile_event_history',
      params: {'p_user_id': userId},
    );
    return _rows(data)
        .map(PublicProfileEventHistoryItem.fromJson)
        .toList(growable: false);
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
