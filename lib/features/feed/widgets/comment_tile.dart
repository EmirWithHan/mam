import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../feed_models.dart';

class CommentTile extends StatelessWidget {
  const CommentTile({
    super.key,
    required this.comment,
  });

  final PostComment comment;

  @override
  Widget build(BuildContext context) {
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
