import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class SocialAuthButtons extends StatelessWidget {
  const SocialAuthButtons({
    super.key,
    required this.isLoading,
    required this.onGooglePressed,
    required this.onFacebookPressed,
    required this.onApplePressed,
  });

  final bool isLoading;
  final VoidCallback onGooglePressed;
  final VoidCallback onFacebookPressed;
  final VoidCallback onApplePressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SocialIconButton(
          tooltip: 'Google ile devam et',
          label: 'G',
          isLoading: isLoading,
          onPressed: isLoading ? null : onGooglePressed,
        ),
        const SizedBox(width: AppSpacing.md),
        _SocialIconButton(
          tooltip: 'Facebook ile devam et',
          label: 'f',
          labelStyle: AppTextStyles.title.copyWith(
            color: const Color(0xFF1877F2),
            fontWeight: FontWeight.w900,
          ),
          isLoading: isLoading,
          onPressed: isLoading ? null : onFacebookPressed,
        ),
        const SizedBox(width: AppSpacing.md),
        _SocialIconButton(
          tooltip: 'Apple ile devam et yakında',
          icon: Icons.apple,
          isDisabled: true,
          badgeLabel: 'Yakında',
          onPressed: isLoading ? null : onApplePressed,
        ),
      ],
    );
  }
}

class _SocialIconButton extends StatelessWidget {
  const _SocialIconButton({
    required this.tooltip,
    this.label,
    this.labelStyle,
    this.icon,
    this.isLoading = false,
    this.isDisabled = false,
    this.badgeLabel,
    required this.onPressed,
  });

  final String tooltip;
  final String? label;
  final TextStyle? labelStyle;
  final IconData? icon;
  final bool isLoading;
  final bool isDisabled;
  final String? badgeLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final disabled = isDisabled || onPressed == null || isLoading;

    return Tooltip(
      message: tooltip,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: disabled
                ? AppColors.border.withValues(alpha: 0.35)
                : AppColors.surface,
            shape: const CircleBorder(
              side: BorderSide(color: AppColors.border),
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox.square(
                dimension: 52,
                child: Center(
                  child: isLoading && !isDisabled
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : icon == null
                      ? Text(
                          label ?? '',
                          style:
                              labelStyle ??
                              AppTextStyles.title.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        )
                      : Icon(
                          icon,
                          color: disabled
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                        ),
                ),
              ),
            ),
          ),
          if (badgeLabel != null)
            Positioned(
              right: -12,
              bottom: -6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: AppRadius.pillBorder,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 2,
                  ),
                  child: Text(
                    badgeLabel!,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
