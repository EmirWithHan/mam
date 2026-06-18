import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_formatter.dart';
import '../trust_score_models.dart';

class TrustScoreLogTile extends StatelessWidget {
  const TrustScoreLogTile({super.key, required this.log});

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
                  Text(
                    _reasonLabel(log.reason, log.sourceType),
                    style: AppTextStyles.caption,
                  ),
                  if (log.sourceType != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Kaynak: ${_sourceLabel(log.sourceType!)}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    DateFormatter.dateTime(log.createdAt),
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _reasonLabel(String reason, String? sourceType) {
    if (sourceType == 'event_leave' && reason == 'event_leave') {
      return 'Onaylı etkinlikten ayrılma: güven puanı etkisi uygulandı.';
    }

    return switch (reason) {
      'event_leave' || 'leave_approved_event' =>
        'Onaylı etkinlikten ayrılma: güven puanı etkisi uygulandı.',
      _ => reason,
    };
  }

  String _sourceLabel(String sourceType) {
    return switch (sourceType) {
      'event_leave' => 'Etkinlikten ayrılma',
      _ => sourceType,
    };
  }
}
