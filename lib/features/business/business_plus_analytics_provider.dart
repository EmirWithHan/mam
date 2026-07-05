import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'business_provider.dart';
import 'business_plus_analytics_models.dart';

final businessPlusAnalyticsProvider =
    FutureProvider.family<BusinessPlusAnalytics, String>((
      ref,
      businessId,
    ) async {
      final data = await ref
          .watch(businessAccountServiceProvider)
          .fetchBusinessPlusAnalytics(businessId);
      return BusinessPlusAnalytics.fromJson(data);
    });
