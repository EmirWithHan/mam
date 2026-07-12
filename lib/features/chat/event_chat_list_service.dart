import 'package:flutter/foundation.dart';
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
        .select('event_id,role,attendance_status,last_read_message_id')
        .eq('user_id', userId)
        .inFilter('attendance_status', eventChatActiveParticipantStatuses);

    final rolesByEventId = <String, String>{};
    final lastReadMessageIdByEventId = <String, String?>{};
    for (final row in participantRows) {
      final participant = Map<String, dynamic>.from(row);
      final eventId = participant['event_id'] as String?;
      if (eventId == null) continue;
      rolesByEventId[eventId] = participant['role'] as String? ?? 'participant';
      lastReadMessageIdByEventId[eventId] =
          participant['last_read_message_id'] as String?;
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
      final lastReadMsgId = lastReadMessageIdByEventId[eventId];

      bool hasUnread = false;
      if (latestMessage != null) {
        final latestMsgId = latestMessage['id'] as String;
        final latestSenderId = latestMessage['sender_id'] as String;
        if (latestSenderId != userId) {
          hasUnread = lastReadMsgId != latestMsgId;
        }
      }

      return EventChatGroup.fromEventJson(
        eventJson: row,
        role: rolesByEventId[eventId] ?? 'participant',
      ).copyWith(
        lastMessage: latestMessage?['message'] as String?,
        lastMessageAt: _dateTimeFromJson(latestMessage?['created_at']),
        unreadCount: hasUnread ? 1 : 0,
      );
    }).toList();

    final hiddenMap = <String, DateTime>{};
    try {
      final hiddenRows = await SupabaseService.client
          .from('user_hidden_conversations')
          .select('conversation_key, hidden_at')
          .eq('user_id', userId)
          .eq('conversation_type', 'event');

      if (hiddenRows != null) {
        for (final row in hiddenRows as List) {
          final rowMap = Map<String, dynamic>.from(row as Map);
          final key = rowMap['conversation_key'] as String?;
          final hiddenAtStr = rowMap['hidden_at']?.toString();
          if (key != null && hiddenAtStr != null) {
            final parsed = DateTime.tryParse(hiddenAtStr);
            if (parsed != null) {
              hiddenMap[key] = parsed.toUtc();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[EventChatList] Failed to fetch hidden conversations: $e');
    }

    final filteredGroups = groups.where((g) {
      final hiddenAt = hiddenMap[g.eventId];
      if (hiddenAt == null) return true;

      final msgTime = g.lastMessageAt;
      if (msgTime == null) {
        return false;
      }
      return msgTime.toUtc().isAfter(hiddenAt);
    }).toList();

    filteredGroups.sort((a, b) {
      final aTime = a.lastMessageAt ?? a.eventDate;
      final bTime = b.lastMessageAt ?? b.eventDate;
      return bTime.compareTo(aTime);
    });

    return filteredGroups;
  }

  Future<Map<String, Map<String, dynamic>>> _fetchLatestMessages(
    List<String> eventIds,
  ) async {
    final rows = await SupabaseService.client
        .from('event_messages')
        .select('id,sender_id,event_id,message,created_at')
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

  Future<void> deleteEventChatFromHistory(String eventId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    debugPrint(
      '[EventChatList] deleteEventChatFromHistory: '
      'currentUserIdIsNull=${userId == null}, '
      'currentUserIdLength=${userId?.length ?? 0}, '
      'conversationType=event, '
      'conversationKey=$eventId, '
      'conversationKeyIsEmpty=${eventId.isEmpty}, '
      'payloadKeys=[user_id, conversation_type, conversation_key, hidden_at]',
    );
    if (userId == null) throw StateError('Giriş yapılmalıdır.');

    try {
      await SupabaseService.client.from('user_hidden_conversations').upsert({
        'user_id': userId,
        'conversation_type': 'event',
        'conversation_key': eventId,
        'hidden_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,conversation_type,conversation_key');
      debugPrint('[EventChatList] deleteEventChatFromHistory succeeded');
    } catch (e, stack) {
      debugPrint(
        '[EventChatList] deleteEventChatFromHistory failed: '
        'errorType=${e.runtimeType}, error=$e\n$stack',
      );
      rethrow;
    }
  }
}
