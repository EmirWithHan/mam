import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/error_messages.dart';
import '../../core/utils/pagination.dart';
import '../../services/supabase_service.dart';
import 'feed_models.dart';
import 'feed_service.dart';

enum FeedStatus { initial, loading, success, error }

class FeedState {
  const FeedState({
    required this.status,
    this.posts = const [],
    this.message,
    this.isCreating = false,
    this.commentsLoading = false,
    this.commentsMessage,
    this.commentsByPostId = const {},
    this.commentsHasMoreByPostId = const {},
    this.likeLoadingPostIds = const {},
    this.hasMorePosts = true,
    this.isLoadingMorePosts = false,
  });

  const FeedState.initial()
    : status = FeedStatus.initial,
      posts = const [],
      message = null,
      isCreating = false,
      commentsLoading = false,
      commentsMessage = null,
      commentsByPostId = const {},
      commentsHasMoreByPostId = const {},
      likeLoadingPostIds = const {},
      hasMorePosts = true,
      isLoadingMorePosts = false;

  final FeedStatus status;
  final List<PostWithStats> posts;
  final String? message;
  final bool isCreating;
  final bool commentsLoading;
  final String? commentsMessage;
  final Map<String, List<PostComment>> commentsByPostId;
  final Map<String, bool> commentsHasMoreByPostId;
  final Set<String> likeLoadingPostIds;
  final bool hasMorePosts;
  final bool isLoadingMorePosts;

  bool get isLoading => status == FeedStatus.loading;
  bool get isEmptySuccess => status == FeedStatus.success && posts.isEmpty;

  FeedState copyWith({
    FeedStatus? status,
    List<PostWithStats>? posts,
    String? message,
    bool? isCreating,
    bool? commentsLoading,
    String? commentsMessage,
    Map<String, List<PostComment>>? commentsByPostId,
    Map<String, bool>? commentsHasMoreByPostId,
    Set<String>? likeLoadingPostIds,
    bool? hasMorePosts,
    bool? isLoadingMorePosts,
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
      commentsHasMoreByPostId:
          commentsHasMoreByPostId ?? this.commentsHasMoreByPostId,
      likeLoadingPostIds: likeLoadingPostIds ?? this.likeLoadingPostIds,
      hasMorePosts: hasMorePosts ?? this.hasMorePosts,
      isLoadingMorePosts: isLoadingMorePosts ?? this.isLoadingMorePosts,
    );
  }

  bool isLikeLoading(String postId) => likeLoadingPostIds.contains(postId);
}

final feedServiceProvider = Provider<FeedService>((ref) {
  return const FeedService();
});

final feedControllerProvider = StateNotifierProvider<FeedController, FeedState>(
  (ref) {
    return FeedController(ref.watch(feedServiceProvider));
  },
);

final linkedEventsProvider = FutureProvider.autoDispose<List<LinkableEvent>>((
  ref,
) {
  return ref.watch(feedServiceProvider).fetchMyLinkableEvents();
});

class FeedController extends StateNotifier<FeedState> {
  FeedController(this._feedService) : super(const FeedState.initial());

  final FeedService _feedService;
  RealtimeChannel? _commentsRealtimeChannel;
  Timer? _commentsRealtimeDebounce;
  String? _commentsRealtimePostId;

  Future<void> loadPosts({bool force = false}) async {
    if (!force && state.status == FeedStatus.success) return;
    state = state.copyWith(status: FeedStatus.loading, clearMessage: true);

    try {
      final posts = await _feedService.fetchPostsWithStats();
      state = FeedState(
        status: FeedStatus.success,
        posts: posts,
        hasMorePosts: pageHasMore(posts.length, SupabasePageSizes.feed),
      );
    } catch (error) {
      state = state.copyWith(
        status: FeedStatus.error,
        message: friendlyFeedLoadErrorMessage(error),
      );
    }
  }

  Future<void> refreshPosts() => loadPosts(force: true);

