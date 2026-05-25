import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/error_messages.dart';
import 'event_chat_list_models.dart';
import 'event_chat_list_service.dart';

enum EventChatListStatus { initial, loading, success, error }

class EventChatListState {
  const EventChatListState({
    required this.status,
    this.groups = const [],
    this.message,
  });

  const EventChatListState.initial()
    : status = EventChatListStatus.initial,
      groups = const [],
      message = null;

  final EventChatListStatus status;
  final List<EventChatGroup> groups;
  final String? message;

  bool get isLoading => status == EventChatListStatus.loading;

  EventChatListState copyWith({
    required EventChatListStatus status,
    List<EventChatGroup>? groups,
    String? message,
  }) {
    return EventChatListState(
      status: status,
      groups: groups ?? this.groups,
      message: message,
    );
  }
}

final eventChatListServiceProvider = Provider<EventChatListService>((ref) {
  return const EventChatListService();
});

final eventChatListControllerProvider =
    StateNotifierProvider<EventChatListController, EventChatListState>((ref) {
      return EventChatListController(ref.watch(eventChatListServiceProvider));
    });

class EventChatListController extends StateNotifier<EventChatListState> {
  EventChatListController(this._service)
    : super(const EventChatListState.initial());

  final EventChatListService _service;

  Future<void> loadChatGroups() async {
    state = state.copyWith(status: EventChatListStatus.loading);

    try {
      final groups = await _service.fetchMyEventChatGroups();
      state = EventChatListState(
        status: EventChatListStatus.success,
        groups: groups,
      );
    } catch (error) {
      state = EventChatListState(
        status: EventChatListStatus.error,
        message: friendlyErrorMessage(error),
      );
    }
  }

  Future<void> refreshChatGroups() => loadChatGroups();
}
