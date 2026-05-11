import '../../services/supabase_service.dart';
import 'event_chat_models.dart';

class EventChatService {
  const EventChatService();

  Future<List<EventMessage>> fetchMessages(String eventId) async {
    final data = await SupabaseService.client
        .from('event_messages')
        .select()
        .eq('event_id', eventId)
        .order('created_at');

    return data.map(EventMessage.fromJson).toList();
  }

  Future<EventMessage> sendMessage({
    required String eventId,
    required String message,
  }) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to send messages.');
    }

    final data = await SupabaseService.client
        .from('event_messages')
        .insert(
          EventMessage.createPayload(
            eventId: eventId,
            senderId: userId,
            message: message,
          ),
        )
        .select()
        .single();

    return EventMessage.fromJson(data);
  }

  Future<bool> isCurrentUserParticipant(String eventId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return false;

    final data = await SupabaseService.client
        .from('event_participants')
        .select('id')
        .eq('event_id', eventId)
        .eq('user_id', userId)
        .maybeSingle();

    return data != null;
  }

  Future<bool> canCurrentUserWriteChat(String eventId) async {
    final isParticipant = await isCurrentUserParticipant(eventId);
    if (!isParticipant) return false;

    final data = await SupabaseService.client
        .from('events')
        .select('status,event_date')
        .eq('id', eventId)
        .single();

    final status = data['status'] as String?;
    final eventDate = DateTime.tryParse(data['event_date'].toString());
    if (status != 'active' || eventDate == null) return false;

    final archiveAt = eventDate.add(const Duration(hours: 24));
    final now = DateTime.now();
    return now.isBefore(archiveAt) || now.isAtSameMomentAs(archiveAt);
  }
}
