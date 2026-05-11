import '../../services/supabase_service.dart';

class BlocksService {
  const BlocksService();

  String? get currentUserId => SupabaseService.client.auth.currentUser?.id;

  Future<List<String>> fetchMyBlockedUserIds() async {
    final userId = currentUserId;
    if (userId == null) return const [];

    final data = await SupabaseService.client
        .from('blocks')
        .select('blocked_id')
        .eq('blocker_id', userId);

    return data.map((row) => row['blocked_id'] as String).toList();
  }

  Future<bool> isUserBlocked(String targetUserId) async {
    final userId = currentUserId;
    if (userId == null) return false;

    final data = await SupabaseService.client
        .from('blocks')
        .select('id')
        .eq('blocker_id', userId)
        .eq('blocked_id', targetUserId)
        .maybeSingle();

    return data != null;
  }

  Future<void> blockUser(String targetUserId) async {
    final userId = currentUserId;
    if (userId == null) {
      throw StateError('You must be signed in to block members.');
    }
    if (userId == targetUserId) {
      throw StateError('You cannot block yourself.');
    }

    final alreadyBlocked = await isUserBlocked(targetUserId);
    if (alreadyBlocked) return;

    await SupabaseService.client.from('blocks').insert({
      'blocker_id': userId,
      'blocked_id': targetUserId,
    });
  }

  Future<void> unblockUser(String targetUserId) async {
    final userId = currentUserId;
    if (userId == null) {
      throw StateError('You must be signed in to unblock members.');
    }

    await SupabaseService.client
        .from('blocks')
        .delete()
        .eq('blocker_id', userId)
        .eq('blocked_id', targetUserId);
  }

  Future<void> toggleBlock({
    required String targetUserId,
    required bool currentlyBlocked,
  }) async {
    if (currentlyBlocked) {
      await unblockUser(targetUserId);
      return;
    }

    await blockUser(targetUserId);
  }
}
