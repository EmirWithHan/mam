import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../business_models.dart';

class BusinessBadge extends StatelessWidget {
  const BusinessBadge({super.key, required this.isVerified});

  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 168),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isVerified ? AppColors.primary : AppColors.primarySoft,
          borderRadius: AppRadius.pillBorder,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isVerified ? Icons.verified_rounded : Icons.storefront_outlined,
                size: 15,
                color: isVerified ? Colors.white : AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  BusinessBadgeLabels.forVerified(isVerified),
                  style: AppTextStyles.label.copyWith(
                    color: isVerified ? Colors.white : AppColors.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
