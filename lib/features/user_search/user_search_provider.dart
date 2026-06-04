import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'user_search_models.dart';
import 'user_search_service.dart';

enum UserSearchStatus { idle, loading, success, error }

class UserSearchState {
  const UserSearchState({
    this.status = UserSearchStatus.idle,
    this.query = '',
    this.results = const [],
    this.message,
    this.loadingUserIds = const {},
  });

  final UserSearchStatus status;
  final String query;
  final List<UserSearchResult> results;
  final String? message;
  final Set<String> loadingUserIds;

  bool get isLoading => status == UserSearchStatus.loading;
  bool get canShowEmpty =>
      status == UserSearchStatus.success &&
      UserSearchRules.canSearch(query) &&
      results.isEmpty;

  bool isUserLoading(String userId) => loadingUserIds.contains(userId);

  UserSearchState copyWith({
    UserSearchStatus? status,
    String? query,
    List<UserSearchResult>? results,
    String? message,
    Set<String>? loadingUserIds,
    bool clearMessage = false,
  }) {
    return UserSearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      results: results ?? this.results,
      message: clearMessage ? null : message ?? this.message,
      loadingUserIds: loadingUserIds ?? this.loadingUserIds,
    );
  }
}

final userSearchServiceProvider = Provider<UserSearchService>((ref) {
  return const UserSearchService();
});

final userSearchControllerProvider =
    StateNotifierProvider<UserSearchController, UserSearchState>((ref) {
      return UserSearchController(ref.watch(userSearchServiceProvider));
    });

class UserSearchController extends StateNotifier<UserSearchState> {
  UserSearchController(this._service) : super(const UserSearchState());

  final UserSearchService _service;

  Future<void> search(String query) async {
    final normalized = UserSearchRules.normalizeQuery(query);
    if (!UserSearchRules.canSearch(normalized)) {
      state = UserSearchState(query: normalized);
      return;
    }

    state = state.copyWith(
      status: UserSearchStatus.loading,
      query: normalized,
      clearMessage: true,
    );

    try {
      final results = await _service.searchProfiles(normalized);
      if (state.query != normalized) return;
      state = UserSearchState(
        status: UserSearchStatus.success,
        query: normalized,
        results: results,
      );
    } catch (_) {
      if (state.query != normalized) return;
      state = UserSearchState(
        status: UserSearchStatus.error,
        query: normalized,
        message: 'Kullanıcılar yüklenemedi.',
      );
    }
  }

  Future<bool> follow(UserSearchResult result) async {
    if (!result.canFollow || state.isUserLoading(result.userId)) return false;

    state = state.copyWith(
      loadingUserIds: {...state.loadingUserIds, result.userId},
      clearMessage: true,
    );

    try {
      final action = await _service.followUser(result.userId);
      final nextFollowState = action.isRequested
          ? UserSearchFollowState.pending
          : UserSearchFollowState.following;
      state = state.copyWith(
        results: state.results
            .map(
              (item) => item.userId == result.userId
                  ? item.copyWith(followState: nextFollowState)
                  : item,
            )
            .toList(growable: false),
        loadingUserIds: _withoutLoading(result.userId),
      );
      return true;
    } catch (_) {
      state = state.copyWith(
        loadingUserIds: _withoutLoading(result.userId),
        message: 'İşlem tamamlanamadı. Tekrar dene.',
      );
      return false;
    }
  }

  Set<String> _withoutLoading(String userId) {
    return state.loadingUserIds.where((id) => id != userId).toSet();
  }
}
