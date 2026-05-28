import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/sport_types.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/event_cover_image.dart';
import '../../../core/widgets/sport_icon.dart';
import '../../profile/widgets/public_profile_preview_tile.dart';
import '../events_models.dart';

class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final spotsLeft = event.safeCapacityTotal - event.safeApprovedCount;
    final spotsLabel = event.isPast || spotsLeft <= 0
        ? null
        : '$spotsLeft yer kaldi';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgBorder,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.lgBorder,
        child: InkWell(
          borderRadius: AppRadius.lgBorder,
          onTap: event.id.trim().isEmpty
              ? null
              : () => context.pushNamed(
                    RouteNames.eventDetail,
                    pathParameters: {'eventId': event.id},
                  ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EventCoverImage(
                  sportType: event.sportType,
                  height: 138,
                  showLabel: false,
                  topLeftLabel: spotsLabel,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        event.titleLabel,
                        style: AppTextStyles.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _SportChip(sportType: event.sportType),
                  ],
                ),
                if (event.isSponsored || event.isPast) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      if (event.isSponsored)
                        _Pill(
                          label: 'Sponsorlu',
                          color: AppColors.primarySoft,
                          textColor: AppColors.primary,
                        ),
                      if (event.isPast)
                        _Pill(
                          label: 'Gecmis',
                          color: AppColors.border,
                          textColor: AppColors.textMuted,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                _MetaLine(
                  icon: Icons.schedule,
                  label: _formatDateTime(event.eventDate),
                ),
                const SizedBox(height: AppSpacing.xs),
                _MetaLine(
                  icon: Icons.place_outlined,
                  label: event.locationLabel,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: PublicProfilePreviewTile(
                        userId: event.hostId,
                        subtitle: _participantSummary,
                        compact: true,
                        enableNavigation: false,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _OpenEventButton(eventId: event.id),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _participantSummary {
    if (event.safeApprovedCount <= 0) return 'Ilk katilimci ol';
    return '${event.safeApprovedCount} katilimci - '
        '${event.safeCapacityTotal} kapasite';
  }

  String _formatDateTime(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }
}

class _SportChip extends StatelessWidget {
  const _SportChip({required this.sportType});

  final String? sportType;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 132),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
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
              SportIcon(sportType: sportType, size: 15, filled: false),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  sportLabelFor(sportType),
                  style: AppTextStyles.label.copyWith(color: AppColors.primary),
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

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.primary),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _OpenEventButton extends StatelessWidget {
  const _OpenEventButton({required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44, maxWidth: 96),
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surface,
          minimumSize: const Size(0, 44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
        onPressed: eventId.trim().isEmpty
            ? null
            : () => context.pushNamed(
                  RouteNames.eventDetail,
                  pathParameters: {'eventId': eventId},
                ),
        child: const Text(
          'Katil',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadius.pillBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(color: textColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
