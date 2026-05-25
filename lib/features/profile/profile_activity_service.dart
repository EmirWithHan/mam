import '../../services/supabase_service.dart';
import 'profile_activity_models.dart';

class ProfileActivityService {
  const ProfileActivityService();

  Future<List<ProfileGalleryPost>> fetchMyGalleryPosts() async {
    final userId = _currentUserId();
    final data = await SupabaseService.client
        .from('posts')
        .select(
          'id,image_url,caption,event_id,comments_hidden,is_archived,created_at',
        )
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(30);

    return data.map(ProfileGalleryPost.fromJson).toList();
  }

  Future<List<ProfileActivityEvent>> fetchMyEvents() async {
    final userId = _currentUserId();
    final data = await SupabaseService.client.rpc(
      'get_public_profile_event_history',
      params: {'p_user_id': userId},
    );

    if (data is! List) return const [];

    final events = data.whereType<Map>().map((row) {
      final event = Map<String, dynamic>.from(row);
      event['id'] = event['event_id'];
      return ProfileActivityEvent.fromJson(
        event,
        role: event['role'] as String?,
        attendanceStatus: event['status'] as String?,
      );
    }).toList()..sort((a, b) => b.eventDate.compareTo(a.eventDate));

    return events;
  }

  String _currentUserId() {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to view profile activity.');
    }
    return userId;
  }
}
