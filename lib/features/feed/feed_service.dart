import '../../services/storage_service.dart';
import '../../services/supabase_service.dart';
import '../reports/blocks_service.dart';
import 'feed_models.dart';

class FeedService {
  const FeedService({
    StorageService storageService = const StorageService(),
    BlocksService blocksService = const BlocksService(),
  })  : _storageService = storageService,
        _blocksService = blocksService;

  final StorageService _storageService;
  final BlocksService _blocksService;

  Future<List<Post>> fetchPosts() async {
    final data = await SupabaseService.client
        .from('posts')
        .select()
        .order('created_at', ascending: false);
    final blockedUserIds = await _blocksService.fetchMyBlockedUserIds();

    return data
        .map(Post.fromJson)
        .where((post) => !blockedUserIds.contains(post.userId))
        .toList();
  }

  Future<List<PostWithStats>> fetchPostsWithStats() async {
    final posts = await fetchPosts();
    final userId = SupabaseService.client.auth.currentUser?.id;
    final items = <PostWithStats>[];

    for (final post in posts) {
      final likeCount = await _countRows(
        table: 'post_likes',
        column: 'post_id',
        value: post.id,
      );
      final commentCount = await _countRows(
        table: 'post_comments',
        column: 'post_id',
        value: post.id,
      );
      final isLikedByMe = userId == null
          ? false
          : await _hasMyLike(postId: post.id, userId: userId);

      items.add(
        PostWithStats(
          post: post,
          likeCount: likeCount,
          commentCount: commentCount,
          isLikedByMe: isLikedByMe,
        ),
      );
    }

    return items;
  }

  Future<void> likePost(String postId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to like posts.');
    }

    final alreadyLiked = await _hasMyLike(postId: postId, userId: userId);
    if (alreadyLiked) return;

    await SupabaseService.client.from('post_likes').insert({
      'post_id': postId,
      'user_id': userId,
    });
  }

  Future<void> unlikePost(String postId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to unlike posts.');
    }

    await SupabaseService.client
        .from('post_likes')
        .delete()
        .eq('post_id', postId)
        .eq('user_id', userId);
  }

  Future<void> toggleLike({
    required String postId,
    required bool currentlyLiked,
  }) async {
    if (currentlyLiked) {
      await unlikePost(postId);
      return;
    }

    await likePost(postId);
  }

  Future<List<PostComment>> fetchComments(String postId) async {
    final data = await SupabaseService.client
        .from('post_comments')
        .select()
        .eq('post_id', postId)
        .order('created_at');
    final blockedUserIds = await _blocksService.fetchMyBlockedUserIds();

    return data
        .map(PostComment.fromJson)
        .where((comment) => !blockedUserIds.contains(comment.userId))
        .toList();
  }

  Future<PostComment> addComment({
    required String postId,
    required String comment,
  }) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to comment.');
    }

    final trimmed = comment.trim();
    if (trimmed.isEmpty) {
      throw StateError('Comment cannot be empty.');
    }

    final data = await SupabaseService.client
        .from('post_comments')
        .insert({
          'post_id': postId,
          'user_id': userId,
          'comment': trimmed,
        })
        .select()
        .single();

    return PostComment.fromJson(data);
  }

  Future<Post> createPost(CreatePostInput input) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to create a post.');
    }

    final imageUrl = await _storageService.uploadPostImage(
      bytes: input.imageBytes,
      fileName: input.fileName,
      contentType: input.contentType,
    );

    final data = <String, dynamic>{
      'user_id': userId,
      'image_url': imageUrl,
      'caption': _nullableTrim(input.caption),
    };

    final eventId = _nullableTrim(input.eventId);
    if (eventId != null) {
      data['event_id'] = eventId;
    }

    final created = await SupabaseService.client
        .from('posts')
        .insert(data)
        .select()
        .single();

    return Post.fromJson(created);
  }
}

Future<int> _countRows({
  required String table,
  required String column,
  required String value,
}) async {
  final data = await SupabaseService.client
      .from(table)
      .select('id')
      .eq(column, value);

  return data.length;
}

Future<bool> _hasMyLike({
  required String postId,
  required String userId,
}) async {
  final data = await SupabaseService.client
      .from('post_likes')
      .select('id')
      .eq('post_id', postId)
      .eq('user_id', userId)
      .maybeSingle();

  return data != null;
}

String? _nullableTrim(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
