import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'public_profile_models.dart';
import 'public_profile_service.dart';

final publicProfileServiceProvider = Provider<PublicProfileService>((ref) {
  return const PublicProfileService();
});

final publicProfilePreviewProvider =
    FutureProvider.family<PublicProfilePreview?, String>((ref, userId) {
      return ref
          .watch(publicProfileServiceProvider)
          .fetchPublicProfilePreview(userId);
    });

final publicProfilePreviewsProvider =
    FutureProvider.family<Map<String, PublicProfilePreview>, List<String>>((
      ref,
      userIds,
    ) {
      return ref
          .watch(publicProfileServiceProvider)
          .fetchPublicProfilePreviews(userIds);
    });
