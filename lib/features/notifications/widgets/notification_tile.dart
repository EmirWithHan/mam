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
    this.isBusy = false,
  });

  final AppNotification notification;
  final String timeLabel;
  final VoidCallback onTap;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final highlighted = notification.isUnread;
    final body = notification.displayBody;
    final accentColor = _accentColor(notification.type);

    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.lgBorder,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isBusy ? null : onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: highlighted ? AppColors.surface : AppColors.surfaceSoft,
            borderRadius: AppRadius.lgBorder,
            border: Border.all(
              color: highlighted
                  ? AppColors.primary.withValues(alpha: 0.7)
                  : AppColors.border,
            ),
            boxShadow: highlighted
                ? [
                    BoxShadow(
                      color: AppColors.textPrimary.withValues(alpha: 0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: highlighted ? 5 : 0,
                  color: AppColors.primary,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _NotificationIcon(
                          type: notification.type,
                          accentColor: accentColor,
                          highlighted: highlighted,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      notification.typeLabel,
                                      style: AppTextStyles.label.copyWith(
                                        color: highlighted
                                            ? accentColor
                                            : AppColors.textMuted,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (highlighted) ...[
                                    const SizedBox(width: AppSpacing.sm),
                                    const _UnreadDot(),
                                  ],
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                notification.displayTitle,
                                style: AppTextStyles.bodyStrong.copyWith(
                                  color: highlighted
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (body.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  body,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: highlighted
                                        ? AppColors.textSecondary
                                        : AppColors.textMuted,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                timeLabel,
                                style: AppTextStyles.caption.copyWith(
                                  color: highlighted
                                      ? AppColors.primary
                                      : AppColors.textMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
}

class _NotificationIcon extends StatelessWidget {
  const _NotificationIcon({
    required this.type,
    required this.accentColor,
    required this.highlighted,
  });

  final String type;
  final Color accentColor;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: highlighted ? AppColors.primarySoft : AppColors.surface,
      child: Icon(_iconForType(type), color: accentColor, size: 22),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: SizedBox.square(dimension: 8),
    );
  }
}

Color _accentColor(String type) {
  return switch (type.trim().toLowerCase()) {
    'event_join_approved' => AppColors.success,
    'event_join_rejected' => AppColors.error,
    'event_join_cancelled' => AppColors.warning,
    'event_left' => AppColors.warning,
    _ => AppColors.primary,
  };
}

IconData _iconForType(String type) {
  return switch (type.trim().toLowerCase()) {
    'event_join_request' => Icons.person_add_alt_1,
    'event_join_approved' => Icons.check_circle_outline,
    'event_join_rejected' => Icons.cancel_outlined,
    'event_join_cancelled' => Icons.remove_circle_outline,
    'event_left' => Icons.logout,
    'follow' => Icons.person_add_alt_1,
    'system' => Icons.auto_awesome,
    _ => Icons.notifications_none_rounded,
  };
}
