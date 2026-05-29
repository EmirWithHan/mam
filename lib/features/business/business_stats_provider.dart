import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'business_stats_models.dart';
import 'business_stats_service.dart';

final businessStatsServiceProvider = Provider<BusinessStatsService>((ref) {
  return const BusinessStatsService();
});

final businessStatsProvider = FutureProvider.family<BusinessStats, String>((
  ref,
  businessId,
) {
  return ref.watch(businessStatsServiceProvider).fetchBusinessStats(businessId);
});
