import '../../services/supabase_service.dart';
import 'public_profile_models.dart';

class PublicProfileService {
  const PublicProfileService();

  Future<PublicProfilePreview?> fetchPublicProfilePreview(String userId) async {
    final data = await SupabaseService.client.rpc(
      'get_public_profile_preview',
      params: {'p_user_id': userId},
    );

    if (data is List && data.isNotEmpty) {
      return PublicProfilePreview.fromJson(
        Map<String, dynamic>.from(data.first as Map),
      );
    }

    if (data is Map) {
      return PublicProfilePreview.fromJson(Map<String, dynamic>.from(data));
    }

    return null;
  }

  Future<Map<String, PublicProfilePreview>> fetchPublicProfilePreviews(
    List<String> userIds,
  ) async {
    final uniqueUserIds = userIds
        .map((userId) => userId.trim())
        .where((userId) => userId.isNotEmpty)
        .toSet()
        .toList();

    if (uniqueUserIds.isEmpty) return const {};

    final data = await SupabaseService.client.rpc(
      'get_public_profile_previews',
      params: {'p_user_ids': uniqueUserIds},
    );

    if (data is! List) return const {};

    final previews = data
        .whereType<Map>()
        .map((item) => PublicProfilePreview.fromJson(Map<String, dynamic>.from(item)));

    return {
      for (final preview in previews) preview.userId: preview,
    };
  }
}
