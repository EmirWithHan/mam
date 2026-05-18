import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../notifications_models.dart';

class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.timeLabel,
    required this.onTap,
  });

  final AppNotification notification;
  final String timeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlighted = notification.isUnread;
    final body = notification.displayBody;

    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.lgBorder,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: highlighted ? AppColors.primarySoft : AppColors.surface,
            borderRadius: AppRadius.lgBorder,
            border: Border.all(
              color: highlighted ? AppColors.primarySoft : AppColors.border,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                if (highlighted) Container(width: 5, color: AppColors.primary),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: highlighted
                              ? AppColors.surface
                              : AppColors.background,
                          child: Icon(
                            _iconForType(notification.type),
                            color: highlighted
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notification.typeLabel,
                                style: AppTextStyles.label.copyWith(
                                  color: highlighted
                                      ? AppColors.primary
                                      : AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                notification.title,
                                style: AppTextStyles.bodyStrong,
                              ),
                              if (body.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Text(body, style: AppTextStyles.bodySmall),
                              ],
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                timeLabel,
                                style: AppTextStyles.caption.copyWith(
                                  color: highlighted
                                      ? AppColors.primary
                                      : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (notification.canOpenEntity) ...[
                          const SizedBox(width: AppSpacing.sm),
                          const Icon(
                            Icons.chevron_right,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type.trim().toLowerCase()) {
      case 'event_join_request':
        return Icons.person_add_alt_1;
      case 'event_join_approved':
        return Icons.check_circle_outline;
      case 'event_join_rejected':
        return Icons.cancel_outlined;
      case 'event_join_cancelled':
        return Icons.undo;
      case 'event_left':
        return Icons.logout;
      case 'follow':
        return Icons.person_add_alt_1;
      case 'system':
        return Icons.auto_awesome;
      default:
        return Icons.notifications_none_rounded;
    }
  }
}
