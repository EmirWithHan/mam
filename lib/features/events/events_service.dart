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

    return data
        .map(Event.fromJson)
        .where((event) => !blockedUserIds.contains(event.hostId))
        .toList();
  }

  Future<Event> fetchEventById(String eventId) async {
    final data = await SupabaseService.client
        .from('events')
        .select()
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

    await SupabaseService.client.rpc(
      'request_event_join',
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
}
