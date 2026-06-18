import 'package:flutter/foundation.dart';
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

    try {
      final results = await Future.wait(
        uniqueUserIds.map((userId) => fetchPublicProfilePreview(userId)),
      );

      final Map<String, PublicProfilePreview> resultMap = {};
      for (final preview in results) {
        if (preview != null) {
          resultMap[preview.userId] = preview;
        }
      }
      return resultMap;
    } catch (e) {
      debugPrint(
        '[PublicProfileService] Error fetching previews in parallel: $e',
      );
      return const {};
    }
  }
}
