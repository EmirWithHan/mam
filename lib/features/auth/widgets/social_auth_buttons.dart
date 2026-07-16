import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';

class SocialAuthButtons extends StatelessWidget {
  const SocialAuthButtons({
    super.key,
    required this.isLoading,
    required this.onGooglePressed,
    this.onApplePressed,
    this.showAppleButton,
  });

  final bool isLoading;
  final VoidCallback onGooglePressed;
  final VoidCallback? onApplePressed;
  final bool? showAppleButton;

  @override
  Widget build(BuildContext context) {
    final shouldShowAppleButton = onApplePressed != null &&
        (showAppleButton ?? false);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SocialAuthIconButton(
          tooltip: 'Google ile devam et',
          icon: const _GoogleMark(),
          isLoading: isLoading,
          onPressed: isLoading ? null : onGooglePressed,
        ),
        if (shouldShowAppleButton) ...[
          const SizedBox(width: AppSpacing.sm),
          _SocialAuthIconButton(
            tooltip: 'Apple ile devam et',
            icon: const _AppleMark(),
            isLoading: isLoading,
            onPressed: isLoading ? null : onApplePressed,
          ),
        ],
      ],
    );
  }
}

class _SocialAuthIconButton extends StatelessWidget {
  const _SocialAuthIconButton({
    required this.tooltip,
    required this.icon,
    required this.isLoading,
    required this.onPressed,
  });

  final String tooltip;
  final Widget icon;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;

    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: SizedBox.square(
          dimension: 52,
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: disabled
                  ? AppColors.textMuted
                  : AppColors.textPrimary,
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
              padding: EdgeInsets.zero,
              minimumSize: const Size.square(52),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : icon,
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/auth/google_logo.png',
      width: 26,
      height: 26,
      fit: BoxFit.contain,
    );
  }
}

class _AppleMark extends StatelessWidget {
  const _AppleMark();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/auth/apple_logo.png',
      width: 26,
      height: 26,
      fit: BoxFit.contain,
    );
  }
}
