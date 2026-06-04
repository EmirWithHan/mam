import '../../services/supabase_service.dart';
import 'public_profile_models.dart';

class PublicProfileService {
  const PublicProfileService();

  static final Map<String, Future<PublicProfilePreview?>>
  _previewRequestsInFlight = {};

  Future<PublicProfilePreview?> fetchPublicProfilePreview(String userId) async {
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) return null;

    final inFlight = _previewRequestsInFlight[trimmedUserId];
    if (inFlight != null) return inFlight;

    final request = _fetchPublicProfilePreview(trimmedUserId);
    _previewRequestsInFlight[trimmedUserId] = request;
    try {
      return await request;
    } finally {
      _previewRequestsInFlight.remove(trimmedUserId);
    }
  }

  Future<PublicProfilePreview?> _fetchPublicProfilePreview(
    String userId,
  ) async {
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

    final previews = data.whereType<Map>().map(
      (item) => PublicProfilePreview.fromJson(Map<String, dynamic>.from(item)),
    );

    return {for (final preview in previews) preview.userId: preview};
  }
}
