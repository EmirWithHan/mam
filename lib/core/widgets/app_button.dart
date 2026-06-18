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
    final isPrimary = variant == AppButtonVariant.primary && !isDisabled;

    Widget button = FilledButton(
      onPressed: isDisabled ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: isPrimary
            ? Colors.transparent
            : _backgroundColor(isDisabled),
        shadowColor: Colors.transparent,
        foregroundColor: _foregroundColor(isDisabled),
        disabledBackgroundColor: _backgroundColor(true),
        disabledForegroundColor: _foregroundColor(true),
        minimumSize: const Size(0, 52),
        textStyle: AppTextStyles.button,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          side: isPrimary
              ? BorderSide.none
              : BorderSide(color: _borderColor(isDisabled)),
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

    if (isPrimary) {
      button = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.tertiary],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: button,
      );
    }

    if (!fullWidth) return SizedBox(height: 52, child: button);

    return SizedBox(width: double.infinity, height: 52, child: button);
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
