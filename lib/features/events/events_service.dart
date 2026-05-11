import '../../services/supabase_service.dart';
import 'events_models.dart';

class EventsService {
  const EventsService();

  Future<List<Event>> fetchEvents() async {
    final data = await SupabaseService.client
        .from('events')
        .select()
        .inFilter('status', ['active', 'completed'])
        .order('event_date');

    return data.map(Event.fromJson).toList();
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
}
