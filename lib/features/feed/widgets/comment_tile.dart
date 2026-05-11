import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
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
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_shortUserId(comment.userId), style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.xs),
            Text(comment.comment, style: AppTextStyles.body),
            const SizedBox(height: AppSpacing.xs),
            Text(_formatDate(comment.createdAt), style: AppTextStyles.caption),
            if (!isMine) ...[
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                children: [
                  ReportButton(
                    targetType: ReportTargetType.comment,
                    targetId: comment.id,
                    compact: true,
                  ),
                  ReportButton(
                    targetType: ReportTargetType.user,
                    targetId: comment.userId,
                    compact: true,
                  ),
                  BlockButton(
                    targetUserId: comment.userId,
                    compact: true,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _shortUserId(String userId) {
    if (userId.length <= 8) return userId;
    return 'User ${userId.substring(0, 8)}';
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
