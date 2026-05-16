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

  String _currentUserId() {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to manage your profile.');
    }
    return userId;
  }
}
