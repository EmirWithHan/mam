import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import 'event_chat_models.dart';

const eventChatActiveParticipantStatuses = [
  'planned',
  'confirmed',
  'checked_in',
  'attended',
];

class EventChatService {
  const EventChatService();

  Future<List<EventMessage>> fetchMessages(String eventId) async {
    try {
      _logOperation('fetchMessages:start', eventId);
      final data = await SupabaseService.client
          .from('event_messages')
          .select()
          .eq('event_id', eventId)
          .order('created_at', ascending: true);

      final messages = data.map(EventMessage.fromJson).toList();
      _logOperation('fetchMessages:success', eventId, count: messages.length);
      return messages;
    } catch (error) {
      _logError('fetchMessages', error, eventId: eventId);
      rethrow;
    }
  }

  Future<EventMessage> sendMessage({
    required String eventId,
    required String message,
    String? replyToMessageId,
    Map<String, dynamic>? metadata,
  }) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to send messages.');
    }

    try {
      _logOperation('sendMessage:start', eventId, hasUser: true);
      final data = await SupabaseService.client
          .from('event_messages')
          .insert(
            EventMessage.createPayload(
              eventId: eventId,
              senderId: userId,
              message: message,
              replyToMessageId: replyToMessageId,
              metadata: metadata,
            ),
          )
          .select()
          .single();

      return EventMessage.fromJson(data);
    } catch (error) {
      _logError('sendMessage', error, eventId: eventId, hasUser: true);
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> fetchEventChatInfo(String eventId) async {
    try {
      _logOperation('fetchEventChatInfo:start', eventId);
      final data = await SupabaseService.client
          .from('events')
          .select('host_id, organizer_user_id, organizer_business_id')
          .eq('id', eventId)
          .maybeSingle();
      _logOperation('fetchEventChatInfo:success', eventId);
      return data == null ? null : Map<String, dynamic>.from(data);
    } catch (error) {
      _logError('fetchEventChatInfo', error, eventId: eventId);
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> fetchEventWriteInfo(String eventId) async {
    try {
      _logOperation('fetchEventWriteInfo:start', eventId);
      final data = await SupabaseService.client
          .from('events')
          .select('status, event_date')
          .eq('id', eventId)
          .single();
      _logOperation('fetchEventWriteInfo:success', eventId);
      return Map<String, dynamic>.from(data);
    } catch (error) {
      _logError('fetchEventWriteInfo', error, eventId: eventId);
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> fetchMyEventParticipation(
    String eventId,
    String userId,
  ) async {
    try {
      _logOperation('fetchMyEventParticipation:start', eventId, hasUser: true);
      final data = await SupabaseService.client
          .from('event_participants')
          .select('role, attendance_status')
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .maybeSingle();
      _logOperation(
        'fetchMyEventParticipation:success',
        eventId,
        count: data == null ? 0 : 1,
      );
      return data == null ? null : Map<String, dynamic>.from(data);
    } catch (error) {
      _logError(
        'fetchMyEventParticipation',
        error,
        eventId: eventId,
        hasUser: true,
      );
      rethrow;
    }
  }

  Future<bool> isBusinessMember({
    required String eventId,
    required String businessId,
    required String userId,
  }) async {
    try {
      _logOperation('isBusinessMember:start', eventId, hasUser: true);
      final memberData = await SupabaseService.client
          .from('business_members')
          .select('user_id')
          .eq('business_id', businessId)
          .eq('user_id', userId)
          .maybeSingle();
      final isMember = memberData != null;
      _logOperation(
        'isBusinessMember:success',
        eventId,
        count: isMember ? 1 : 0,
      );
      return isMember;
    } catch (error) {
      _logError('isBusinessMember', error, eventId: eventId, hasUser: true);
      rethrow;
    }
  }

  Future<void> reactToMessage({
    required String messageId,
    required String emoji,
  }) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;

    await SupabaseService.client.from('message_reactions').upsert({
      'message_id': messageId,
      'user_id': userId,
      'emoji': emoji,
    });
  }

  Future<void> removeReactionFromMessage({required String messageId}) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;

    await SupabaseService.client
        .from('message_reactions')
        .delete()
        .eq('message_id', messageId)
        .eq('user_id', userId);
  }

  Future<List<Map<String, dynamic>>> fetchReactionsForEvent(
    String eventId,
  ) async {
    try {
      _logOperation('fetchReactionsForEvent:start', eventId);
      final messagesData = await SupabaseService.client
          .from('event_messages')
          .select('id')
          .eq('event_id', eventId);
      final messageIds = (messagesData as List)
          .map((row) => row['id'].toString())
          .toList();
      if (messageIds.isEmpty) return const [];

      final data = await SupabaseService.client
          .from('message_reactions')
          .select('message_id, user_id, emoji')
          .inFilter('message_id', messageIds);
      final rows = List<Map<String, dynamic>>.from(data);
      _logOperation(
        'fetchReactionsForEvent:success',
        eventId,
        count: rows.length,
      );
      return rows;
    } catch (error) {
      _logError('fetchReactionsForEvent', error, eventId: eventId);
      return const [];
    }
  }

  Future<void> reportMessage({
    required String messageId,
    required String reason,
  }) async {
    if (SupabaseService.client.auth.currentUser == null) {
      throw StateError('You must be signed in to report messages.');
    }

    final result = await SupabaseService.client.rpc(
      'report_event_message',
      params: {'p_message_id': messageId, 'p_reason': reason},
    );
    if (result is! Map || result['report_id'] == null) {
      throw StateError('Message report could not be submitted.');
    }
  }

  Future<void> muteChat(String eventId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;

    await SupabaseService.client.from('chat_mutes').upsert({
      'event_id': eventId,
      'user_id': userId,
    });
  }

  Future<void> unmuteChat(String eventId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;

    await SupabaseService.client
        .from('chat_mutes')
        .delete()
        .eq('event_id', eventId)
        .eq('user_id', userId);
  }

  Future<bool> isChatMuted(String eventId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      final data = await SupabaseService.client
          .from('chat_mutes')
          .select('id')
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .maybeSingle();
      return data != null;
    } catch (error) {
      _logOptionalMuteFallback(error, eventId: eventId);
      return false;
    }
  }

  Future<void> markMessageAsRead({
    required String eventId,
    required String messageId,
  }) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;

    await SupabaseService.client
        .from('event_participants')
        .update({'last_read_message_id': messageId})
        .eq('event_id', eventId)
        .eq('user_id', userId);
  }

  Future<List<Map<String, dynamic>>> fetchChatReadReceipts(
    String eventId,
  ) async {
    try {
      _logOperation('fetchChatReadReceipts:start', eventId);
      final data = await SupabaseService.client
          .from('event_participants')
          .select('user_id, last_read_message_id')
          .eq('event_id', eventId)
          .not('last_read_message_id', 'is', null);
      final rows = List<Map<String, dynamic>>.from(data);
      _logOperation(
        'fetchChatReadReceipts:success',
        eventId,
        count: rows.length,
      );
      return rows;
    } catch (error) {
      _logError('fetchChatReadReceipts', error, eventId: eventId);
      return const [];
    }
  }

  void _logOperation(
    String operationName,
    String eventId, {
    bool? hasUser,
    int? count,
  }) {
    debugPrint(
      '[EventChatService] operation=$operationName eventId=$eventId '
      'hasUser=${hasUser ?? SupabaseService.client.auth.currentUser != null} '
      '${count == null ? '' : 'count=$count'}',
    );
  }

  void _logError(
    String operationName,
    Object error, {
    String? eventId,
    bool? hasUser,
  }) {
    final buffer = StringBuffer(
      '[EventChatService ERROR] operation=$operationName '
      'eventId=${eventId ?? '-'} '
      'hasUser=${hasUser ?? SupabaseService.client.auth.currentUser != null} '
      'type=${error.runtimeType}',
    );

    if (error is PostgrestException) {
      buffer.write(
        ' code=${error.code} message=${error.message} '
        'details=${error.details} hint=${error.hint}',
      );
    }

    debugPrint(buffer.toString());
  }

  void _logOptionalMuteFallback(Object error, {required String eventId}) {
    final buffer = StringBuffer(
      '[EventChatService WARNING] operation=fetchMuted eventId=$eventId '
      'fallback=notMuted type=${error.runtimeType}',
    );

    if (error is PostgrestException) {
      buffer.write(' code=${error.code ?? 'unknown'}');
    }

    debugPrint(buffer.toString());
  }

  Future<bool> isCurrentUserParticipant(String eventId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      _logOperation('isCurrentUserParticipant:noUser', eventId, hasUser: false);
      return false;
    }

    try {
      final participantData = await fetchMyEventParticipation(eventId, userId);

      if (participantData != null) {
        final role = participantData['role'] as String?;
        final status = participantData['attendance_status'] as String?;
        if (role == 'host' ||
            eventChatActiveParticipantStatuses.contains(status)) {
          return true;
        }
      }

      final eventData = await fetchEventChatInfo(eventId);

      if (eventData != null) {
        final hostId = eventData['host_id'] as String?;
        final orgUserId = eventData['organizer_user_id'] as String?;
        if (hostId == userId || orgUserId == userId) {
          return true;
        }

        final orgBusId = eventData['organizer_business_id'] as String?;
        if (orgBusId != null) {
          return await isBusinessMember(
            eventId: eventId,
            businessId: orgBusId,
            userId: userId,
          );
        }
      }
    } catch (error) {
      _logError('isCurrentUserParticipant', error, eventId: eventId);
    }
    return false;
  }

  Future<bool> canCurrentUserWriteChat(String eventId) async {
    final isParticipant = await isCurrentUserParticipant(eventId);
    if (!isParticipant) return false;

    try {
      final data = await fetchEventWriteInfo(eventId);
      if (data == null) return false;

      final status = data['status'] as String?;
      final eventDate = DateTime.tryParse(data['event_date'].toString());
      if (status != 'active' || eventDate == null) return false;

      final archiveAt = eventDate.add(const Duration(hours: 24));
      final now = DateTime.now();
      return now.isBefore(archiveAt) || now.isAtSameMomentAs(archiveAt);
    } catch (error) {
      _logError('canCurrentUserWriteChat', error, eventId: eventId);
      return false;
    }
  }

  Future<void> createPoll({
    required String eventId,
    required String question,
    required List<String> options,
  }) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not signed in.');

    final poll = await SupabaseService.client
        .from('chat_polls')
        .insert({
          'event_id': eventId,
          'creator_id': userId,
          'question': question,
        })
        .select()
        .single();

    final pollId = poll['id'] as String;

    for (final opt in options) {
      if (opt.trim().isEmpty) continue;
      await SupabaseService.client.from('chat_poll_options').insert({
        'poll_id': pollId,
        'option_text': opt.trim(),
      });
    }

    await SupabaseService.client.from('event_messages').insert({
      'event_id': eventId,
      'sender_id': userId,
      'message': '[Anket] $question',
      'metadata': {'type': 'poll', 'poll_id': pollId},
    });
  }

  Future<Map<String, dynamic>> fetchPollDetails(String pollId) async {
    final poll = await SupabaseService.client
        .from('chat_polls')
        .select('*, chat_poll_options(*), chat_poll_votes(*)')
        .eq('id', pollId)
        .single();
    return Map<String, dynamic>.from(poll);
  }

  Future<void> castVote({
    required String pollId,
    required String optionId,
  }) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;

    await SupabaseService.client
        .from('chat_poll_votes')
        .delete()
        .eq('poll_id', pollId)
        .eq('user_id', userId);

    await SupabaseService.client.from('chat_poll_votes').insert({
      'poll_id': pollId,
      'option_id': optionId,
      'user_id': userId,
    });
  }
}
