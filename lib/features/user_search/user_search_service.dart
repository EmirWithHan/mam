import '../../services/supabase_service.dart';
import '../follow/follow_models.dart';
import '../follow/follow_service.dart';
import 'user_search_models.dart';

class UserSearchService {
  const UserSearchService({FollowService followService = const FollowService()})
    : _followService = followService;

  final FollowService _followService;

  Future<List<UserSearchResult>> searchProfiles(String query) async {
    final normalized = UserSearchRules.normalizeQuery(query);
    if (!UserSearchRules.canSearch(normalized)) return const [];

    final data = await SupabaseService.client.rpc(
      'search_profiles_by_username',
      params: {'p_query': normalized, 'p_limit': UserSearchRules.maxResults},
    );

    return (data as List<dynamic>)
        .whereType<Map>()
        .map((row) => UserSearchResult.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<FollowActionResult> followUser(String targetUserId) {
    return _followService.followUser(targetUserId);
  }
}
