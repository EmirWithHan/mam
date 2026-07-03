import '../../services/supabase_service.dart';
import '../../core/utils/error_messages.dart';
import '../feed/feed_models.dart';
import '../profile/public_profile_service.dart';

class HomeFeedService {
  const HomeFeedService();

  Future<List<dynamic>> fetchMixedFeed() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      // 2. Fetch followed user IDs
      final followsData = await SupabaseService.client
          .from('follows')
          .select('following_id')
          .eq('follower_id', userId);
      final followedIds = followsData
          .map((row) => row['following_id'] as String)
          .toList();

      // 3. Fetch blocked user IDs
      final blockedData = await SupabaseService.client
          .from('blocks')
          .select('blocker_id, blocked_id')
          .or('blocker_id.eq.$userId,blocked_id.eq.$userId');
      final blockedUserIds = blockedData.map((row) {
        final map = Map<String, dynamic>.from(row);
        return map['blocker_id'] == userId
            ? map['blocked_id'] as String
            : map['blocker_id'] as String;
      }).toSet();

      // 4. Fetch past co-participant user IDs
      final myEventsData = await SupabaseService.client
          .from('event_participants')
          .select('event_id')
          .eq('user_id', userId)
          .inFilter('attendance_status', ['planned', 'attended']);
      final myEventIds = myEventsData
          .map((row) => row['event_id'] as String)
          .toList();

      List<String> coParticipantIds = [];
      if (myEventIds.isNotEmpty) {
        final othersData = await SupabaseService.client
            .from('event_participants')
            .select('user_id')
            .inFilter('event_id', myEventIds)
            .neq('user_id', userId)
            .inFilter('attendance_status', ['planned', 'attended']);
        coParticipantIds = othersData
            .map((row) => row['user_id'] as String)
            .where((id) => !blockedUserIds.contains(id))
            .toSet()
            .toList();
      }

      // --- ASYNC FETCHES ---
      // Source A: Followed posts (via RPC get_visible_feed_posts_with_stats)
      Future<List<PostWithStats>> fetchFollowedPosts() async {
        try {
          final data = await SupabaseService.client.rpc(
            'get_visible_feed_posts_with_stats',
            params: {'p_limit': 30, 'p_offset': 0},
          );
          return (data as List<dynamic>)
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .map(PostWithStats.fromFeedJson)
              .where((item) => !item.post.isArchived)
              .where((item) => !blockedUserIds.contains(item.post.userId))
              .toList();
        } catch (error) {
          logSupabaseDebug('HomeFeed', 'fetchFollowedPosts', error);
          rethrow;
        }
      }

      // Source E: Past participants posts
      Future<List<PostWithStats>> fetchPastParticipantPosts() async {
        final postsUserIds = coParticipantIds
            .where((id) => !followedIds.contains(id) && id != userId)
            .toList();
        if (postsUserIds.isEmpty) return [];
        try {
          final data = await SupabaseService.client
              .from('posts')
              .select('''
                id, user_id, event_id, image_url, caption, comments_hidden, is_archived, created_at, updated_at,
                post_likes ( user_id ),
                post_comments ( id )
              ''')
              .inFilter('user_id', postsUserIds)
              .eq('is_archived', false)
              .order('created_at', ascending: false)
              .limit(20);

          final List<dynamic> dataList = data as List<dynamic>;
          if (dataList.isEmpty) return [];

          const publicProfileService = PublicProfileService();
          final previewMap = await publicProfileService
              .fetchPublicProfilePreviews(postsUserIds);

          return dataList
              .map((row) {
                final map = Map<String, dynamic>.from(row);
                final authorId = map['user_id'] as String;
                final preview = previewMap[authorId];
                if (preview == null ||
                    (preview.isPrivate && !preview.canViewExtendedProfile)) {
                  return null;
                }
                final postMap = {
                  ...map,
                  'author_username': preview.username,
                  'author_tag': preview.tag,
                  'author_avatar_url': preview.canShowAvatar
                      ? preview.avatarUrl
                      : null,
                };
                final post = Post.fromJson(postMap);
                final likes = map['post_likes'] as List? ?? [];
                final comments = map['post_comments'] as List? ?? [];
                final isLikedByMe = likes.any(
                  (like) => (like as Map)['user_id'] == userId,
                );

                return PostWithStats(
                  post: post,
                  likeCount: likes.length,
                  commentCount: comments.length,
                  isLikedByMe: isLikedByMe,
                );
              })
              .whereType<PostWithStats>()
              .toList();
        } catch (error) {
          logSupabaseDebug('HomeFeed', 'fetchPastParticipantPosts', error);
          rethrow;
        }
      }

      // Trigger all fetches in parallel
      final results = await Future.wait([
        fetchFollowedPosts(),
        fetchPastParticipantPosts(),
      ]);

      final followedPosts = results[0] as List<PostWithStats>;
      final pastParticipantPosts = results[1] as List<PostWithStats>;

      // Combine and Interleave
      final List<dynamic> mixedFeed = _mixFeedItems(
        followedPosts: followedPosts,
        pastParticipantPosts: pastParticipantPosts,
      );

      return mixedFeed;
    } catch (error) {
      rethrow;
    }
  }

  List<dynamic> _mixFeedItems({
    required List<PostWithStats> followedPosts,
    required List<PostWithStats> pastParticipantPosts,
  }) {
    // Combine and sort posts (followed + past participants) by recency
    final allPosts = [...followedPosts, ...pastParticipantPosts];
    final seenPostIds = <String>{};
    final List<PostWithStats> uniquePosts = [];
    for (final post in allPosts) {
      if (seenPostIds.add(post.post.id)) {
        uniquePosts.add(post);
      }
    }
    uniquePosts.sort((a, b) => b.post.createdAt.compareTo(a.post.createdAt));

    return [...uniquePosts];
  }
}
