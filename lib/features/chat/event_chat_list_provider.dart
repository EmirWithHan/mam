import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/error_messages.dart';
import '../../services/supabase_service.dart';
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
      final controller = EventChatListController(
        ref.watch(eventChatListServiceProvider),
      );
      ref.onDispose(controller.dispose);
      return controller;
    });

class EventChatListController extends StateNotifier<EventChatListState> {
  EventChatListController(this._service)
    : super(const EventChatListState.initial());

  final EventChatListService _service;
  RealtimeChannel? _realtimeChannel;
  Timer? _refreshDebounce;

  Future<void> loadChatGroups() async {
    state = state.copyWith(status: EventChatListStatus.loading);

    try {
      final groups = await _service.fetchMyEventChatGroups();
      state = EventChatListState(
        status: EventChatListStatus.success,
        groups: groups,
      );
      startRealtime();
    } catch (error) {
      state = EventChatListState(
        status: EventChatListStatus.error,
        message: friendlyErrorMessage(error),
      );
    }
  }

  Future<void> refreshChatGroups() => loadChatGroups();

  Future<bool> deleteEventChatFromHistory(String eventId) async {
    try {
      await _service.deleteEventChatFromHistory(eventId);
      final list = state.groups.where((g) => g.eventId != eventId).toList();
      state = state.copyWith(status: state.status, groups: list);
      return true;
    } catch (error) {
      debugPrint(
        '[EventChatList] Error deleting event chat from history: $error',
      );
      return false;
    }
  }

  void startRealtime() {
    if (_realtimeChannel != null) return;
    final userId = SupabaseService.client.auth.currentUser?.id;
    try {
      var channel = SupabaseService.client.channel('event_chat_list_updates');

      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'event_messages',
        callback: (_) => _scheduleRefresh(),
      );

      if (userId != null && userId.isNotEmpty) {
        channel = channel.onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'event_participants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => _scheduleRefresh(),
        );
      }

      _realtimeChannel = channel.subscribe();
    } catch (error) {
      debugPrint('[EventChatList] Realtime failed: $error');
    }
  }

  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(refreshChatGroups());
    });
  }

  void stopRealtime() {
    _refreshDebounce?.cancel();
    _refreshDebounce = null;
    final channel = _realtimeChannel;
    _realtimeChannel = null;
    if (channel != null) {
      unawaited(SupabaseService.client.removeChannel(channel));
    }
  }

  @override
  void dispose() {
    stopRealtime();
    super.dispose();
  }
}
