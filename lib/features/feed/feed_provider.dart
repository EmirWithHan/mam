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
    this.commentsLoading = false,
    this.commentsMessage,
    this.commentsByPostId = const {},
  });

  const FeedState.initial()
      : status = FeedStatus.initial,
        posts = const [],
        message = null,
        isCreating = false,
        commentsLoading = false,
        commentsMessage = null,
        commentsByPostId = const {};

  final FeedStatus status;
  final List<PostWithStats> posts;
  final String? message;
  final bool isCreating;
  final bool commentsLoading;
  final String? commentsMessage;
  final Map<String, List<PostComment>> commentsByPostId;

  bool get isLoading => status == FeedStatus.loading;

  FeedState copyWith({
    FeedStatus? status,
    List<PostWithStats>? posts,
    String? message,
    bool? isCreating,
    bool? commentsLoading,
    String? commentsMessage,
    Map<String, List<PostComment>>? commentsByPostId,
    bool clearMessage = false,
    bool clearCommentsMessage = false,
  }) {
    return FeedState(
      status: status ?? this.status,
      posts: posts ?? this.posts,
      message: clearMessage ? null : message ?? this.message,
      isCreating: isCreating ?? this.isCreating,
      commentsLoading: commentsLoading ?? this.commentsLoading,
      commentsMessage: clearCommentsMessage
          ? null
          : commentsMessage ?? this.commentsMessage,
      commentsByPostId: commentsByPostId ?? this.commentsByPostId,
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

final linkedEventsProvider =
    FutureProvider.autoDispose<List<LinkableEvent>>((ref) {
  return ref.watch(feedServiceProvider).fetchMyLinkableEvents();
});

class FeedController extends StateNotifier<FeedState> {
  FeedController(this._feedService) : super(const FeedState.initial());

  final FeedService _feedService;

  Future<void> loadPosts() async {
    state = state.copyWith(status: FeedStatus.loading, clearMessage: true);

    try {
      final posts = await _feedService.fetchPostsWithStats();
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
      final posts = await _feedService.fetchPostsWithStats();
      state = FeedState(status: FeedStatus.success, posts: posts);
      return post;
    } catch (error) {
      state = state.copyWith(isCreating: false, message: '$error');
      return null;
    }
  }

  Future<void> toggleLike(PostWithStats item) async {
    state = state.copyWith(clearMessage: true);

    try {
      await _feedService.toggleLike(
        postId: item.post.id,
        currentlyLiked: item.isLikedByMe,
      );
      final posts = await _feedService.fetchPostsWithStats();
      state = state.copyWith(status: FeedStatus.success, posts: posts);
    } catch (error) {
      state = state.copyWith(message: '$error');
    }
  }

  Future<bool> deletePost(String postId) async {
    state = state.copyWith(clearMessage: true);

    try {
      await _feedService.deleteMyPost(postId);
      final posts = state.posts
          .where((item) => item.post.id != postId)
          .toList(growable: false);
      state = state.copyWith(status: FeedStatus.success, posts: posts);
      await refreshPosts();
      return true;
    } catch (error) {
      state = state.copyWith(message: '$error');
      return false;
    }
  }

  Future<void> fetchComments(String postId) async {
    state = state.copyWith(
      commentsLoading: true,
      clearCommentsMessage: true,
    );

    try {
      final comments = await _feedService.fetchComments(postId);
      final commentsByPostId = Map<String, List<PostComment>>.from(
        state.commentsByPostId,
      );
      commentsByPostId[postId] = comments;
      state = state.copyWith(
        commentsLoading: false,
        commentsByPostId: commentsByPostId,
      );
    } catch (error) {
      state = state.copyWith(
        commentsLoading: false,
        commentsMessage: '$error',
      );
    }
  }

  Future<PostComment?> addComment({
    required String postId,
    required String comment,
  }) async {
    state = state.copyWith(
      commentsLoading: true,
      clearCommentsMessage: true,
    );

    try {
      final newComment = await _feedService.addComment(
        postId: postId,
        comment: comment,
      );
      final comments = await _feedService.fetchComments(postId);
      final posts = await _feedService.fetchPostsWithStats();
      final commentsByPostId = Map<String, List<PostComment>>.from(
        state.commentsByPostId,
      );
      commentsByPostId[postId] = comments;
      state = state.copyWith(
        status: FeedStatus.success,
        posts: posts,
        commentsLoading: false,
        commentsByPostId: commentsByPostId,
      );
      return newComment;
    } catch (error) {
      state = state.copyWith(
        commentsLoading: false,
        commentsMessage: '$error',
      );
      return null;
    }
  }
}
