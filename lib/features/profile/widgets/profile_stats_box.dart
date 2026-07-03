import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class ProfileStatsBox extends StatelessWidget {
  const ProfileStatsBox({super.key, required this.items});

  final List<ProfileStatItem> items;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.lgBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              Expanded(child: _ProfileStatCell(item: items[index])),
              if (index != items.length - 1)
                const SizedBox(
                  height: 48,
                  child: VerticalDivider(
                    width: AppSpacing.sm,
                    thickness: 1,
                    color: AppColors.border,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class ProfileStatItem {
  const ProfileStatItem({required this.value, required this.label, this.onTap});

  final int value;
  final String label;
  final VoidCallback? onTap;
}

class _ProfileStatCell extends StatelessWidget {
  const _ProfileStatCell({required this.item});

  final ProfileStatItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.mdBorder,
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _compactCount(item.value),
                  style: AppTextStyles.title.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                item.label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _compactCount(int value) {
  if (value >= 1000000) {
    final formatted = (value / 1000000).toStringAsFixed(
      value >= 10000000 ? 0 : 1,
    );
    return '${formatted.replaceAll('.0', '')}M';
  }
  if (value >= 1000) {
    final formatted = (value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1);
    return '${formatted.replaceAll('.0', '')}K';
  }
  return value.toString();
}
