import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/error_messages.dart';
import 'join_requests_models.dart';
import 'join_requests_service.dart';

class JoinRequestsState {
  const JoinRequestsState({
    this.loading = false,
    this.message,
    this.myRequest,
    this.hostRequests = const [],
  });

  final bool loading;
  final String? message;
  final EventJoinRequest? myRequest;
  final List<EventJoinRequest> hostRequests;

  JoinRequestsState copyWith({
    bool? loading,
    String? message,
    EventJoinRequest? myRequest,
    List<EventJoinRequest>? hostRequests,
    bool clearMessage = false,
    bool clearMyRequest = false,
  }) {
    return JoinRequestsState(
      loading: loading ?? this.loading,
      message: clearMessage ? null : message ?? this.message,
      myRequest: clearMyRequest ? null : myRequest ?? this.myRequest,
      hostRequests: hostRequests ?? this.hostRequests,
    );
  }
}

final joinRequestsServiceProvider = Provider<JoinRequestsService>((ref) {
  return const JoinRequestsService();
});

final joinRequestControllerProvider =
    StateNotifierProvider.family<
      JoinRequestController,
      JoinRequestsState,
      String
    >((ref, eventId) {
      return JoinRequestController(
        eventId: eventId,
        service: ref.watch(joinRequestsServiceProvider),
      );
    });

class JoinRequestController extends StateNotifier<JoinRequestsState> {
  JoinRequestController({
    required this.eventId,
    required JoinRequestsService service,
  }) : _service = service,
       super(const JoinRequestsState());

  final String eventId;
  final JoinRequestsService _service;

  Future<void> loadMyRequest() async {
    state = state.copyWith(loading: true, clearMessage: true);

    try {
      final request = await _service.getMyJoinRequestForEvent(eventId);
      state = state.copyWith(
        loading: false,
        myRequest: request,
        clearMyRequest: request == null,
      );
    } catch (error) {
      state = state.copyWith(
        loading: false,
        message: friendlyErrorMessage(error),
      );
    }
  }

  Future<void> requestToJoin() async {
    state = state.copyWith(loading: true, clearMessage: true);

    try {
      final request = await _service.requestToJoinEvent(eventId);
      state = state.copyWith(loading: false, myRequest: request);
    } catch (error) {
      state = state.copyWith(
        loading: false,
        message: friendlyErrorMessage(error),
      );
    }
  }

  Future<void> cancelPendingRequest(String requestId) async {
    state = state.copyWith(loading: true, clearMessage: true);

    try {
      await _service.cancelMyJoinRequest(requestId);
      final request = await _service.getMyJoinRequestForEvent(eventId);
      state = state.copyWith(
        loading: false,
        myRequest: request,
        clearMyRequest: request == null,
      );
    } catch (error) {
      state = state.copyWith(
        loading: false,
        message: friendlyErrorMessage(error),
      );
    }
  }

  Future<void> loadHostRequests() async {
    state = state.copyWith(loading: true, clearMessage: true);

    try {
      final requests = await _service.fetchJoinRequestsForEvent(eventId);
      state = state.copyWith(loading: false, hostRequests: requests);
    } catch (error) {
      state = state.copyWith(
        loading: false,
        message: friendlyErrorMessage(error),
      );
    }
  }

  Future<void> approveRequest(String requestId) async {
    state = state.copyWith(loading: true, clearMessage: true);

    try {
      await _service.approveJoinRequest(requestId);
      final requests = await _service.fetchJoinRequestsForEvent(eventId);
      state = state.copyWith(loading: false, hostRequests: requests);
    } catch (error) {
      state = state.copyWith(
        loading: false,
        message: friendlyErrorMessage(error),
      );
    }
  }

  Future<void> rejectRequest(String requestId) async {
    state = state.copyWith(loading: true, clearMessage: true);

    try {
      await _service.rejectJoinRequest(requestId);
      final requests = await _service.fetchJoinRequestsForEvent(eventId);
      state = state.copyWith(loading: false, hostRequests: requests);
    } catch (error) {
      state = state.copyWith(
        loading: false,
        message: friendlyErrorMessage(error),
      );
    }
  }
}
