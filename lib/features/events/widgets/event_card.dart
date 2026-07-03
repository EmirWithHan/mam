import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/sport_types.dart';
import '../../../core/layout/responsive_layout.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/event_cover_image.dart';
import '../../../core/widgets/sport_icon.dart';
import '../../business/widgets/business_badge.dart';
import '../../profile/widgets/public_profile_preview_tile.dart';
import '../events_models.dart';
import 'event_share_sheet.dart';

class EventCard extends ConsumerWidget {
  const EventCard({super.key, required this.event, this.status});

  final Event event;
  final String? status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showSponsorChip = event.isActiveSponsoredPlacement(DateTime.now());
    final spotsLeft = event.safeCapacityTotal - event.safeApprovedCount;
    final spotsLabel = event.isPast || spotsLeft <= 0
        ? null
        : '$spotsLeft yer kaldi';

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.lgBorder,
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFFFF9F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.09),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(color: const Color(0xFFFFF0EA), width: 0.8),
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
            padding: AppResponsive.cardPadding(context),
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
                if (showSponsorChip || event.isPast || status != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      if (showSponsorChip)
                        _Pill(
                          label: 'Sponsorlu',
                          color: const Color(0xFFFF7E79),
                          textColor: Colors.white,
                        ),
                      if (status != null) ...[
                        if (_buildStatusPill(status!) != null)
                          _buildStatusPill(status!)!,
                      ] else if (event.isPast)
                        _Pill(
                          label: 'Gecmis',
                          color: AppColors.border,
                          textColor: AppColors.textMuted,
                        ),
                    ],
                  ),
                ],
                if (event.isBusinessEvent) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      BusinessBadge(
                        isVerified:
                            event.businessOrganizer?.isVerified ?? false,
                      ),
                      _Pill(
                        label: event.priceLabel,
                        color: AppColors.secondarySoft,
                        textColor: AppColors.secondary,
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stackActions = constraints.maxWidth < 330;
                    if (stackActions) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _OrganizerTile(event: event),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Expanded(
                                child: _OpenEventButton(
                                  eventId: event.id,
                                  fullWidth: true,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              IconButton(
                                icon: const Icon(
                                  Icons.share_outlined,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                tooltip: 'Paylaş',
                                onPressed: () {
                                  showModalBottomSheet<void>(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (_) =>
                                        EventShareSheet(event: event),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: _OrganizerTile(event: event)),
                        const SizedBox(width: AppSpacing.sm),
                        IconButton(
                          icon: const Icon(
                            Icons.share_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          tooltip: 'Paylaş',
                          onPressed: () {
                            showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => EventShareSheet(event: event),
                            );
                          },
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _OpenEventButton(eventId: event.id),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  Widget? _buildStatusPill(String status) {
    final now = DateTime.now();
    final isPast = event.eventDate.isBefore(now);

    if (isPast &&
        status != 'host' &&
        status != 'cancelled' &&
        status != 'rejected' &&
        status != 'no_show') {
      return const _Pill(
        label: 'Katıldın',
        color: AppColors.border,
        textColor: AppColors.textMuted,
      );
    }

    switch (status) {
      case 'host':
        return const _Pill(
          label: 'Organizatör',
          color: AppColors.primarySoft,
          textColor: AppColors.primary,
        );
      case 'pending':
        return const _Pill(
          label: 'İstek gönderildi',
          color: Color(0xFFFEF3C7),
          textColor: Color(0xFF92400E),
        );
      case 'pending_confirmation':
        return const _Pill(
          label: 'Beklemede',
          color: Color(0xFFFFEDD5),
          textColor: Color(0xFF9A3412),
        );
      case 'approved':
      case 'planned':
        return const _Pill(
          label: 'Onaylandı',
          color: Color(0xFFDCFCE7),
          textColor: Color(0xFF166534),
        );
      case 'confirmed':
        return const _Pill(
          label: 'Rezervasyon',
          color: Color(0xFFDBEAFE),
          textColor: Color(0xFF1E40AF),
        );
      case 'attended':
      case 'checked_in':
        return const _Pill(
          label: 'Katıldın',
          color: Color(0xFFCCFBF1),
          textColor: Color(0xFF0F766E),
        );
      case 'cancelled':
        return const _Pill(
          label: 'İptal edildi',
          color: Color(0xFFFEE2E2),
          textColor: Color(0xFF991B1B),
        );
      case 'rejected':
        return const _Pill(
          label: 'Reddedildi',
          color: Color(0xFFFEE2E2),
          textColor: Color(0xFF991B1B),
        );
      case 'waitlisted':
        return const _Pill(
          label: 'Yedek sıra',
          color: Color(0xFFF3E8FF),
          textColor: Color(0xFF6B21A8),
        );
      case 'no_show':
        return const _Pill(
          label: 'Katılmadı',
          color: Color(0xFFE5E7EB),
          textColor: Color(0xFF374151),
        );
      default:
        return null;
    }
  }
}

class _OrganizerTile extends StatelessWidget {
  const _OrganizerTile({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    return PublicProfilePreviewTile(
      userId: event.hostId,
      subtitle: _participantSummary,
      compact: true,
      enableNavigation: false,
    );
  }

  String get _participantSummary {
    if (event.safeApprovedCount <= 0) return 'İlk katılımcı ol';
    return '${event.safeApprovedCount} katılımcı - '
        '${event.safeCapacityTotal} kapasite';
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
  const _OpenEventButton({required this.eventId, this.fullWidth = false});

  final String eventId;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: 44,
        maxWidth: fullWidth ? double.infinity : 96,
      ),
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
          'Katıl',
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