  void startCommentsRealtime(String postId) {
    final trimmedPostId = postId.trim();
    if (trimmedPostId.isEmpty) {
      stopCommentsRealtime();
      return;
    }
    if (_commentsRealtimePostId == trimmedPostId &&
        _commentsRealtimeChannel != null) {
      return;
    }

    stopCommentsRealtime();
    try {
      _commentsRealtimePostId = trimmedPostId;
      _commentsRealtimeChannel = SupabaseService.client
          .channel('post_comments:$trimmedPostId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'post_comments',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'post_id',
              value: trimmedPostId,
            ),
            callback: (_) => _scheduleCommentsRefresh(trimmedPostId),
          )
          .subscribe();
    } catch (error) {
      logSupabaseDebug('Feed', 'comments realtime subscribe', error);
      stopCommentsRealtime();
    }
  }

  void stopCommentsRealtime() {
    _commentsRealtimeDebounce?.cancel();
    _commentsRealtimeDebounce = null;
    final channel = _commentsRealtimeChannel;
    _commentsRealtimeChannel = null;
    _commentsRealtimePostId = null;
    if (channel != null) {
      unawaited(SupabaseService.client.removeChannel(channel));
    }
  }

  void _scheduleCommentsRefresh(String postId) {
    _commentsRealtimeDebounce?.cancel();
    _commentsRealtimeDebounce = Timer(const Duration(milliseconds: 600), () {
      unawaited(fetchComments(postId));
      unawaited(refreshPosts());
    });
  }

  Future<void> loadMorePosts() async {
    if (state.isLoadingMorePosts || state.isLoading || !state.hasMorePosts) {
      return;
    }

    state = state.copyWith(isLoadingMorePosts: true, clearMessage: true);
    try {
      final nextPosts = await _feedService.fetchPostsWithStats(
        offset: state.posts.length,
      );
      state = state.copyWith(
        status: FeedStatus.success,
        posts: appendUniqueByKey(
          state.posts,
          nextPosts,
          (item) => item.post.id,
        ),
        hasMorePosts: pageHasMore(nextPosts.length, SupabasePageSizes.feed),
        isLoadingMorePosts: false,
      );
    } catch (error) {
      state = state.copyWith(
        isLoadingMorePosts: false,
        message: friendlyFeedLoadErrorMessage(error),
      );
    }
  }

  Future<Post?> createPost(CreatePostInput input) async {
    state = state.copyWith(isCreating: true, clearMessage: true);

    try {
      final post = await _feedService.createPost(input);
      try {
        final posts = await _feedService.fetchPostsWithStats();
        state = FeedState(
          status: FeedStatus.success,
          posts: posts,
          hasMorePosts: pageHasMore(posts.length, SupabasePageSizes.feed),
        );
      } catch (refreshError) {
        state = state.copyWith(
          isCreating: false,
          message: friendlyFeedRefreshErrorMessage(refreshError),
        );
      }
      return post;
    } catch (error) {
      state = state.copyWith(
        isCreating: false,
        message: friendlyCreatePostErrorMessage(error),
      );
      return null;
    }
  }

  Future<void> toggleLike(PostWithStats item) async {
    final postId = item.post.id;

    final index = state.posts.indexWhere((p) => p.post.id == postId);
    final wasLiked = index != -1
        ? state.posts[index].isLikedByMe
        : item.isLikedByMe;
    final originalLikeCount = index != -1
        ? state.posts[index].likeCount
        : item.likeCount;
    final likeDelta = wasLiked ? -1 : 1;

    final updatedItem = (index != -1 ? state.posts[index] : item).copyWith(
      isLikedByMe: !wasLiked,
      likeCount: (originalLikeCount + likeDelta).clamp(0, 1 << 31).toInt(),
    );

    final List<PostWithStats> updatedPosts;
    if (index != -1) {
      updatedPosts = state.posts
          .map((postItem) {
            if (postItem.post.id != postId) return postItem;
            return updatedItem;
          })
          .toList(growable: false);
    } else {
      updatedPosts = [...state.posts, updatedItem];
    }

    state = state.copyWith(clearMessage: true, posts: updatedPosts);

    try {
      await _feedService.toggleLike(postId: postId, currentlyLiked: wasLiked);
    } catch (error) {
      final revertedPosts = state.posts
          .map((postItem) {
            if (postItem.post.id != postId) return postItem;
            return postItem.copyWith(
              isLikedByMe: wasLiked,
              likeCount: originalLikeCount,
            );
          })
          .toList(growable: false);

      state = state.copyWith(
        message: 'Beğeni güncellenemedi. Lütfen tekrar dene.',
        posts: revertedPosts,
      );
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
      state = state.copyWith(message: friendlyErrorMessage(error));
      return false;
    }
  }

  Future<void> fetchComments(String postId) async {
    state = state.copyWith(commentsLoading: true, clearCommentsMessage: true);

    try {
      final comments = await _feedService.fetchComments(postId);
      final commentsByPostId = Map<String, List<PostComment>>.from(
        state.commentsByPostId,
      );
      final commentsHasMoreByPostId = Map<String, bool>.from(
        state.commentsHasMoreByPostId,
      );
      commentsByPostId[postId] = comments;
      commentsHasMoreByPostId[postId] = pageHasMore(
        comments.length,
        SupabasePageSizes.comments,
      );
      state = state.copyWith(
        commentsLoading: false,
        commentsByPostId: commentsByPostId,
        commentsHasMoreByPostId: commentsHasMoreByPostId,
      );
    } catch (error) {
      state = state.copyWith(
        commentsLoading: false,
        commentsMessage: friendlyErrorMessage(error),
      );
    }
  }

  Future<void> loadMoreComments(String postId) async {
    final currentComments = state.commentsByPostId[postId] ?? const [];
    final hasMore = state.commentsHasMoreByPostId[postId] ?? true;
    if (state.commentsLoading || !hasMore) return;

    state = state.copyWith(commentsLoading: true, clearCommentsMessage: true);

    try {
      final nextComments = await _feedService.fetchComments(
        postId,
        offset: currentComments.length,
      );
      final commentsByPostId = Map<String, List<PostComment>>.from(
        state.commentsByPostId,
      );
      final commentsHasMoreByPostId = Map<String, bool>.from(
        state.commentsHasMoreByPostId,
      );
      commentsByPostId[postId] = appendUniqueByKey(
        currentComments,
        nextComments,
        (comment) => comment.id,
      );
      commentsHasMoreByPostId[postId] = pageHasMore(
        nextComments.length,
        SupabasePageSizes.comments,
      );
      state = state.copyWith(
        commentsLoading: false,
        commentsByPostId: commentsByPostId,
        commentsHasMoreByPostId: commentsHasMoreByPostId,
      );
    } catch (error) {
      state = state.copyWith(
        commentsLoading: false,
        commentsMessage: friendlyErrorMessage(error),
      );
    }
  }

  Future<PostComment?> addComment({
    required String postId,
    required String comment,
  }) async {
    state = state.copyWith(commentsLoading: true, clearCommentsMessage: true);

    try {
      final newComment = await _feedService.addComment(
        postId: postId,
        comment: comment,
      );
      final commentsByPostId = Map<String, List<PostComment>>.from(
        state.commentsByPostId,
      );
      commentsByPostId[postId] = [
        ...(commentsByPostId[postId] ?? const []),
        newComment,
      ];
      final posts = state.posts
          .map((item) {
            if (item.post.id != postId) return item;
            return item.copyWith(commentCount: item.commentCount + 1);
          })
          .toList(growable: false);
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
        commentsMessage: friendlyErrorMessage(error),
      );
      return null;
    }
  }

  @override
  void dispose() {
    stopCommentsRealtime();
    super.dispose();
  }
}
