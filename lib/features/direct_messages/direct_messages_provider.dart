import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/error_messages.dart';
import '../../services/supabase_service.dart';
import 'direct_messages_models.dart';
import 'direct_messages_service.dart';

// Service provider
final directMessagingServiceProvider = Provider<DirectMessagingService>((ref) {
  return const DirectMessagingService();
});

// Inbox state
class DirectInboxState {
  const DirectInboxState({
    this.loading = false,
    this.conversations = const [],
    this.message,
    this.isUnavailable = false,
  });

  final bool loading;
  final List<DirectConversation> conversations;
  final String? message;
  final bool isUnavailable;

  DirectInboxState copyWith({
    bool? loading,
    List<DirectConversation>? conversations,
    String? message,
    bool? isUnavailable,
    bool clearMessage = false,
  }) {
    return DirectInboxState(
      loading: loading ?? this.loading,
      conversations: conversations ?? this.conversations,
      message: clearMessage ? null : message ?? this.message,
      isUnavailable: isUnavailable ?? this.isUnavailable,
    );
  }
}

// Inbox controller
final directInboxProvider =
    StateNotifierProvider<DirectInboxController, DirectInboxState>((ref) {
      final controller = DirectInboxController(
        service: ref.watch(directMessagingServiceProvider),
      );
      ref.onDispose(controller.dispose);
      return controller;
    });

class DirectInboxController extends StateNotifier<DirectInboxState> {
  DirectInboxController({required DirectMessagingService service})
    : _service = service,
      super(const DirectInboxState(loading: true));

  final DirectMessagingService _service;
  RealtimeChannel? _realtimeChannel;
  Timer? _refreshDebounce;

  Future<void> loadInbox() async {
    state = state.copyWith(loading: true, clearMessage: true);
    try {
      final list = await _service.fetchConversations();
      state = state.copyWith(
        loading: false,
        conversations: list,
        isUnavailable: false,
      );
      startRealtime();
    } catch (error) {
      final isUnav = error is DirectMessagingUnavailableException;
      state = state.copyWith(
        loading: false,
        message: friendlyErrorMessage(error),
        isUnavailable: isUnav,
      );
    }
  }

  Future<void> refresh() => loadInbox();

  void startRealtime() {
    if (_realtimeChannel != null) return;
    try {
      _realtimeChannel = SupabaseService.client
          .channel('direct_inbox_messages')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'direct_messages',
            callback: (_) => _scheduleRefresh(),
          )
          .subscribe();
    } catch (error) {
      debugPrint('[DirectMessaging] Inbox realtime failed: $error');
    }
  }

  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(refresh());
    });
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    final channel = _realtimeChannel;
    _realtimeChannel = null;
    if (channel != null) {
      unawaited(SupabaseService.client.removeChannel(channel));
    }
    super.dispose();
  }
}

// Active chat state
// Active chat state
class DirectChatState {
  const DirectChatState({
    this.loading = false,
    this.sending = false,
    this.messages = const [],
    this.message,
    this.sendFailureMessage,
    this.isUnavailable = false,
    this.replyToMessage,
    this.reactions = const {},
  });

  final bool loading;
  final bool sending;
  final List<DirectMessage> messages;
  final String? message;
  final String? sendFailureMessage;
  final bool isUnavailable;
  final DirectMessage? replyToMessage;
  final Map<String, Map<String, List<String>>>
  reactions; // messageId -> emoji -> userIds

  DirectChatState copyWith({
    bool? loading,
    bool? sending,
    List<DirectMessage>? messages,
    String? message,
    String? sendFailureMessage,
    bool? isUnavailable,
    bool clearMessage = false,
    bool clearSendFailureMessage = false,
    DirectMessage? replyToMessage,
    bool clearReplyToMessage = false,
    Map<String, Map<String, List<String>>>? reactions,
  }) {
    return DirectChatState(
      loading: loading ?? this.loading,
      sending: sending ?? this.sending,
      messages: messages ?? this.messages,
      message: clearMessage ? null : message ?? this.message,
      sendFailureMessage: clearSendFailureMessage
          ? null
          : sendFailureMessage ?? this.sendFailureMessage,
      isUnavailable: isUnavailable ?? this.isUnavailable,
      replyToMessage: clearReplyToMessage
          ? null
          : replyToMessage ?? this.replyToMessage,
      reactions: reactions ?? this.reactions,
    );
  }
}

// Active chat controller (family by conversationId)
final directChatControllerProvider =
    StateNotifierProvider.family<DirectChatController, DirectChatState, String>(
      (ref, conversationId) {
        final controller = DirectChatController(
          conversationId: conversationId,
          service: ref.watch(directMessagingServiceProvider),
          ref: ref,
        );
        ref.onDispose(controller.dispose);
        return controller;
      },
    );

