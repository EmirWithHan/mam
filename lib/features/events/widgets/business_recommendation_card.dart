import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../business/widgets/business_badge.dart';

class BusinessRecommendation {
  const BusinessRecommendation({
    required this.id,
    required this.name,
    this.username,
    this.businessTag,
    this.isVerified = false,
    this.category,
    this.city,
  });

  final String id;
  final String name;
  final String? username;
  final String? businessTag;
  final bool isVerified;
  final String? category;
  final String? city;

  String get displayName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'İşletme';
    return trimmed;
  }

  factory BusinessRecommendation.fromJson(Map<String, dynamic> json) {
    return BusinessRecommendation(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      username: json['username']?.toString(),
      businessTag: json['business_tag']?.toString(),
      isVerified: json['is_verified'] as bool? ?? false,
      category: json['category']?.toString(),
      city: json['city']?.toString(),
    );
  }
}

class BusinessRecommendationCard extends StatelessWidget {
  const BusinessRecommendationCard({super.key, required this.recommendation});

  final BusinessRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.secondarySoft, AppColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.lgBorder,
        child: InkWell(
          borderRadius: AppRadius.lgBorder,
          onTap: recommendation.id.trim().isEmpty
              ? null
              : () => context.pushNamed(
                  RouteNames.businessProfile,
                  pathParameters: {'businessId': recommendation.id},
                ),
          child: Padding(
            padding: AppResponsive.cardPadding(context),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.storefront_outlined,
                    color: AppColors.secondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              recommendation.displayName,
                              style: AppTextStyles.bodyStrong,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (recommendation.isVerified) ...[
                            const SizedBox(width: AppSpacing.xs),
                            const BusinessBadge(isVerified: true),
                          ],
                        ],
                      ),
                      if (recommendation.category != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          recommendation.category!,
                          style: AppTextStyles.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (recommendation.city != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.place_outlined,
                              size: 13,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                recommendation.city!,
                                style: AppTextStyles.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _ViewProfileButton(businessId: recommendation.id),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewProfileButton extends StatelessWidget {
  const _ViewProfileButton({required this.businessId});

  final String businessId;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
      onPressed: businessId.trim().isEmpty
          ? null
          : () => context.pushNamed(
              RouteNames.businessProfile,
              pathParameters: {'businessId': businessId},
            ),
      child: const Text(
        'İncele',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}
