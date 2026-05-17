import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'events_models.dart';
import 'events_service.dart';

enum EventsStatus {
  initial,
  loading,
  success,
  error,
}

class EventsState {
  const EventsState({
    required this.status,
    this.events = const [],
    this.message,
  });

  const EventsState.initial()
      : status = EventsStatus.initial,
        events = const [],
        message = null;

  final EventsStatus status;
  final List<Event> events;
  final String? message;

  bool get isLoading => status == EventsStatus.loading;

  EventsState copyWith({
    required EventsStatus status,
    List<Event>? events,
    String? message,
    bool clearMessage = false,
  }) {
    return EventsState(
      status: status,
      events: events ?? this.events,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

final eventsServiceProvider = Provider<EventsService>((ref) {
  return const EventsService();
});

final eventsControllerProvider =
    StateNotifierProvider<EventsController, EventsState>((ref) {
  return EventsController(ref.watch(eventsServiceProvider));
});

final eventDetailProvider = FutureProvider.family<Event, String>((ref, eventId) {
  return ref.watch(eventsServiceProvider).fetchEventById(eventId);
});

final eventAttendanceStatusProvider =
    FutureProvider.family<String?, String>((ref, eventId) {
  return ref.watch(eventsServiceProvider).fetchMyAttendanceStatus(eventId);
});

final eventMyParticipationProvider =
    FutureProvider.family<EventParticipation?, String>((ref, eventId) {
  return ref.watch(eventsServiceProvider).fetchMyParticipation(eventId);
});

final eventParticipantAttendanceStatusesProvider =
    FutureProvider.family<Map<String, String>, String>((ref, eventId) {
  return ref
      .watch(eventsServiceProvider)
      .fetchParticipantAttendanceStatuses(eventId);
});

final eventPublicParticipantsProvider =
    FutureProvider.family<List<EventPublicParticipant>, String>((ref, eventId) {
  return ref.watch(eventsServiceProvider).fetchEventPublicParticipants(eventId);
});

class EventsController extends StateNotifier<EventsState> {
  EventsController(this._eventsService) : super(const EventsState.initial());

  final EventsService _eventsService;

  Future<void> loadEvents() async {
    state = state.copyWith(status: EventsStatus.loading, clearMessage: true);

    try {
      final events = await _eventsService.fetchEvents();
      state = EventsState(status: EventsStatus.success, events: events);
    } catch (error) {
      state = EventsState(status: EventsStatus.error, message: '$error');
    }
  }

  Future<void> refreshEvents() => loadEvents();

  Future<Event?> createEvent(CreateEventInput input) async {
    state = state.copyWith(status: EventsStatus.loading);

    try {
      final event = await _eventsService.createEvent(input);
      final events = await _eventsService.fetchEvents();
      state = EventsState(status: EventsStatus.success, events: events);
      return event;
    } catch (error) {
      state = EventsState(status: EventsStatus.error, message: '$error');
      return null;
    }
  }

  Future<bool> requestToJoinEvent(String eventId) async {
    state = state.copyWith(status: state.status, clearMessage: true);

    try {
      await _eventsService.requestToJoinEvent(eventId);
      return true;
    } catch (error) {
      state = state.copyWith(status: state.status, message: '$error');
      return false;
    }
  }

  Future<bool> deleteEvent(String eventId) async {
    try {
      await _eventsService.deleteMyEvent(eventId);
      final events = state.events
          .where((event) => event.id != eventId)
          .toList(growable: false);
      state = EventsState(status: EventsStatus.success, events: events);
      await refreshEvents();
      return true;
    } catch (error) {
      state = EventsState(
        status: EventsStatus.error,
        events: state.events,
        message: '$error',
      );
      return false;
    }
  }

  Future<bool> leaveApprovedEvent(String eventId) async {
    state = state.copyWith(status: state.status, clearMessage: true);

    try {
      await _eventsService.leaveApprovedEvent(eventId);
      await refreshEvents();
      return true;
    } catch (error) {
      state = state.copyWith(status: state.status, message: '$error');
      return false;
    }
  }
}
