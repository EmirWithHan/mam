import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../follow/follow_provider.dart';
import '../../profile/profile_models.dart';

class ProfileRecommendationCard extends ConsumerStatefulWidget {
  const ProfileRecommendationCard({super.key, required this.profile});

  final Profile profile;

  @override
  ConsumerState<ProfileRecommendationCard> createState() =>
      _ProfileRecommendationCardState();
}

class _ProfileRecommendationCardState
    extends ConsumerState<ProfileRecommendationCard> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref
          .read(followControllerProvider(widget.profile.userId).notifier)
          .loadStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final followState = ref.watch(
      followControllerProvider(widget.profile.userId),
    );
    final stats = followState.stats;

    final isFollowing = stats?.isFollowedByMe ?? false;
    final isPending = stats?.hasPendingRequestByMe ?? false;
    final canShowAvatar = !widget.profile.isPrivate || isFollowing;
    final avatarUrl = canShowAvatar ? widget.profile.avatarUrl?.trim() : null;

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgBorder,
        side: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            // Avatar
            GestureDetector(
              onTap: () => context.pushNamed(
                RouteNames.publicProfile,
                pathParameters: {'userId': widget.profile.userId},
              ),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primarySoft,
                  image: avatarUrl != null && avatarUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(avatarUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: avatarUrl == null || avatarUrl.isEmpty
                    ? const Icon(
                        Icons.person,
                        color: AppColors.primary,
                        size: 28,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // Name and Trust Score
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => context.pushNamed(
                      RouteNames.publicProfile,
                      pathParameters: {'userId': widget.profile.userId},
                    ),
                    child: Text(
                      widget.profile.firstName ??
                          widget.profile.username ??
                          'Sporcu',
                      style: AppTextStyles.bodyStrong,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.profile.displayHandle ?? '',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Trust score tag
                  Row(
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        color: AppColors.primary,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Güven Skoru: ${widget.profile.trustScoreValue}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),

            // Follow button
            SizedBox(
              width: 110,
              height: 36,
              child: AppButton(
                label: isFollowing
                    ? 'Takip'
                    : isPending
                    ? 'İstek'
                    : 'Takip Et',
                isLoading: followState.loading,
                variant: isFollowing || isPending
                    ? AppButtonVariant.secondary
                    : AppButtonVariant.primary,
                onPressed: () {
                  ref
                      .read(
                        followControllerProvider(
                          widget.profile.userId,
                        ).notifier,
                      )
                      .toggleFollow();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
