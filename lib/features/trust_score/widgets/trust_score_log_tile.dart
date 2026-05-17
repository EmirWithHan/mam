import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../trust_score_models.dart';

class TrustScoreLogTile extends StatelessWidget {
  const TrustScoreLogTile({
    super.key,
    required this.log,
  });

  final TrustScoreLog log;

  @override
  Widget build(BuildContext context) {
    final deltaColor = log.isNegative ? AppColors.error : AppColors.success;

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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: deltaColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                log.isNegative ? Icons.trending_down : Icons.trending_up,
                color: deltaColor,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.formattedDelta,
                    style: AppTextStyles.title.copyWith(color: deltaColor),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${log.previousScore} -> ${log.newScore}',
                    style: AppTextStyles.bodyStrong,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(_reasonLabel(log.reason), style: AppTextStyles.caption),
                  if (log.sourceType != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Source: ${log.sourceType}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Text(_formatDate(log.createdAt), style: AppTextStyles.caption),
                ],
              ),
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

  String _reasonLabel(String reason) {
    return switch (reason) {
      'event_leave' || 'leave_approved_event' =>
        'Approved event left: trust score penalty applied.',
      _ => reason,
    };
  }
}
