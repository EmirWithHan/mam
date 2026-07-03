import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/error_messages.dart';
import '../../services/supabase_service.dart';
import '../events/events_models.dart';
import '../events/events_provider.dart';
import '../events/events_service.dart';
import 'event_chat_list_provider.dart';
import 'event_chat_models.dart';
import 'event_chat_service.dart';

class EventChatState {
  const EventChatState({
    this.loading = false,
    this.sending = false,
    this.message,
    this.sendFailureMessage,
    this.messages = const [],
    this.access = const EventChatAccess.denied(),
    this.isMuted = false,
    this.replyToMessage,
    this.reactions = const {},
    this.readReceipts = const {},
    this.participants = const [],
  });

  final bool loading;
  final bool sending;
  final String? message;
  final String? sendFailureMessage;
  final List<EventMessage> messages;
  final EventChatAccess access;
  final bool isMuted;
  final EventMessage? replyToMessage;
  final Map<String, Map<String, List<String>>> reactions;
  final Map<String, List<String>> readReceipts;
  final List<EventPublicParticipant> participants;

  EventChatState copyWith({
    bool? loading,
    bool? sending,
    String? message,
    String? sendFailureMessage,
    List<EventMessage>? messages,
    EventChatAccess? access,
    bool? isMuted,
    EventMessage? replyToMessage,
    bool clearReplyToMessage = false,
    Map<String, Map<String, List<String>>>? reactions,
    Map<String, List<String>>? readReceipts,
    List<EventPublicParticipant>? participants,
    bool clearMessage = false,
    bool clearSendFailureMessage = false,
  }) {
    return EventChatState(
      loading: loading ?? this.loading,
      sending: sending ?? this.sending,
      message: clearMessage ? null : message ?? this.message,
      sendFailureMessage: clearSendFailureMessage
          ? null
          : sendFailureMessage ?? this.sendFailureMessage,
      messages: messages ?? this.messages,
      access: access ?? this.access,
      isMuted: isMuted ?? this.isMuted,
      replyToMessage: clearReplyToMessage
          ? null
          : replyToMessage ?? this.replyToMessage,
      reactions: reactions ?? this.reactions,
      readReceipts: readReceipts ?? this.readReceipts,
      participants: participants ?? this.participants,
    );
  }
}

final eventChatServiceProvider = Provider<EventChatService>((ref) {
  return const EventChatService();
});

final eventChatControllerProvider =
    StateNotifierProvider.family<EventChatController, EventChatState, String>((
      ref,
      eventId,
    ) {
      final controller = EventChatController(
        eventId: eventId,
        service: ref.watch(eventChatServiceProvider),
        eventsService: ref.watch(eventsServiceProvider),
        ref: ref,
      );
      ref.onDispose(controller.dispose);
      return controller;
    });

class EventChatController extends StateNotifier<EventChatState> {
  EventChatController({
    required this.eventId,
    required EventChatService service,
    required EventsService eventsService,
    required Ref ref,
  }) : _service = service,
       _eventsService = eventsService,
       _ref = ref,
       super(const EventChatState(loading: true));

  final String eventId;
  final EventChatService _service;
  final EventsService _eventsService;
  final Ref _ref;
  RealtimeChannel? _realtimeChannel;

