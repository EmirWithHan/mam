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
    this.mutationMessage,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.isMutating = false,
  });

  const EventsState.initial()
    : status = EventsStatus.initial,
      events = const [],
      message = null,
      mutationMessage = null,
      hasMore = true,
      isLoadingMore = false,
      isMutating = false;

  final EventsStatus status;
  final List<Event> events;
  final String? message;
  final String? mutationMessage;
  final bool hasMore;
  final bool isLoadingMore;
  final bool isMutating;

  bool get isLoading => status == EventsStatus.loading;

  EventsState copyWith({
    required EventsStatus status,
    List<Event>? events,
    String? message,
    String? mutationMessage,
    bool? hasMore,
    bool? isLoadingMore,
    bool? isMutating,
    bool clearMessage = false,
    bool clearMutationMessage = false,
  }) {
    return EventsState(
      status: status,
      events: events ?? this.events,
      message: clearMessage ? null : message ?? this.message,
      mutationMessage: clearMutationMessage
          ? null
          : mutationMessage ?? this.mutationMessage,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isMutating: isMutating ?? this.isMutating,
    );
  }
}

final eventsServiceProvider = Provider<EventsService>((ref) {
  return const EventsService();
});

final myEventsProvider = FutureProvider<List<MyEventItem>>((ref) async {
  final service = ref.watch(eventsServiceProvider);
  return service.fetchMyEvents();
});

