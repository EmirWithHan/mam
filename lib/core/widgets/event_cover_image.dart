import 'package:flutter/material.dart';

import '../constants/sport_types.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class EventCoverImage extends StatelessWidget {
  const EventCoverImage({
    super.key,
    required this.sportType,
    this.height = 128,
    this.borderRadius = AppRadius.lg,
    this.showLabel = true,
  });

  final String? sportType;
  final double height;
  final double borderRadius;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final style = eventCoverStyleForSport(sportType);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [style.startColor, style.endColor],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                right: -20,
                bottom: -28,
                child: Icon(
                  style.icon,
                  size: height * 0.95,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ),
              Positioned(
                left: AppSpacing.md,
                top: AppSpacing.md,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(style.icon, color: style.startColor, size: 25),
                ),
              ),
              if (showLabel)
                Positioned(
                  left: AppSpacing.md,
                  bottom: AppSpacing.md,
                  right: AppSpacing.md,
                  child: Row(
                    children: [
                      Flexible(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.textPrimary.withValues(
                              alpha: 0.46,
                            ),
                            borderRadius: AppRadius.pillBorder,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            child: Text(
                              style.label,
                              style: AppTextStyles.label.copyWith(
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
