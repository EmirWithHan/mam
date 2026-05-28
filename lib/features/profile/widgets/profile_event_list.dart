import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/sport_types.dart';
import '../../../core/widgets/event_cover_image.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/sport_icon.dart';
import '../profile_activity_models.dart';

class ProfileEventList extends StatelessWidget {
  const ProfileEventList({super.key, required this.events});

  final List<ProfileActivityEvent> events;

  @override
  Widget build(BuildContext context) {
    final activeEvents = events.where((event) => !event.isPast).toList();
    final pastEvents = events.where((event) => event.isPast).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Aktif Events'),
        const SizedBox(height: AppSpacing.md),
        _EventSectionList(
          events: activeEvents,
          emptyTitle: 'Aktif etkinlik yok.',
          emptyMessage: 'Yaklaşan veya devam eden etkinlikler burada görünür.',
        ),
        const SizedBox(height: AppSpacing.xl),
        const _SectionTitle('Geçmiş Events'),
        const SizedBox(height: AppSpacing.md),
        _EventSectionList(
          events: pastEvents,
          emptyTitle: 'Geçmiş event yok.',
          emptyMessage: 'Tamamlanan etkinlikler burada görünür.',
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppTextStyles.title);
  }
}

class _EventSectionList extends StatelessWidget {
  const _EventSectionList({
    required this.events,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final List<ProfileActivityEvent> events;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return EmptyState(
        title: emptyTitle,
        message: emptyMessage,
        icon: Icons.event_available_outlined,
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: events.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        return _ProfileEventTile(event: events[index]);
      },
    );
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EventCoverImage(
                  sportType: event.sportType,
                  height: 86,
                  borderRadius: AppRadius.md,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
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
                              _InfoChip(label: sportLabelFor(event.sportType)),
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
  const _InfoChip({required this.label, this.highlighted = false});

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
  const _MetaLine({required this.icon, required this.label});

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
