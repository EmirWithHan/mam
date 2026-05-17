import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

enum AppButtonVariant { primary, secondary, outlined }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.variant = AppButtonVariant.primary,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonVariant variant;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || isLoading;

    final button = FilledButton(
      onPressed: isDisabled ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: _backgroundColor(isDisabled),
        foregroundColor: _foregroundColor(isDisabled),
        disabledBackgroundColor: _backgroundColor(true),
        disabledForegroundColor: _foregroundColor(true),
        minimumSize: const Size(0, 52),
        textStyle: AppTextStyles.button,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          side: BorderSide(color: _borderColor(isDisabled)),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),
      child: isLoading
          ? SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _foregroundColor(false),
              ),
            )
          : Text(label),
    );

    if (!fullWidth) return button;

    return SizedBox(width: double.infinity, child: button);
  }

  Color _backgroundColor(bool isDisabled) {
    if (isDisabled) return AppColors.border;
    switch (variant) {
      case AppButtonVariant.primary:
        return AppColors.primary;
      case AppButtonVariant.secondary:
        return AppColors.primarySoft;
      case AppButtonVariant.outlined:
        return Colors.transparent;
    }
  }

  Color _foregroundColor(bool isDisabled) {
    if (isDisabled) return AppColors.textMuted;
    switch (variant) {
      case AppButtonVariant.primary:
        return Colors.white;
      case AppButtonVariant.secondary:
      case AppButtonVariant.outlined:
        return AppColors.primary;
    }
  }

  Color _borderColor(bool isDisabled) {
    if (isDisabled) return AppColors.border;
    return variant == AppButtonVariant.primary
        ? AppColors.primary
        : AppColors.primary.withValues(alpha: 0.36);
  }
}
