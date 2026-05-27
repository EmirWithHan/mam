import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/storage_service.dart';
import '../../services/supabase_service.dart';
import '../reports/blocks_service.dart';
import 'feed_models.dart';

class FeedService {
  const FeedService({
    StorageService storageService = const StorageService(),
    BlocksService blocksService = const BlocksService(),
  }) : _storageService = storageService,
       _blocksService = blocksService;

  final StorageService _storageService;
  final BlocksService _blocksService;

  Future<List<Post>> fetchPosts() async {
    final data = await SupabaseService.client.rpc('get_visible_feed_posts');
    final blockedUserIds = await _blocksService.fetchMyBlockedUserIds();

    return (data as List<dynamic>)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .map(Post.fromJson)
        .where((post) => !post.isArchived)
        .where((post) => !blockedUserIds.contains(post.userId))
        .toList();
  }

  Future<List<PostWithStats>> fetchPostsWithStats() async {
    try {
      final data = await SupabaseService.client.rpc(
        'get_visible_feed_posts_with_stats',
      );
      final blockedUserIds = await _blocksService.fetchMyBlockedUserIds();

      return (data as List<dynamic>)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .map(PostWithStats.fromFeedJson)
          .where((item) => !item.post.isArchived)
          .where((item) => !blockedUserIds.contains(item.post.userId))
          .toList();
    } catch (error) {
      _logFeedError('feed posts with stats query failed', error);
      rethrow;
    }
  }

  Future<List<LinkableEvent>> fetchMyLinkableEvents() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to link an event.');
    }

    final participantRows = await SupabaseService.client
        .from('event_participants')
        .select('event_id,role,attendance_status')
        .eq('user_id', userId)
        .inFilter('attendance_status', ['planned', 'attended']);

    final rolesByEventId = <String, String>{};
    final statusesByEventId = <String, String>{};
    for (final row in participantRows) {
      final participant = Map<String, dynamic>.from(row);
      final eventId = participant['event_id'] as String?;
      if (eventId == null) continue;
      rolesByEventId[eventId] = participant['role'] as String? ?? 'participant';
      statusesByEventId[eventId] =
          participant['attendance_status'] as String? ?? 'planned';
    }

    final eventRowsById = <String, Map<String, dynamic>>{};
    final eventIds = rolesByEventId.keys.toList();
    if (eventIds.isNotEmpty) {
      final participantEventRows = await SupabaseService.client
          .from('events')
          .select('id,title,sport_type,city,district,event_date,status')
          .inFilter('id', eventIds);

      for (final row in participantEventRows) {
        final event = Map<String, dynamic>.from(row);
        final eventId = event['id'] as String?;
        if (eventId != null) eventRowsById[eventId] = event;
      }
    }

    final hostedEventRows = await SupabaseService.client
        .from('events')
        .select('id,title,sport_type,city,district,event_date,status')
        .eq('host_id', userId);

    for (final row in hostedEventRows) {
      final event = Map<String, dynamic>.from(row);
      final eventId = event['id'] as String?;
      if (eventId == null) continue;
      rolesByEventId[eventId] = 'host';
      statusesByEventId[eventId] = statusesByEventId[eventId] ?? 'planned';
      eventRowsById[eventId] = event;
    }

    final now = DateTime.now();
    final events = eventRowsById.entries.map((entry) {
      return LinkableEvent.fromJson(
        entry.value,
        role: rolesByEventId[entry.key],
        status: statusesByEventId[entry.key],
      );
    }).toList();

    events.sort((a, b) {
      final aPast = !a.eventDate.isAfter(now);
      final bPast = !b.eventDate.isAfter(now);
      if (aPast != bPast) return aPast ? -1 : 1;
      return b.eventDate.compareTo(a.eventDate);
    });

    return events;
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

  Future<void> deleteMyPost(String postId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to delete posts.');
    }

    await SupabaseService.client.rpc(
      'delete_my_post',
      params: {'p_post_id': postId},
    );
  }

  Future<List<PostComment>> fetchComments(String postId) async {
    await _ensureCommentsVisible(postId);

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
    await _ensureCommentsVisible(postId);

    final data = await SupabaseService.client
        .from('post_comments')
        .insert({'post_id': postId, 'user_id': userId, 'comment': trimmed})
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

    final data = input.toInsertJson(userId: userId, imageUrl: imageUrl);

    final created = await SupabaseService.client
        .from('posts')
        .insert(data)
        .select()
        .single()
        .catchError((Object error) {
          _logFeedError('post insert failed', error);
          throw error;
        });

    return Post.fromJson(created);
  }

  Future<void> _ensureCommentsVisible(String postId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    final post = await SupabaseService.client
        .from('posts')
        .select()
        .eq('id', postId)
        .maybeSingle();

    if (post == null) return;
    final isOwner = userId != null && post['user_id'] == userId;
    final commentsHidden = post['comments_hidden'] as bool? ?? false;
    if (commentsHidden && !isOwner) {
      throw StateError('Yorumlar gizlendi.');
    }
  }
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

void _logFeedError(String label, Object error) {
  final code = error is PostgrestException ? error.code : null;
  final message = error is PostgrestException
      ? error.message
      : error.toString();
  debugPrint(
    '[Feed] $label'
    '${code == null ? '' : ' code=$code'}'
    ' message=$message',
  );
}