  Future<void> loadMessages() async {
    state = state.copyWith(loading: true, clearMessage: true);

    try {
      _logLoadOperation('checkAccess:start');
      final canRead = await _service.isCurrentUserParticipant(eventId);
      if (!canRead) {
        state = state.copyWith(
          loading: false,
          messages: const [],
          access: const EventChatAccess.denied(
            reason: 'Bu sohbeti görüntüleme yetkin yok.',
          ),
          message: 'Bu sohbeti görüntüleme yetkin yok.',
        );
        return;
      }

      _logLoadOperation('checkWrite:start');
      final canWrite = await _service.canCurrentUserWriteChat(eventId);
      _logLoadOperation('fetchMessages:start');
      final messages = await _service.fetchMessages(eventId);

      _logLoadOperation('fetchMuted:start');
      final muted = await _service.isChatMuted(eventId);
      _logLoadOperation('fetchReactions:start');
      final reactionsData = await _service.fetchReactionsForEvent(eventId);
      _logLoadOperation('fetchReadReceipts:start');
      final readReceiptsData = await _service.fetchChatReadReceipts(eventId);
      _logLoadOperation('fetchParticipants:start');
      final participantsData = await _eventsService
          .fetchEventPublicParticipants(eventId);
      _logLoadOperation('parseMessageModels:start', count: messages.length);

      final Map<String, Map<String, List<String>>> reactionsMap = {};
      for (final row in reactionsData) {
        final msgId = row['message_id'].toString();
        final emoji = row['emoji'].toString();
        final uId = row['user_id'].toString();
        reactionsMap.putIfAbsent(msgId, () => {});
        reactionsMap[msgId]!.putIfAbsent(emoji, () => []);
        if (!reactionsMap[msgId]![emoji]!.contains(uId)) {
          reactionsMap[msgId]![emoji]!.add(uId);
        }
      }

      final Map<String, List<String>> readReceiptsMap = {};
      for (final row in readReceiptsData) {
        final uId = row['user_id'].toString();
        final msgId = row['last_read_message_id'].toString();
        readReceiptsMap.putIfAbsent(msgId, () => []);
        if (!readReceiptsMap[msgId]!.contains(uId)) {
          readReceiptsMap[msgId]!.add(uId);
        }
      }

      state = state.copyWith(
        loading: false,
        messages: EventMessage.chronological(messages),
        access: EventChatAccess(canRead: true, canWrite: canWrite),
        isMuted: muted,
        reactions: reactionsMap,
        readReceipts: readReceiptsMap,
        participants: participantsData,
      );
      startRealtime();

      if (messages.isNotEmpty) {
        await markRead(messages.last.id);
      }
    } catch (error) {
      _logLoadError('loadMessages', error);
      final errStr = error.toString().toLowerCase();
      String userMessage = 'Etkinlik sohbeti yüklenemedi.';
      if (errStr.contains('network') ||
          errStr.contains('socket') ||
          errStr.contains('connection')) {
        userMessage = 'Bağlantı sorunu var. Lütfen tekrar dene.';
      } else if (errStr.contains('permission') ||
          errStr.contains('policy') ||
          errStr.contains('unauthorized') ||
          errStr.contains('security')) {
        userMessage = 'Bu sohbeti görüntüleme yetkin yok.';
      }
      state = state.copyWith(loading: false, message: userMessage);
    }
  }

  Future<void> refreshMessages() => loadMessages();

  Future<bool> sendMessage(
    String message, {
    List<String>? mentionUserIds,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty || !state.access.canWrite) return false;

    state = state.copyWith(
      sending: true,
      clearMessage: true,
      clearSendFailureMessage: true,
    );

    try {
      final Map<String, dynamic> metadata = {};
      if (mentionUserIds != null && mentionUserIds.isNotEmpty) {
        metadata['mentions'] = mentionUserIds;
      }

      final sentMessage = await _service.sendMessage(
        eventId: eventId,
        message: trimmed,
        replyToMessageId: state.replyToMessage?.id,
        metadata: metadata.isNotEmpty ? metadata : null,
      );

      state = state.copyWith(
        sending: false,
        messages: _mergeMessage(state.messages, sentMessage),
        clearReplyToMessage: true,
      );

      await markRead(sentMessage.id);
      return true;
    } catch (error) {
      state = state.copyWith(
        sending: false,
        sendFailureMessage: friendlyErrorMessage(error),
      );
      return false;
    }
  }

  void setReplyToMessage(EventMessage? message) {
    state = state.copyWith(
      replyToMessage: message,
      clearReplyToMessage: message == null,
    );
  }

  Future<void> toggleMute() async {
    final newMute = !state.isMuted;
    state = state.copyWith(isMuted: newMute);
    try {
      if (newMute) {
        await _service.muteChat(eventId);
      } else {
        await _service.unmuteChat(eventId);
      }
    } catch (_) {
      state = state.copyWith(isMuted: !newMute);
    }
  }

  Future<bool> addReaction(String messageId, String emoji) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return false;

    final currentReactions = Map<String, Map<String, List<String>>>.from(
      state.reactions,
    );
    currentReactions.putIfAbsent(messageId, () => {});

    currentReactions[messageId]!.forEach((key, list) {
      list.remove(userId);
    });
    currentReactions[messageId]!.removeWhere((key, list) => list.isEmpty);

