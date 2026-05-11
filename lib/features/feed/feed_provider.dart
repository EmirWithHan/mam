import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'feed_models.dart';
import 'feed_service.dart';

enum FeedStatus {
  initial,
  loading,
  success,
  error,
}

class FeedState {
  const FeedState({
    required this.status,
    this.posts = const [],
    this.message,
    this.isCreating = false,
  });

  const FeedState.initial()
      : status = FeedStatus.initial,
        posts = const [],
        message = null,
        isCreating = false;

  final FeedStatus status;
  final List<Post> posts;
  final String? message;
  final bool isCreating;

  bool get isLoading => status == FeedStatus.loading;

  FeedState copyWith({
    FeedStatus? status,
    List<Post>? posts,
    String? message,
    bool? isCreating,
    bool clearMessage = false,
  }) {
    return FeedState(
      status: status ?? this.status,
      posts: posts ?? this.posts,
      message: clearMessage ? null : message ?? this.message,
      isCreating: isCreating ?? this.isCreating,
    );
  }
}

final feedServiceProvider = Provider<FeedService>((ref) {
  return const FeedService();
});

final feedControllerProvider =
    StateNotifierProvider<FeedController, FeedState>((ref) {
  return FeedController(ref.watch(feedServiceProvider));
});

class FeedController extends StateNotifier<FeedState> {
  FeedController(this._feedService) : super(const FeedState.initial());

  final FeedService _feedService;

  Future<void> loadPosts() async {
    state = state.copyWith(status: FeedStatus.loading, clearMessage: true);

    try {
      final posts = await _feedService.fetchPosts();
      state = FeedState(status: FeedStatus.success, posts: posts);
    } catch (error) {
      state = FeedState(status: FeedStatus.error, message: '$error');
    }
  }

  Future<void> refreshPosts() => loadPosts();

  Future<Post?> createPost(CreatePostInput input) async {
    state = state.copyWith(isCreating: true, clearMessage: true);

    try {
      final post = await _feedService.createPost(input);
      final posts = await _feedService.fetchPosts();
      state = FeedState(status: FeedStatus.success, posts: posts);
      return post;
    } catch (error) {
      state = state.copyWith(isCreating: false, message: '$error');
      return null;
    }
  }
}
