import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/error_messages.dart';
import 'home_feed_service.dart';

enum HomeFeedStatus { initial, loading, success, error }

class HomeFeedState {
  const HomeFeedState({
    required this.status,
    this.items = const [],
    this.message,
  });

  const HomeFeedState.initial()
    : status = HomeFeedStatus.initial,
      items = const [],
      message = null;

  final HomeFeedStatus status;
  final List<dynamic> items;
  final String? message;

  bool get isLoading => status == HomeFeedStatus.loading;

  HomeFeedState copyWith({
    required HomeFeedStatus status,
    List<dynamic>? items,
    String? message,
  }) {
    return HomeFeedState(
      status: status,
      items: items ?? this.items,
      message: message,
    );
  }
}

final homeFeedServiceProvider = Provider<HomeFeedService>((ref) {
  return const HomeFeedService();
});

class HomeFeedController extends StateNotifier<HomeFeedState> {
  HomeFeedController(this._service) : super(const HomeFeedState.initial());

  final HomeFeedService _service;

  Future<void> loadFeed({bool force = false}) async {
    if (!force && state.status == HomeFeedStatus.success) return;
    state = state.copyWith(status: HomeFeedStatus.loading);

    try {
      final items = await _service.fetchMixedFeed();
      state = HomeFeedState(status: HomeFeedStatus.success, items: items);
    } catch (error) {
      state = HomeFeedState(
        status: HomeFeedStatus.error,
        message: friendlyErrorMessage(error),
      );
    }
  }

  Future<void> refreshFeed() => loadFeed(force: true);
}

final homeFeedProvider =
    StateNotifierProvider<HomeFeedController, HomeFeedState>((ref) {
      final service = ref.watch(homeFeedServiceProvider);
      return HomeFeedController(service);
    });
