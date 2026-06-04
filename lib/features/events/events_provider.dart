import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/error_messages.dart';
import '../../core/utils/pagination.dart';
import 'events_models.dart';
import 'events_service.dart';

enum EventsStatus { initial, loading, success, error }

class EventsState {
  const EventsState({
    required this.status,
    this.events = const [],
    this.message,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  const EventsState.initial()
    : status = EventsStatus.initial,
      events = const [],
      message = null,
      hasMore = true,
      isLoadingMore = false;

  final EventsStatus status;
  final List<Event> events;
  final String? message;
  final bool hasMore;
  final bool isLoadingMore;

  bool get isLoading => status == EventsStatus.loading;

  EventsState copyWith({
    required EventsStatus status,
    List<Event>? events,
    String? message,
    bool? hasMore,
    bool? isLoadingMore,
    bool clearMessage = false,
  }) {
    return EventsState(
      status: status,
      events: events ?? this.events,
      message: clearMessage ? null : message ?? this.message,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
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

final eventDetailProvider = FutureProvider.family<Event, String>((
  ref,
  eventId,
) {
  return ref.watch(eventsServiceProvider).fetchEventById(eventId);
});

final eventAttendanceStatusProvider = FutureProvider.family<String?, String>((
  ref,
  eventId,
) {
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
      return ref
          .watch(eventsServiceProvider)
          .fetchEventPublicParticipants(eventId);
    });

final businessEventCheckInParticipantsProvider =
    FutureProvider.family<List<BusinessEventCheckInParticipant>, String>((
      ref,
      eventId,
    ) {
      return ref
          .watch(eventsServiceProvider)
          .fetchBusinessEventCheckInParticipants(eventId);
    });

final businessEventCheckInControllerProvider =
    StateNotifierProvider.family<
      BusinessEventCheckInController,
      BusinessEventCheckInState,
      String
    >((ref, eventId) {
      return BusinessEventCheckInController(
        eventId: eventId,
        eventsService: ref.watch(eventsServiceProvider),
        ref: ref,
      );
    });

class BusinessEventCheckInState {
  const BusinessEventCheckInState({
    this.loadingUserIds = const {},
    this.message,
  });

  final Set<String> loadingUserIds;
  final String? message;

  bool isLoading(String userId) => loadingUserIds.contains(userId);

  BusinessEventCheckInState copyWith({
    Set<String>? loadingUserIds,
    String? message,
    bool clearMessage = false,
  }) {
    return BusinessEventCheckInState(
      loadingUserIds: loadingUserIds ?? this.loadingUserIds,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

class BusinessEventCheckInController
    extends StateNotifier<BusinessEventCheckInState> {
  BusinessEventCheckInController({
    required this.eventId,
    required EventsService eventsService,
    required Ref ref,
  }) : _eventsService = eventsService,
       _ref = ref,
       super(const BusinessEventCheckInState());

  final String eventId;
  final EventsService _eventsService;
  final Ref _ref;

  Future<bool> markAttendance({
    required String participantUserId,
    required String attendanceStatus,
  }) async {
    state = state.copyWith(
      loadingUserIds: {...state.loadingUserIds, participantUserId},
      clearMessage: true,
    );

    try {
      await _eventsService.markBusinessEventAttendance(
        eventId: eventId,
        participantUserId: participantUserId,
        attendanceStatus: attendanceStatus,
      );
      _ref.invalidate(businessEventCheckInParticipantsProvider(eventId));
      _ref.invalidate(eventParticipantAttendanceStatusesProvider(eventId));
      _ref.invalidate(eventPublicParticipantsProvider(eventId));
      _ref.invalidate(eventMyParticipationProvider(eventId));
      state = state.copyWith(
        loadingUserIds: {
          ...state.loadingUserIds.where((id) => id != participantUserId),
        },
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        loadingUserIds: {
          ...state.loadingUserIds.where((id) => id != participantUserId),
        },
        message: friendlyErrorMessage(error),
      );
      return false;
    }
  }
}

class EventsController extends StateNotifier<EventsState> {
  EventsController(this._eventsService) : super(const EventsState.initial());

  final EventsService _eventsService;

  Future<void> loadEvents({bool force = false}) async {
    if (!force && state.status == EventsStatus.success) return;
    state = state.copyWith(status: EventsStatus.loading, clearMessage: true);

    try {
      final events = await _eventsService.fetchEvents();
      state = EventsState(
        status: EventsStatus.success,
        events: events,
        hasMore: pageHasMore(events.length, SupabasePageSizes.events),
      );
    } catch (error) {
      state = EventsState(
        status: EventsStatus.error,
        message: friendlyErrorMessage(error),
      );
    }
  }

  Future<void> refreshEvents() => loadEvents(force: true);

  Future<void> loadMoreEvents() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(
      status: state.status,
      isLoadingMore: true,
      clearMessage: true,
    );

    try {
      final nextEvents = await _eventsService.fetchEvents(
        offset: state.events.length,
      );
      state = state.copyWith(
        status: EventsStatus.success,
        events: appendUniqueByKey(
          state.events,
          nextEvents,
          (event) => event.id,
        ),
        hasMore: pageHasMore(nextEvents.length, SupabasePageSizes.events),
        isLoadingMore: false,
      );
    } catch (error) {
      state = state.copyWith(
        status: state.status,
        isLoadingMore: false,
        message: friendlyErrorMessage(error),
      );
    }
  }

  Future<Event?> createEvent(CreateEventInput input) async {
    state = state.copyWith(status: EventsStatus.loading);

    try {
      final event = await _eventsService.createEvent(input);
      final events = await _eventsService.fetchEvents();
      state = EventsState(
        status: EventsStatus.success,
        events: events,
        hasMore: pageHasMore(events.length, SupabasePageSizes.events),
      );
      return event;
    } catch (error) {
      state = EventsState(
        status: EventsStatus.error,
        message: friendlyErrorMessage(error),
      );
      return null;
    }
  }

  Future<bool> requestToJoinEvent(String eventId) async {
    state = state.copyWith(status: state.status, clearMessage: true);

    try {
      await _eventsService.requestToJoinEvent(eventId);
      return true;
    } catch (error) {
      state = state.copyWith(
        status: state.status,
        message: friendlyErrorMessage(error),
      );
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
        message: friendlyErrorMessage(error),
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
      state = state.copyWith(
        status: state.status,
        message: friendlyErrorMessage(error),
      );
      return false;
    }
  }

  Future<bool> confirmBusinessParticipation(String eventId) async {
    state = state.copyWith(status: state.status, clearMessage: true);

    try {
      await _eventsService.confirmMyBusinessParticipation(eventId);
      await refreshEvents();
      return true;
    } catch (error) {
      state = state.copyWith(
        status: state.status,
        message: friendlyErrorMessage(error),
      );
      return false;
    }
  }
}
