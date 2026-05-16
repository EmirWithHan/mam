import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/auth_provider.dart';
import '../../follow/widgets/follow_button.dart';
import '../../profile/widgets/public_profile_preview_tile.dart';
import '../../reports/reports_models.dart';
import '../../reports/widgets/block_button.dart';
import '../../reports/widgets/report_button.dart';
import '../feed_models.dart';

class PostCard extends ConsumerWidget {
  const PostCard({
    super.key,
    required this.item,
    required this.onToggleLike,
    required this.onOpenComments,
  });

  final PostWithStats item;
  final VoidCallback onToggleLike;
  final VoidCallback onOpenComments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = item.post;
    final caption = post.caption?.trim();
    final currentUserId = ref.watch(authControllerProvider).userId;
    final isMine = currentUserId != null && post.userId == currentUserId;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.xlBorder,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PublicProfilePreviewTile(
                  userId: post.userId,
                  compact: true,
                  trailing: !isMine
                      ? FollowButton(
                          targetUserId: post.userId,
                          compact: true,
                        )
                      : null,
                ),
                if (!isMine)
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      ReportButton(
                        targetType: ReportTargetType.post,
                        targetId: post.id,
                        compact: true,
                      ),
                      ReportButton(
                        targetType: ReportTargetType.user,
                        targetId: post.userId,
                        compact: true,
                      ),
                      BlockButton(
                        targetUserId: post.userId,
                        compact: true,
                      ),
                    ],
                  ),
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: AppRadius.lgBorder,
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.network(
                      post.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const ColoredBox(
                          color: AppColors.border,
                          child: Center(child: Icon(Icons.image_not_supported)),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (post.eventId != null) ...[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.secondarySoft,
                      borderRadius: AppRadius.pillBorder,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.event_outlined,
                            color: AppColors.primary,
                            size: 15,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'Linked event',
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (caption != null && caption.isNotEmpty) ...[
                  Text(caption, style: AppTextStyles.body),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Text(_formatDate(post.createdAt), style: AppTextStyles.caption),
                const SizedBox(height: AppSpacing.md),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: AppRadius.pillBorder,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: onToggleLike,
                          icon: Icon(
                            item.isLikedByMe
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: item.isLikedByMe
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                          label: Text('${item.likeCount}'),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        TextButton.icon(
                          onPressed: onOpenComments,
                          icon: const Icon(
                            Icons.mode_comment_outlined,
                            color: AppColors.textMuted,
                          ),
                          label: Text('${item.commentCount}'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }
}