class DirectChatController extends StateNotifier<DirectChatState> {
  DirectChatController({
    required this.conversationId,
    required DirectMessagingService service,
    required Ref ref,
  }) : _service = service,
       _ref = ref,
       super(const DirectChatState(loading: true));

  final String conversationId;
  final DirectMessagingService _service;
  final Ref _ref;
  RealtimeChannel? _realtimeChannel;

  Future<void> loadMessages() async {
    state = state.copyWith(loading: true, clearMessage: true);
    try {
      final list = await _service.fetchMessages(conversationId);
      final reactionsData = await _service.fetchReactionsForConversation(
        conversationId,
      );

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

      state = state.copyWith(
        loading: false,
        messages: list,
        reactions: reactionsMap,
        isUnavailable: false,
      );

      // Start listening to realtime messages
      startRealtime();

      // Mark the last message read when opened
      if (list.isNotEmpty) {
        await markRead(list.last.id);
      }
    } catch (error) {
      final isUnav = error is DirectMessagingUnavailableException;
      state = state.copyWith(
        loading: false,
        message: friendlyErrorMessage(error),
        isUnavailable: isUnav,
      );
    }
  }

  void startRealtime() {
    if (_realtimeChannel != null) return;
    try {
      _realtimeChannel = SupabaseService.client
          .channel('direct_messages:$conversationId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'direct_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'conversation_id',
              value: conversationId,
            ),
            callback: (payload) {
              final newRow = payload.newRecord;
              if (newRow.isEmpty) return;
              final newMessage = DirectMessage.fromJson(newRow);

              // Avoid adding duplicates (e.g. sent locally via RPC first)
              final alreadyExists = state.messages.any(
                (m) => m.id == newMessage.id,
              );
              if (!alreadyExists) {
                state = state.copyWith(
                  messages: _mergeMessage(state.messages, newMessage),
                );

                // Mark as read
                unawaited(markRead(newMessage.id));
              }
            },
          )
          .subscribe();
    } catch (error) {
      debugPrint('[DirectMessaging] Realtime subscription failed: $error');
    }
  }

  void stopRealtime() {
    final channel = _realtimeChannel;
    _realtimeChannel = null;
    if (channel != null) {
      unawaited(SupabaseService.client.removeChannel(channel));
    }
  }

  Future<bool> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    state = state.copyWith(
      sending: true,
      clearMessage: true,
      clearSendFailureMessage: true,
    );
    try {
      final msg = await _service.sendMessage(
        conversationId: conversationId,
        body: trimmed,
        replyToMessageId: state.replyToMessage?.id,
      );

      // Append message locally if not already appended
      final alreadyExists = state.messages.any((m) => m.id == msg.id);
      final List<DirectMessage> updated = alreadyExists
          ? state.messages
          : _mergeMessage(state.messages, msg);

      state = state.copyWith(
        sending: false,
        messages: updated,
        clearReplyToMessage: true,
      );
      unawaited(markRead(msg.id));
      return true;
    } catch (error) {
      state = state.copyWith(
        sending: false,
        sendFailureMessage: friendlyErrorMessage(error),
      );
      return false;
    }
  }

  void setReplyToMessage(DirectMessage? message) {
    state = state.copyWith(
      replyToMessage: message,
      clearReplyToMessage: message == null,
    );
  }

  Future<bool> addReaction(String messageId, String emoji) async {
    final userId = _service.currentUserId;
    if (userId == null) return false;
    debugPrint(
      '[DirectMessaging] Direct message reactions are not schema-enabled yet: '
      'messageId=$messageId emoji=$emoji',
    );
    return false;
  }

  Future<void> removeReaction(String messageId) async {
    final userId = _service.currentUserId;
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
      loadMessages();
    }
  }

  Future<bool> reportMessage(String messageId, String reason) async {
    final userId = _service.currentUserId;
    if (userId == null) return false;
    debugPrint(
      '[DirectMessaging] Direct message reports are not schema-enabled yet: '
      'messageId=$messageId reason=$reason',
    );
    return false;
  }

  Future<void> markRead(String messageId) async {
    try {
      await _service.markRead(
        conversationId: conversationId,
        messageId: messageId,
      );
      unawaited(_refreshInbox());
    } catch (_) {}
  }

  List<DirectMessage> _mergeMessage(
    List<DirectMessage> current,
    DirectMessage message,
  ) {
    final byId = {for (final item in current) item.id: item};
    byId[message.id] = message;
    final merged = byId.values.toList();
    merged.sort((a, b) {
      final createdAtOrder = a.createdAt.compareTo(b.createdAt);
      if (createdAtOrder != 0) return createdAtOrder;
      return a.id.compareTo(b.id);
    });
    return merged;
  }

  Future<void> _refreshInbox() async {
    await _ref.read(directInboxProvider.notifier).refresh();
  }

  @override
  void dispose() {
    stopRealtime();
    super.dispose();
  }
}
