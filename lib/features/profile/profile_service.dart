import '../../services/supabase_service.dart';
import 'profile_models.dart';

class ProfileService {
  const ProfileService();

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

  String _currentUserId() {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to manage your profile.');
    }
    return userId;
  }
}
