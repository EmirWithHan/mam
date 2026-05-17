import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/error_view.dart';
import '../events_models.dart';

class EventParticipantsPreview extends StatelessWidget {
  const EventParticipantsPreview({
    super.key,
    required this.participants,
    required this.isLoading,
    this.errorMessage,
    this.onRetry,
  });

  final List<EventPublicParticipant> participants;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final visibleParticipants = _visibleParticipants(participants);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.xlBorder,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Katılımcılar', style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Bu etkinlikte kimlerin olduğunu gör.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.md),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: AppLoader(),
              )
            else if (errorMessage != null)
              ErrorView(message: errorMessage!, onRetry: onRetry)
            else if (visibleParticipants.isEmpty)
              Text('Katılımcı bilgisi yok.', style: AppTextStyles.bodySmall)
            else
              ...visibleParticipants.map(
                (participant) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _ParticipantTile(participant: participant),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<EventPublicParticipant> _visibleParticipants(
    List<EventPublicParticipant> participants,
  ) {
    final seenUserIds = <String>{};
    final visibleParticipants = <EventPublicParticipant>[];

    for (final participant in participants) {
      final isVisible = participant.isHost || participant.isActiveParticipant;
      if (!isVisible || !seenUserIds.add(participant.userId)) continue;
      visibleParticipants.add(participant);
    }

    return visibleParticipants;
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({required this.participant});

  final EventPublicParticipant participant;

  @override
  Widget build(BuildContext context) {
    final secondary = participant.handleLabel ?? participant.city;

    return InkWell(
      borderRadius: AppRadius.lgBorder,
      onTap: () => context.pushNamed(
        RouteNames.publicProfile,
        pathParameters: {'userId': participant.userId},
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            _ParticipantAvatar(participant: participant),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(participant.displayName, style: AppTextStyles.bodyStrong),
                  if (secondary != null && secondary.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(secondary, style: AppTextStyles.caption),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _RoleChip(label: participant.isHost ? 'Host' : 'Katılımcı'),
          ],
        ),
      ),
    );
  }
}

class _ParticipantAvatar extends StatelessWidget {
  const _ParticipantAvatar({required this.participant});

  final EventPublicParticipant participant;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = participant.avatarUrl?.trim();

    return CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.primarySoft,
      backgroundImage: avatarUrl == null || avatarUrl.isEmpty
          ? null
          : NetworkImage(avatarUrl),
      child: avatarUrl == null || avatarUrl.isEmpty
          ? Text(
              _initial(participant.displayName),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }

  String _initial(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'M';
    return trimmed.substring(0, 1).toUpperCase();
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: label == 'Host' ? AppColors.primary : AppColors.primarySoft,
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
            color: label == 'Host' ? AppColors.surface : AppColors.primary,
          ),
        ),
      ),
    );
  }
}
