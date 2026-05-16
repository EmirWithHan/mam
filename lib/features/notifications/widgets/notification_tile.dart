import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.title,
    required this.timeLabel,
    this.message,
    this.type,
    this.avatarUrl,
    this.icon,
    this.highlighted = false,
  });

  final String title;
  final String timeLabel;
  final String? message;
  final String? type;
  final String? avatarUrl;
  final IconData? icon;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final imageUrl = avatarUrl?.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
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
      child: ClipRRect(
        borderRadius: AppRadius.lgBorder,
        child: IntrinsicHeight(
          child: Row(
            children: [
              if (highlighted)
                Container(width: 5, color: AppColors.primary),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: highlighted
                            ? AppColors.primarySoft
                            : AppColors.background,
                        backgroundImage:
                            imageUrl == null || imageUrl.isEmpty
                                ? null
                                : NetworkImage(imageUrl),
                        child: imageUrl == null || imageUrl.isEmpty
                            ? Icon(
                                icon ?? Icons.notifications_none_rounded,
                                color: AppColors.primary,
                                size: 22,
                              )
                            : null,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (type != null && type!.trim().isNotEmpty) ...[
                              Text(
                                type!,
                                style: AppTextStyles.label.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                            ],
                            Text(title, style: AppTextStyles.bodyStrong),
                            if (message != null &&
                                message!.trim().isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(message!, style: AppTextStyles.bodySmall),
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
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
