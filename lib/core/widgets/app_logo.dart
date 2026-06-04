import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40, this.showText = false});

  final double size;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    final logo = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Image.asset(
        'assets/branding/mam_logo.jpg',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: AppRadius.smBorder,
            ),
            child: Text(
              'MaM',
              style: AppTextStyles.label.copyWith(color: AppColors.primary),
            ),
          );
        },
      ),
    );

    if (!showText) return logo;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        const SizedBox(width: AppSpacing.sm),
        Text('MaM', style: AppTextStyles.logo),
      ],
    );
  }
}
