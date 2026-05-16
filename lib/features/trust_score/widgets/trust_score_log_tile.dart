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
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.lgBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
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
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(log.reason, style: AppTextStyles.caption),
            if (log.sourceType != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text('Source: ${log.sourceType}', style: AppTextStyles.caption),
            ],
            const SizedBox(height: AppSpacing.xs),
            Text(_formatDate(log.createdAt), style: AppTextStyles.caption),
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
