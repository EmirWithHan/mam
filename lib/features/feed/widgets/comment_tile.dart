import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../profile/widgets/public_profile_avatar.dart';
import '../../profile/widgets/public_profile_name.dart';
import '../../reports/reports_models.dart';
import '../../reports/widgets/block_button.dart';
import '../../reports/widgets/report_button.dart';
import '../feed_models.dart';

class CommentTile extends StatelessWidget {
  const CommentTile({
    super.key,
    required this.comment,
    required this.currentUserId,
  });

  final PostComment comment;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final isMine = currentUserId != null && comment.userId == currentUserId;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgBorder,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PublicProfileAvatar(userId: comment.userId, radius: 16),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: PublicProfileName(
                    userId: comment.userId,
                    compact: true,
                  ),
                ),
                if (!isMine) ...[
                  const SizedBox(width: AppSpacing.xs),
                  _CommentOverflowButton(comment: comment),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(comment.comment, style: AppTextStyles.body),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(
                  Icons.schedule,
                  color: AppColors.textMuted,
                  size: 14,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  _formatDate(comment.createdAt),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ],
        ),
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

class _CommentOverflowButton extends StatelessWidget {
  const _CommentOverflowButton({required this.comment});

  final PostComment comment;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: 'Comment actions',
      icon: const Icon(Icons.more_horiz, color: AppColors.textMuted),
      onPressed: () => _showCommentActions(context),
    );
  }

  Future<void> _showCommentActions(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
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
                Text('Comment actions', style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.sm),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.lgBorder,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ReportButton(
                        targetType: ReportTargetType.comment,
                        targetId: comment.id,
                        menuItem: true,
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      ReportButton(
                        targetType: ReportTargetType.user,
                        targetId: comment.userId,
                        menuItem: true,
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      BlockButton(targetUserId: comment.userId, menuItem: true),
                    ],
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
