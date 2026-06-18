import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../profile_badges.dart';

class ProfileBadgesSection extends StatelessWidget {
  const ProfileBadgesSection({
    super.key,
    required this.badges,
    this.trustScore,
    this.isLoading = false,
    this.errorMessage,
  });

  factory ProfileBadgesSection.fromAsync(
    AsyncValue<List<ProfileBadge>> async, {
    int? trustScore,
  }) {
    return async.when(
      data: (badges) =>
          ProfileBadgesSection(badges: badges, trustScore: trustScore),
      loading: () => ProfileBadgesSection(
        badges: const [],
        trustScore: trustScore,
        isLoading: true,
      ),
      error: (_, _) => ProfileBadgesSection(
        badges: ProfileBadgeCatalog.withUpcoming(
          ProfileBadgeCatalog.fallbackCatalog(),
        ),
        trustScore: trustScore,
        errorMessage: 'Rozetler yüklenemedi.',
      ),
    );
  }

  final List<ProfileBadge> badges;
  final int? trustScore;
  final bool isLoading;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final visibleBadges = ProfileBadgeCatalog.launchVisible(badges);
    final previewBadges = ProfileBadgeCatalog.preview(visibleBadges);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.lgBorder,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Rozetler ve Güven', style: AppTextStyles.title),
                ),
                TextButton(
                  onPressed: () => _showAllBadges(context, visibleBadges),
                  child: const Text('Tümünü Gör'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: LinearProgressIndicator(minHeight: 3),
              )
            else if (errorMessage != null)
              Text(
                errorMessage!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              )
            else ...[
              if (trustScore != null) ...[
                _TrustScoreCard(score: trustScore!),
                const SizedBox(height: AppSpacing.md),
              ],
              if (previewBadges.isEmpty)
                Text(
                  'Henüz rozet kazanılmadı. Etkinliklere katılarak rozet kazanabilirsin.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                )
              else
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final badge in previewBadges)
                      _BadgeChip(badge: badge, compact: true),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showAllBadges(
    BuildContext context,
    List<ProfileBadge> visibleBadges,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: AppRadius.pillBorder,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Tüm Rozetler', style: AppTextStyles.headline),
                const SizedBox(height: AppSpacing.md),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: visibleBadges.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      return _BadgeTile(badge: visibleBadges[index]);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TrustScoreCard extends StatelessWidget {
  const _TrustScoreCard({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.06),
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: AppColors.success.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_user,
                color: AppColors.success,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Güven Puanı:', style: AppTextStyles.bodyStrong),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '$score/100',
                        style: AppTextStyles.bodyStrong.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Trust Score, etkinliklere katılım, zamanında iptal ve QR doğrulama gibi davranışlara göre otomatik hesaplanır.',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.badge, this.compact = false});

  final ProfileBadge badge;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.sm : AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(badge.icon, size: 16, color: AppColors.primary),
            const SizedBox(width: AppSpacing.xs),
            Text(
              badge.label,
              style: AppTextStyles.label.copyWith(color: AppColors.primary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge});

  final ProfileBadge badge;

  @override
  Widget build(BuildContext context) {
    final earned = badge.status == ProfileBadgeStatus.earned;
    final upcoming = badge.status == ProfileBadgeStatus.upcoming;
    final statusLabel = earned
        ? 'Kazanıldı'
        : upcoming
        ? 'Yakında'
        : 'Kilitli';
    final color = earned
        ? AppColors.primary
        : upcoming
        ? AppColors.warning
        : AppColors.textMuted;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.lgBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(badge.icon, color: color, size: 21),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    badge.label,
                    style: AppTextStyles.bodyStrong,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    badge.description,
                    style: AppTextStyles.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            DecoratedBox(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: AppRadius.pillBorder,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Text(
                  statusLabel,
                  style: AppTextStyles.label.copyWith(color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
