import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_button.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final hasPrimaryAction = actionLabel != null && onAction != null;
    final hasSecondaryAction =
        secondaryActionLabel != null && onSecondaryAction != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: AppRadius.lgBorder,
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon ?? Icons.sports_handball,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  title,
                  style: AppTextStyles.title,
                  textAlign: TextAlign.center,
                ),
                if (message != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    message!,
                    style: AppTextStyles.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
                if (hasPrimaryAction) ...[
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(label: actionLabel!, onPressed: onAction),
                ],
                if (hasSecondaryAction) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: secondaryActionLabel!,
                    variant: AppButtonVariant.secondary,
                    onPressed: onSecondaryAction,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