final eventsControllerProvider =
    StateNotifierProvider<EventsController, EventsState>((ref) {
      return EventsController(ref.watch(eventsServiceProvider), ref);
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

final eventCapacityBucketCountsProvider =
    FutureProvider.family<Map<String, int>, String>((ref, eventId) {
      return ref
          .watch(eventsServiceProvider)
          .fetchCapacityBucketCounts(eventId);
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

final hostEventAnalyticsProvider =
    FutureProvider.family<List<EventParticipantAnalytics>, String>((
      ref,
      eventId,
    ) {
      return ref.watch(eventsServiceProvider).fetchHostEventAnalytics(eventId);
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

  String? get message => state.message;

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

  Future<String?> verifyAndCheckIn({
    required String participantUserId,
    required String token,
  }) async {
    state = state.copyWith(
      loadingUserIds: {...state.loadingUserIds, participantUserId},
      clearMessage: true,
    );

    try {
      final result = await _eventsService.verifyAndCheckInParticipant(
        eventId: eventId,
        participantUserId: participantUserId,
        token: token,
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
      return result;
    } catch (error) {
      state = state.copyWith(
        loadingUserIds: {
          ...state.loadingUserIds.where((id) => id != participantUserId),
        },
        message: friendlyErrorMessage(error),
      );
      return null;
    }
  }
}

class EventsController extends StateNotifier<EventsState> {
  EventsController(this._eventsService, this._ref)
    : super(const EventsState.initial());

  final EventsService _eventsService;
  final Ref _ref;

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

  Future<void> refreshEvents() {
    _refreshEventLists();
    return loadEvents(force: true);
  }

  void _refreshEventLists() {
    _ref.invalidate(myEventsProvider);
    _ref.read(featuredEventsProvider.notifier).refreshEvents();
    _ref.read(followingEventsProvider.notifier).refreshEvents();
  }

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
    if (state.isMutating) return null;
    state = state.copyWith(
      status: state.status,
      isMutating: true,
      clearMutationMessage: true,
    );

    try {
      final event = await _eventsService.createEvent(input);
      try {
        final events = await _eventsService.fetchEvents();
        state = EventsState(
          status: EventsStatus.success,
          events: events,
          hasMore: pageHasMore(events.length, SupabasePageSizes.events),
        );
      } catch (refreshError) {
        final events = appendUniqueByKey(
          [event, ...state.events],
          const <Event>[],
          (event) => event.id,
        );
        state = EventsState(
          status: EventsStatus.success,
          events: events,
          hasMore: state.hasMore,
          message: friendlyErrorMessage(refreshError),
        );
      }
      _ref.invalidate(eventDetailProvider(event.id));
      _refreshEventLists();
      return event;
    } catch (error) {
      state = state.copyWith(
        status: state.status,
        isMutating: false,
        mutationMessage: friendlyErrorMessage(error),
      );
      return null;
    }
  }

  Future<Event?> updateEvent({
    required String eventId,
    required UpdateEventInput input,
  }) async {
    if (state.isMutating) return null;
    state = state.copyWith(
      status: state.status,
      isMutating: true,
      clearMutationMessage: true,
    );

    try {
      final event = await _eventsService.updateEvent(
        eventId: eventId,
        input: input,
      );
      try {
        final events = await _eventsService.fetchEvents();
        state = EventsState(
          status: EventsStatus.success,
          events: events,
          message: 'Etkinlik gÃ¼ncellendi.',
          hasMore: pageHasMore(events.length, SupabasePageSizes.events),
        );
      } catch (refreshError) {
        final events = appendUniqueByKey(
          [event, ...state.events.where((existing) => existing.id != event.id)],
          const <Event>[],
          (event) => event.id,
        );
        state = EventsState(
          status: EventsStatus.success,
          events: events,
          message: friendlyErrorMessage(refreshError),
        );
      }
      _ref.invalidate(eventDetailProvider(eventId));
      _refreshEventLists();
      return event;
    } catch (error) {
      state = state.copyWith(
        status: state.status,
        isMutating: false,
        mutationMessage: friendlyErrorMessage(error),
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

  Future<bool> submitExcuse({
    required String eventId,
    required String excuseText,
  }) async {
    state = state.copyWith(status: state.status, clearMessage: true);

    try {
      await _eventsService.submitExcuse(
        eventId: eventId,
        excuseText: excuseText,
      );
      _ref.invalidate(eventMyParticipationProvider(eventId));
      _ref.invalidate(eventAttendanceStatusProvider(eventId));
      _ref.invalidate(eventParticipantAttendanceStatusesProvider(eventId));
      _ref.invalidate(eventPublicParticipantsProvider(eventId));
      _ref.invalidate(eventDetailProvider(eventId));
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

  Future<bool> cancelParticipation({
    required String eventId,
    String? excuseText,
  }) async {
    state = state.copyWith(status: state.status, clearMessage: true);

    try {
      await _eventsService.cancelParticipation(
        eventId: eventId,
        excuseText: excuseText,
      );
      _ref.invalidate(eventMyParticipationProvider(eventId));
      _ref.invalidate(eventAttendanceStatusProvider(eventId));
      _ref.invalidate(eventParticipantAttendanceStatusesProvider(eventId));
      _ref.invalidate(eventPublicParticipantsProvider(eventId));
      _ref.invalidate(eventDetailProvider(eventId));
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

  Future<bool> resolveParticipantExcuse({
    required String eventId,
    required String participantUserId,
    required String excuseStatus,
  }) async {
    state = state.copyWith(status: state.status, clearMessage: true);

    try {
      await _eventsService.resolveParticipantExcuse(
        eventId: eventId,
        participantUserId: participantUserId,
        excuseStatus: excuseStatus,
      );
      _ref.invalidate(businessEventCheckInParticipantsProvider(eventId));
      _ref.invalidate(eventParticipantAttendanceStatusesProvider(eventId));
      _ref.invalidate(eventPublicParticipantsProvider(eventId));
      _ref.invalidate(eventDetailProvider(eventId));
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

class FeaturedEventsController extends StateNotifier<EventsState> {
  FeaturedEventsController(this._eventsService)
    : super(const EventsState.initial()) {
    loadEvents();
  }

  final EventsService _eventsService;

  Future<void> loadEvents({bool force = false}) async {
    if (!force && state.status == EventsStatus.success) return;
    state = state.copyWith(status: EventsStatus.loading, clearMessage: true);

    try {
      final events = await _eventsService.fetchFeaturedEvents();
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
      final nextEvents = await _eventsService.fetchFeaturedEvents(
        offset: state.events.length,
      );
      state = state.copyWith(
        status: EventsStatus.success,
        events: [...state.events, ...nextEvents],
        hasMore: pageHasMore(nextEvents.length, SupabasePageSizes.events),
        isLoadingMore: false,
      );
    } catch (error) {
      state = state.copyWith(
        status: state.status,
        message: friendlyErrorMessage(error),
        isLoadingMore: false,
      );
    }
  }
}

final featuredEventsProvider =
    StateNotifierProvider<FeaturedEventsController, EventsState>((ref) {
      return FeaturedEventsController(ref.watch(eventsServiceProvider));
    });

class FollowingEventsController extends StateNotifier<EventsState> {
  FollowingEventsController(this._eventsService)
    : super(const EventsState.initial()) {
    loadEvents();
  }

  final EventsService _eventsService;

  Future<void> loadEvents({bool force = false}) async {
    if (!force && state.status == EventsStatus.success) return;
    state = state.copyWith(status: EventsStatus.loading, clearMessage: true);

    try {
      final events = await _eventsService.fetchFollowingEvents();
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
      final nextEvents = await _eventsService.fetchFollowingEvents(
        offset: state.events.length,
      );
      state = state.copyWith(
        status: EventsStatus.success,
        events: [...state.events, ...nextEvents],
        hasMore: pageHasMore(nextEvents.length, SupabasePageSizes.events),
        isLoadingMore: false,
      );
    } catch (error) {
      state = state.copyWith(
        status: state.status,
        message: friendlyErrorMessage(error),
        isLoadingMore: false,
      );
    }
  }
}

final followingEventsProvider =
    StateNotifierProvider<FollowingEventsController, EventsState>((ref) {
      return FollowingEventsController(ref.watch(eventsServiceProvider));
    });

final businessRecommendationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
      return ref
          .watch(eventsServiceProvider)
          .fetchBusinessRecommendationsData();
    });
