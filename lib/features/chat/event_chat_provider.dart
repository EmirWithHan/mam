import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/error_messages.dart';
import 'event_chat_models.dart';
import 'event_chat_service.dart';

class EventChatState {
  const EventChatState({
    this.loading = false,
    this.sending = false,
    this.message,
    this.messages = const [],
    this.access = const EventChatAccess.denied(),
  });

  final bool loading;
  final bool sending;
  final String? message;
  final List<EventMessage> messages;
  final EventChatAccess access;

  EventChatState copyWith({
    bool? loading,
    bool? sending,
    String? message,
    List<EventMessage>? messages,
    EventChatAccess? access,
    bool clearMessage = false,
  }) {
    return EventChatState(
      loading: loading ?? this.loading,
      sending: sending ?? this.sending,
      message: clearMessage ? null : message ?? this.message,
      messages: messages ?? this.messages,
      access: access ?? this.access,
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
      return EventChatController(
        eventId: eventId,
        service: ref.watch(eventChatServiceProvider),
      );
    });

class EventChatController extends StateNotifier<EventChatState> {
  EventChatController({
    required this.eventId,
    required EventChatService service,
  }) : _service = service,
       super(const EventChatState(loading: true));

  final String eventId;
  final EventChatService _service;

  Future<void> loadMessages() async {
    state = state.copyWith(loading: true, clearMessage: true);

    try {
      final canRead = await _service.isCurrentUserParticipant(eventId);
      if (!canRead) {
        state = state.copyWith(
          loading: false,
          messages: const [],
          access: const EventChatAccess.denied(
            reason:
                'Sadece ev sahibi ve onaylı katılımcılar sohbete erişebilir.',
          ),
        );
        return;
      }

      final canWrite = await _service.canCurrentUserWriteChat(eventId);
      final messages = await _service.fetchMessages(eventId);
      state = state.copyWith(
        loading: false,
        messages: messages,
        access: EventChatAccess(canRead: true, canWrite: canWrite),
      );
    } catch (error) {
      state = state.copyWith(
        loading: false,
        message: friendlyErrorMessage(error),
      );
    }
  }

  Future<void> refreshMessages() => loadMessages();

  Future<bool> sendMessage(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty || !state.access.canWrite) return false;

    state = state.copyWith(sending: true, clearMessage: true);

    try {
      await _service.sendMessage(eventId: eventId, message: trimmed);
      final messages = await _service.fetchMessages(eventId);
      state = state.copyWith(sending: false, messages: messages);
      return true;
    } catch (error) {
      state = state.copyWith(
        sending: false,
        message: friendlyErrorMessage(error),
      );
      return false;
    }
  }
}
