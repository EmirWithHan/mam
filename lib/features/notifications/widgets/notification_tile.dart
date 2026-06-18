import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../profile/widgets/public_profile_avatar.dart';
import '../notifications_models.dart';

class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.timeLabel,
    required this.onTap,
    this.isBusy = false,
    this.onApprove,
    this.onReject,
  });

  final AppNotification notification;
  final String timeLabel;
  final VoidCallback onTap;
  final bool isBusy;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final highlighted = notification.isUnread;
    final body = notification.displayBody;
    final accentColor = _accentColor(notification.type);
    final hasActor =
        notification.actorId != null && notification.actorId!.isNotEmpty;

    return InkWell(
      onTap: isBusy ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, // 16px
          vertical: AppSpacing.sm, // 12px
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar Section
            if (hasActor)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  PublicProfileAvatar(
                    userId: notification.actorId,
                    radius: 22, // 44px diameter
                    enableNavigation: false,
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 8,
                        backgroundColor: accentColor,
                        child: Icon(
                          _iconForType(notification.type),
                          color: Colors.white,
                          size: 9,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              CircleAvatar(
                radius: 22,
                backgroundColor: accentColor.withValues(alpha: 0.1),
                child: Icon(
                  _iconForType(notification.type),
                  color: accentColor,
                  size: 20,
                ),
              ),
            const SizedBox(width: AppSpacing.md),

            // Content Area
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  RichText(
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                      children: [
                        TextSpan(
                          text: notification.displayTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (body.isNotEmpty) ...[
                          const TextSpan(text: ' '),
                          TextSpan(
                            text: body,
                            style: TextStyle(
                              color: highlighted
                                  ? AppColors.textSecondary
                                  : AppColors.textMuted,
                            ),
                          ),
                        ],
                        const TextSpan(text: '  '),
                        TextSpan(
                          text: timeLabel,
                          style: AppTextStyles.caption.copyWith(
                            color: highlighted
                                ? AppColors.primary
                                : AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Actions if pending follow request
                  if (notification.canRespondToFollowRequest) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        SizedBox(
                          height: 32,
                          child: ElevatedButton(
                            onPressed: isBusy ? null : onApprove,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: AppRadius.mdBorder,
                              ),
                            ),
                            child: isBusy
                                ? const SizedBox.square(
                                    dimension: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Onayla',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        SizedBox(
                          height: 32,
                          child: OutlinedButton(
                            onPressed: isBusy ? null : onReject,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              side: const BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: AppRadius.mdBorder,
                              ),
                            ),
                            child: const Text(
                              'Reddet',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Actions if business confirmation is required
                  if (notification.isBusinessEventConfirmRequired) ...[
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      height: 32,
                      child: ElevatedButton(
                        onPressed: isBusy ? null : onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.mdBorder,
                          ),
                        ),
                        child: const Text(
                          'Katılımı Doğrula',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            if (highlighted) ...[
              const SizedBox(width: AppSpacing.sm),
              const CircleAvatar(radius: 4, backgroundColor: AppColors.primary),
            ],
          ],
        ),
      ),
    );
  }
}

Color _accentColor(String type) {
  return switch (type.trim().toLowerCase()) {
    'business_event_confirm_required' => AppColors.success,
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
    'business_event_confirm_required' => Icons.verified_user_outlined,
    'event_join_approved' => Icons.check_circle_outline,
    'event_join_rejected' => Icons.cancel_outlined,
    'event_join_cancelled' => Icons.remove_circle_outline,
    'event_left' => Icons.logout,
    'follow' => Icons.person_add_alt_1,
    'follow_request' => Icons.person_add_alt_1,
    'follow_request_approved' => Icons.check_circle_outline,
    'follow_request_rejected' => Icons.cancel_outlined,
    'system' => Icons.auto_awesome,
    _ => Icons.notifications_none_rounded,
  };
}
