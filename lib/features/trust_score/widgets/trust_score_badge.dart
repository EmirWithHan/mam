import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../trust_score_models.dart';

class TrustScoreBadge extends StatelessWidget {
  const TrustScoreBadge({super.key, required this.score, this.compact = false});

  final int score;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final clampedScore = score.clamp(0, 100).toInt();
    final label = trustScoreLabel(clampedScore);
    final accentColor = _colorForScore(clampedScore);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: compact
            ? accentColor.withValues(alpha: 0.12)
            : AppColors.surface,
        border: Border.all(color: accentColor.withValues(alpha: 0.24)),
        borderRadius: compact ? AppRadius.pillBorder : AppRadius.lgBorder,
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
        child: compact
            ? Text(
                '$clampedScore - $label',
                style: AppTextStyles.label.copyWith(color: accentColor),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Trust score', style: AppTextStyles.label),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '$clampedScore',
                    style: AppTextStyles.headline.copyWith(color: accentColor),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(label, style: AppTextStyles.bodyStrong),
                ],
              ),
      ),
    );
  }

  Color _colorForScore(int score) {
    if (score <= 39) return AppColors.error;
    if (score <= 59) return AppColors.warning;
    if (score <= 79) return AppColors.primary;
    return AppColors.success;
  }
}
