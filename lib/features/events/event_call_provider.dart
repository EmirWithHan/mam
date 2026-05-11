import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'event_call_service.dart';

class EventCallState {
  const EventCallState({
    this.loading = false,
    this.message,
    this.lastCalledUserId,
    this.activeTargetUserId,
  });

  final bool loading;
  final String? message;
  final String? lastCalledUserId;
  final String? activeTargetUserId;

  EventCallState copyWith({
    bool? loading,
    String? message,
    String? lastCalledUserId,
    String? activeTargetUserId,
    bool clearMessage = false,
    bool clearActiveTarget = false,
  }) {
    return EventCallState(
      loading: loading ?? this.loading,
      message: clearMessage ? null : message ?? this.message,
      lastCalledUserId: lastCalledUserId ?? this.lastCalledUserId,
      activeTargetUserId:
          clearActiveTarget ? null : activeTargetUserId ?? this.activeTargetUserId,
    );
  }
}

final eventCallServiceProvider = Provider<EventCallService>((ref) {
  return const EventCallService();
});

final eventCallControllerProvider =
    StateNotifierProvider<EventCallController, EventCallState>((ref) {
  return EventCallController(ref.watch(eventCallServiceProvider));
});

class EventCallController extends StateNotifier<EventCallState> {
  EventCallController(this._service) : super(const EventCallState());

  final EventCallService _service;

  Future<bool> callEventContact({
    required String eventId,
    required String targetUserId,
  }) async {
    state = state.copyWith(
      loading: true,
      activeTargetUserId: targetUserId,
      clearMessage: true,
    );

    try {
      final contact = await _service.getEventCallContact(
        eventId: eventId,
        targetUserId: targetUserId,
      );
      if (!contact.hasPhone) {
        throw StateError('This member does not have a phone number.');
      }

      await _service.callPhoneNumber(contact.phone!);
      state = state.copyWith(
        loading: false,
        lastCalledUserId: contact.userId,
        clearActiveTarget: true,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        loading: false,
        message: '$error',
        clearActiveTarget: true,
      );
      return false;
    }
  }
}
