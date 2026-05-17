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
        .select()
        .inFilter('status', ['active', 'completed'])
        .order('event_date');
    final blockedUserIds = await _blocksService.fetchMyBlockedUserIds();

    final events = data
        .map(Event.fromJson)
        .where((event) => !blockedUserIds.contains(event.hostId))
        .toList();

    return _withClientApprovedCounts(events);
  }

  Future<Event> fetchEventById(String eventId) async {
    final data = await SupabaseService.client
        .from('events')
        .select()
        .eq('id', eventId)
        .single();

    final events = await _withClientApprovedCounts([Event.fromJson(data)]);
    return events.first;
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

  Future<void> leaveApprovedEvent(String eventId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to leave events.');
    }

    await SupabaseService.client.rpc(
      'leave_approved_event',
      params: {'p_event_id': eventId},
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

  Future<List<Event>> _withClientApprovedCounts(List<Event> events) async {
    if (events.isEmpty) return events;

    final counts = await _fetchApprovedCounts(
      events.map((event) => event.id).toList(growable: false),
    );

    return events
        .map(
          (event) => event.copyWith(
            approvedCount: counts[event.id] ?? 0,
          ),
        )
        .toList(growable: false);
  }

  Future<Map<String, int>> _fetchApprovedCounts(List<String> eventIds) async {
    if (eventIds.isEmpty) return const {};

    final rows = await SupabaseService.client
        .from('event_participants')
        .select('event_id,role,attendance_status')
        .inFilter('event_id', eventIds)
        .eq('role', 'participant')
        .inFilter('attendance_status', [
      EventParticipationStatus.planned,
      EventParticipationStatus.attended,
    ]);

    final counts = <String, int>{};
    for (final row in rows) {
      final eventId = row['event_id'] as String?;
      if (eventId == null) continue;
      counts[eventId] = (counts[eventId] ?? 0) + 1;
    }

    return counts;
  }
}
