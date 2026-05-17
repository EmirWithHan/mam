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

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight = constraints.hasBoundedHeight;
        final isCompact = hasBoundedHeight && constraints.maxHeight < 280;
        final outerPadding = isCompact ? AppSpacing.sm : AppSpacing.lg;
        final innerPadding = isCompact ? AppSpacing.md : AppSpacing.lg;
        final iconSize = isCompact ? 40.0 : 52.0;
        final sectionGap = isCompact ? AppSpacing.sm : AppSpacing.md;
        final actionGap = isCompact ? AppSpacing.md : AppSpacing.lg;

        final content = Center(
          child: Padding(
            padding: EdgeInsets.all(outerPadding),
            child: _EmptyStateCard(
              title: title,
              message: message,
              actionLabel: actionLabel,
              onAction: onAction,
              icon: icon,
              secondaryActionLabel: secondaryActionLabel,
              onSecondaryAction: onSecondaryAction,
              hasPrimaryAction: hasPrimaryAction,
              hasSecondaryAction: hasSecondaryAction,
              innerPadding: innerPadding,
              iconSize: iconSize,
              sectionGap: sectionGap,
              actionGap: actionGap,
            ),
          ),
        );

        if (!hasBoundedHeight) return content;

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: content,
          ),
        );
      },
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.icon,
    required this.secondaryActionLabel,
    required this.onSecondaryAction,
    required this.hasPrimaryAction,
    required this.hasSecondaryAction,
    required this.innerPadding,
    required this.iconSize,
    required this.sectionGap,
    required this.actionGap,
  });

  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final bool hasPrimaryAction;
  final bool hasSecondaryAction;
  final double innerPadding;
  final double iconSize;
  final double sectionGap;
  final double actionGap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
        padding: EdgeInsets.all(innerPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon ?? Icons.sports_handball,
                color: AppColors.primary,
                size: iconSize * 0.48,
              ),
            ),
            SizedBox(height: sectionGap),
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
              SizedBox(height: actionGap),
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
    );
  }
}
