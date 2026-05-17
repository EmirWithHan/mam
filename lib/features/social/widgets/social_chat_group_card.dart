import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/sport_icon.dart';
import '../../chat/event_chat_list_models.dart';

class SocialChatGroupCard extends StatelessWidget {
  const SocialChatGroupCard({
    super.key,
    required this.group,
    required this.onTap,
  });

  final EventChatGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.xlBorder,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.xlBorder,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                SportIcon(sportType: group.sportType, size: 24),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              group.title,
                              style: AppTextStyles.bodyStrong,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(group.dateLabel, style: AppTextStyles.caption),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        group.displaySubtitle,
                        style: AppTextStyles.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          _Chip(label: group.sportType),
                          _Chip(label: group.isHost ? 'Host' : 'Participant'),
                          if (group.isArchived) const _Chip(label: 'Archived'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: AppRadius.pillBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(color: AppColors.primary),
        ),
      ),
    );
  }
}
