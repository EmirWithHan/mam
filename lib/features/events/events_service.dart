import 'package:flutter/foundation.dart';

import '../../services/supabase_service.dart';
import '../reports/blocks_service.dart';
import 'events_models.dart';

class EventsService {
  const EventsService({BlocksService blocksService = const BlocksService()})
    : _blocksService = blocksService;

  final BlocksService _blocksService;

  Future<List<Event>> fetchEvents() async {
    final data = await SupabaseService.client
        .from('events')
        .select(_eventSelect)
        .inFilter('status', ['active', 'completed'])
        .order('event_date');
    final blockedUserIds = await _blocksService.fetchMyBlockedUserIds();

    return data
        .map(Event.fromJson)
        .where((event) => !blockedUserIds.contains(event.hostId))
        .toList();
  }

  Future<Event> fetchEventById(String eventId) async {
    final data = await SupabaseService.client
        .from('events')
        .select(_eventSelect)
        .eq('id', eventId)
        .single();

    return Event.fromJson(data);
  }

  Future<Event> createEvent(CreateEventInput input) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to create an event.');
    }

    final data = await SupabaseService.client
        .from('events')
        .insert(input.toCreateJson(hostId: userId))
        .select()
        .single();

    return Event.fromJson(data);
  }

  Future<void> requestToJoinEvent(String eventId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to request to join an event.');
    }

    final event = await fetchEventById(eventId);
    if (event.isPast) {
      throw StateError('Bu etkinlik geçmişte kaldı.');
    }
    if (event.isFull) {
      throw StateError('Bu etkinlik şu anda dolu.');
    }

    await SupabaseService.client.rpc(
      'request_event_join',
      params: {'p_event_id': eventId},
    );
  }

  Future<String?> fetchMyAttendanceStatus(String eventId) async {
    final participation = await fetchMyParticipation(eventId);
    return participation?.attendanceStatus;
  }

  Future<EventParticipation?> fetchMyParticipation(String eventId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return null;

    final data = await SupabaseService.client
        .from('event_participants')
        .select('role,attendance_status')
        .eq('event_id', eventId)
        .eq('user_id', userId)
        .maybeSingle();

    if (data == null) return null;
    return EventParticipation.fromJson(data);
  }

  Future<Map<String, String>> fetchParticipantAttendanceStatuses(
    String eventId,
  ) async {
    final rows = await SupabaseService.client
        .from('event_participants')
        .select('user_id,role,attendance_status')
        .eq('event_id', eventId)
        .eq('role', 'participant');

    final statuses = <String, String>{};
    for (final row in rows) {
      final userId = row['user_id'] as String?;
      final status = row['attendance_status'] as String?;
      if (userId == null || status == null) continue;
      statuses[userId] = status;
    }

    return statuses;
  }

  Future<List<EventPublicParticipant>> fetchEventPublicParticipants(
    String eventId,
  ) async {
    final rows = await SupabaseService.client.rpc(
      'get_event_public_participants',
      params: {'p_event_id': eventId},
    );

    return (rows as List<dynamic>)
        .map(
          (row) => EventPublicParticipant.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .where(
          (participant) => EventPublicParticipantVisibility.canShow(
            role: participant.role,
            attendanceStatus: participant.attendanceStatus,
          ),
        )
        .toList(growable: false);
  }

  Future<void> leaveApprovedEvent(String eventId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to leave events.');
    }

    await SupabaseService.client.rpc(
      'leave_approved_event',
      params: {'p_event_id': eventId},
    );
    await _applyMyTrustScoreEvent(
      eventType: 'approved_event_left',
      refId: eventId,
    );
  }

  Future<void> deleteMyEvent(String eventId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to delete events.');
    }

    await SupabaseService.client.rpc(
      'delete_my_event',
      params: {'p_event_id': eventId},
    );
  }
}

const _eventSelect = '''
*,
business_accounts:organizer_business_id(
  id,
  name,
  username,
  business_tag,
  is_verified
)
''';

Future<void> _applyMyTrustScoreEvent({
  required String eventType,
  required String refId,
}) async {
  try {
    await SupabaseService.client.rpc(
      'apply_my_trust_score_event',
      params: {'p_event_type': eventType, 'p_ref_id': refId},
    );
  } catch (error) {
    debugPrint('[Events] trust score event failed: ${error.runtimeType}');
  }
}
