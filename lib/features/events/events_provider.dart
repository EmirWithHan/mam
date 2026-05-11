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
  }) {
    return EventsState(
      status: status,
      events: events ?? this.events,
      message: message,
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

class EventsController extends StateNotifier<EventsState> {
  EventsController(this._eventsService) : super(const EventsState.initial());

  final EventsService _eventsService;

  Future<void> loadEvents() async {
    state = state.copyWith(status: EventsStatus.loading);

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
}
