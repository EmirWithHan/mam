import '../../services/supabase_service.dart';
import 'event_chat_service.dart';
import 'event_chat_list_models.dart';

class EventChatListService {
  const EventChatListService();

  Future<List<EventChatGroup>> fetchMyEventChatGroups() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to view event chats.');
    }

    final participantRows = await SupabaseService.client
        .from('event_participants')
        .select('event_id,role,attendance_status')
        .eq('user_id', userId)
        .inFilter('attendance_status', eventChatActiveParticipantStatuses);

    final rolesByEventId = <String, String>{};
    for (final row in participantRows) {
      final participant = Map<String, dynamic>.from(row);
      final eventId = participant['event_id'] as String?;
      if (eventId == null) continue;
      rolesByEventId[eventId] = participant['role'] as String? ?? 'participant';
    }

    final eventIds = rolesByEventId.keys.toList();

    final eventRows = <Map<String, dynamic>>[];
    if (eventIds.isNotEmpty) {
      final participantEventRows = await SupabaseService.client
          .from('events')
          .select('id,title,sport_type,city,district,event_date,status')
          .inFilter('id', eventIds);

      eventRows.addAll(
        participantEventRows.map((row) => Map<String, dynamic>.from(row)),
      );
    }

    final hostedEventRows = await SupabaseService.client
        .from('events')
        .select('id,title,sport_type,city,district,event_date,status')
        .eq('host_id', userId);

    for (final row in hostedEventRows) {
      final eventJson = Map<String, dynamic>.from(row);
      final eventId = eventJson['id'] as String?;
      if (eventId == null) continue;
      rolesByEventId[eventId] = 'host';
      if (eventRows.any((event) => event['id'] == eventId)) continue;
      eventRows.add(eventJson);
    }

    if (eventRows.isEmpty) return const [];

    final visibleEventIds = rolesByEventId.keys.toList();

    final latestMessagesByEventId = await _fetchLatestMessages(visibleEventIds);

    final groups = eventRows.map((row) {
      final eventId = row['id'] as String;
      final latestMessage = latestMessagesByEventId[eventId];
      return EventChatGroup.fromEventJson(
        eventJson: row,
        role: rolesByEventId[eventId] ?? 'participant',
      ).copyWith(
        lastMessage: latestMessage?['message'] as String?,
        lastMessageAt: _dateTimeFromJson(latestMessage?['created_at']),
      );
    }).toList();

    groups.sort((a, b) {
      final aTime = a.lastMessageAt ?? a.eventDate;
      final bTime = b.lastMessageAt ?? b.eventDate;
      return bTime.compareTo(aTime);
    });

    return groups;
  }

  Future<Map<String, Map<String, dynamic>>> _fetchLatestMessages(
    List<String> eventIds,
  ) async {
    final rows = await SupabaseService.client
        .from('event_messages')
        .select('event_id,message,created_at')
        .inFilter('event_id', eventIds)
        .order('created_at', ascending: false);

    final latestByEventId = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final message = Map<String, dynamic>.from(row);
      final eventId = message['event_id'] as String?;
      if (eventId == null || latestByEventId.containsKey(eventId)) continue;
      latestByEventId[eventId] = message;
    }

    return latestByEventId;
  }

  DateTime? _dateTimeFromJson(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
