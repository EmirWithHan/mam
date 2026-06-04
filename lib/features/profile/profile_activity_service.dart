import '../../services/supabase_service.dart';
import '../../core/utils/pagination.dart';
import 'profile_activity_models.dart';

class ProfileActivityService {
  const ProfileActivityService();

  Future<List<ProfileGalleryPost>> fetchMyGalleryPosts() async {
    final userId = _currentUserId();
    final data = await SupabaseService.client
        .from('posts')
        .select(
          'id,user_id,event_id,image_url,caption,comments_hidden,is_archived,created_at,updated_at',
        )
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(SupabasePageSizes.gallery);

    return data.map(ProfileGalleryPost.fromJson).toList();
  }

  Future<List<ProfileActivityEvent>> fetchMyEvents() async {
    final userId = _currentUserId();
    final participantRows = await SupabaseService.client
        .from('event_participants')
        .select('event_id,role,attendance_status')
        .eq('user_id', userId)
        .limit(SupabasePageSizes.events);

    final rolesByEventId = <String, String>{};
    final statusesByEventId = <String, String>{};
    for (final row in participantRows) {
      final participant = Map<String, dynamic>.from(row);
      final status = participant['attendance_status'] as String?;
      if (!_isVisibleAttendanceStatus(status)) continue;

      final eventId = participant['event_id'] as String?;
      if (eventId == null) continue;
      rolesByEventId[eventId] = participant['role'] as String? ?? 'participant';
      statusesByEventId[eventId] = status ?? 'planned';
    }

    final eventRowsById = <String, Map<String, dynamic>>{};
    final eventIds = rolesByEventId.keys.toList();
    if (eventIds.isNotEmpty) {
      final participantEventRows = await SupabaseService.client
          .from('events')
          .select(_eventSelect)
          .inFilter('id', eventIds);

      for (final row in participantEventRows) {
        final event = Map<String, dynamic>.from(row);
        final eventId = event['id'] as String?;
        if (eventId != null) eventRowsById[eventId] = event;
      }
    }

    final hostedEventRows = await SupabaseService.client
        .from('events')
        .select(_eventSelect)
        .eq('host_id', userId)
        .limit(SupabasePageSizes.events);

    for (final row in hostedEventRows) {
      final event = Map<String, dynamic>.from(row);
      final eventId = event['id'] as String?;
      if (eventId == null) continue;
      rolesByEventId[eventId] = 'host';
      statusesByEventId[eventId] = statusesByEventId[eventId] ?? 'planned';
      eventRowsById[eventId] = event;
    }

    final events = eventRowsById.entries.map((entry) {
      return ProfileActivityEvent.fromJson(
        entry.value,
        role: rolesByEventId[entry.key],
        attendanceStatus: statusesByEventId[entry.key],
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

  bool _isVisibleAttendanceStatus(String? status) {
    return status == 'planned' || status == 'attended' || status == 'pending';
  }
}

const _eventSelect =
    'id,title,sport_type,city,district,event_date,capacity_total,approved_count';