    currentReactions[messageId]!.putIfAbsent(emoji, () => []);
    if (!currentReactions[messageId]![emoji]!.contains(userId)) {
      currentReactions[messageId]![emoji]!.add(userId);
    }

    state = state.copyWith(reactions: currentReactions);

    try {
      await _service.reactToMessage(messageId: messageId, emoji: emoji);
      return true;
    } catch (_) {
      await refreshMessages();
      return false;
    }
  }

  Future<void> removeReaction(String messageId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;

    final currentReactions = Map<String, Map<String, List<String>>>.from(
      state.reactions,
    );
    if (currentReactions.containsKey(messageId)) {
      currentReactions[messageId]!.forEach((key, list) {
        list.remove(userId);
      });
      currentReactions[messageId]!.removeWhere((key, list) => list.isEmpty);
      state = state.copyWith(reactions: currentReactions);
    }

    try {
      await _service.removeReactionFromMessage(messageId: messageId);
    } catch (_) {
      refreshMessages();
    }
  }

  Future<bool> reportMessage(String messageId, String reason) async {
    try {
      await _service.reportMessage(messageId: messageId, reason: reason);
      return true;
    } catch (error) {
      debugPrint('[EventChatController] reportMessage failed: $error');
      return false;
    }
  }

  Future<void> markRead(String messageId) async {
    try {
      await _service.markMessageAsRead(eventId: eventId, messageId: messageId);
      unawaited(_refreshChatList());
    } catch (_) {}
  }

  void startRealtime() {
    if (_realtimeChannel != null || !state.access.canRead) return;
    try {
      _realtimeChannel = SupabaseService.client
          .channel('event_chat_messages:$eventId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'event_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'event_id',
              value: eventId,
            ),
            callback: (payload) {
              final newRow = payload.newRecord;
              if (newRow.isEmpty) return;
              final newMessage = EventMessage.fromJson(newRow);
              final alreadyExists = state.messages.any(
                (message) => message.id == newMessage.id,
              );
              if (alreadyExists) return;

              state = state.copyWith(
                messages: _mergeMessage(state.messages, newMessage),
              );
              unawaited(markRead(newMessage.id));
            },
          )
          .subscribe();
    } catch (error) {
      debugPrint('[EventChatController] realtime failed: $error');
    }
  }

  void stopRealtime() {
    final channel = _realtimeChannel;
    _realtimeChannel = null;
    if (channel != null) {
      unawaited(SupabaseService.client.removeChannel(channel));
    }
  }

  List<EventMessage> _mergeMessage(
    List<EventMessage> current,
    EventMessage message,
  ) {
    final byId = {for (final item in current) item.id: item};
    byId[message.id] = message;
    return EventMessage.chronological(byId.values.toList());
  }

  Future<void> _refreshChatList() async {
    await _ref
        .read(eventChatListControllerProvider.notifier)
        .refreshChatGroups();
  }

  Future<void> createPoll({
    required String question,
    required List<String> options,
  }) async {
    state = state.copyWith(loading: true, clearMessage: true);
    try {
      await _service.createPoll(
        eventId: eventId,
        question: question,
        options: options,
      );
      await loadMessages();
      unawaited(_refreshChatList());
    } catch (error) {
      state = state.copyWith(
        loading: false,
        message: friendlyErrorMessage(error),
      );
    }
  }

  Future<void> castVote({
    required String pollId,
    required String optionId,
  }) async {
    try {
      await _service.castVote(pollId: pollId, optionId: optionId);
      await loadMessages();
    } catch (error) {
      state = state.copyWith(message: friendlyErrorMessage(error));
    }
  }

  void _logLoadOperation(String operationName, {int? count}) {
    debugPrint(
      '[EventChatController] operation=$operationName eventId=$eventId '
      '${count == null ? '' : 'count=$count'}',
    );
  }

  void _logLoadError(String operationName, Object error) {
    final buffer = StringBuffer(
      '[EventChatController ERROR] operation=$operationName '
      'eventId=$eventId type=${error.runtimeType}',
    );

    if (error is PostgrestException) {
      buffer.write(
        ' code=${error.code} message=${error.message} '
        'details=${error.details} hint=${error.hint}',
      );
    }

    debugPrint(buffer.toString());
  }

  @override
  void dispose() {
    stopRealtime();
    super.dispose();
  }
}
