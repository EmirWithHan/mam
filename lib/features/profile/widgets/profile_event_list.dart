import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/sport_icon.dart';
import '../profile_activity_models.dart';

class ProfileEventList extends StatelessWidget {
  const ProfileEventList({
    super.key,
    required this.events,
  });

  final List<ProfileActivityEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(),
          SizedBox(height: AppSpacing.md),
          EmptyState(
            title: 'Henüz etkinliğin yok',
            message:
                'Oluşturduğun veya katıldığın etkinlikler burada görünecek.',
            icon: Icons.event_available_outlined,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle(),
        const SizedBox(height: AppSpacing.md),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: events.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            return _ProfileEventTile(event: events[index]);
          },
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle();

  @override
  Widget build(BuildContext context) {
    return Text('Eventlerim', style: AppTextStyles.title);
  }
}

class _ProfileEventTile extends StatelessWidget {
  const _ProfileEventTile({required this.event});

  final ProfileActivityEvent event;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.lgBorder,
        child: InkWell(
          borderRadius: AppRadius.lgBorder,
          onTap: () => context.pushNamed(
            RouteNames.eventDetail,
            pathParameters: {'eventId': event.id},
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SportIcon(sportType: event.sportType, size: 20),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.title, style: AppTextStyles.title),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          _InfoChip(label: event.sportType),
                          _InfoChip(label: event.roleLabel),
                          if (_statusLabel(event.attendanceStatus) != null)
                            _InfoChip(
                              label: _statusLabel(event.attendanceStatus)!,
                              highlighted: true,
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _MetaLine(
                        icon: Icons.place_outlined,
                        label: event.locationLabel,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      _MetaLine(
                        icon: Icons.schedule,
                        label: event.displayDate,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _statusLabel(String? status) {
    if (status == 'attended') return 'Onaylandı';
    if (status == 'planned') return 'Planlandı';
    if (status == 'pending') return 'Beklemede';
    return null;
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    this.highlighted = false,
  });

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: highlighted ? AppColors.primarySoft : AppColors.background,
        borderRadius: AppRadius.pillBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: highlighted ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.primary),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: Text(label, style: AppTextStyles.caption)),
      ],
    );
  }
}
