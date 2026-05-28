import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/error_view.dart';
import 'events_models.dart';
import 'events_provider.dart';

class BusinessEventCheckInPage extends ConsumerWidget {
  const BusinessEventCheckInPage({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  final String eventId;
  final String eventTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participantsAsync = ref.watch(
      businessEventCheckInParticipantsProvider(eventId),
    );
    final state = ref.watch(businessEventCheckInControllerProvider(eventId));

    ref.listen<BusinessEventCheckInState>(
      businessEventCheckInControllerProvider(eventId),
      (previous, next) {
        final message = next.message;
        if (message == null || message == previous?.message) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Katılımcı kontrolü')),
      body: SafeArea(
        child: participantsAsync.when(
          loading: () => const AppLoader(),
          error: (error, _) => ErrorView(
            message: 'Katılımcılar yüklenemedi.',
            onRetry: () => ref.invalidate(
              businessEventCheckInParticipantsProvider(eventId),
            ),
          ),
          data: (participants) {
            if (participants.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Text('Onaylanmış katılımcı yok.'),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: participants.length + 1,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _Header(eventTitle: eventTitle);
                }

                final participant = participants[index - 1];
                return _ParticipantTile(
                  participant: participant,
                  isLoading: state.isLoading(participant.userId),
                  onCheckedIn: () => _mark(
                    ref,
                    participant,
                    EventParticipationStatus.checkedIn,
                  ),
                  onNoShow: () =>
                      _mark(ref, participant, EventParticipationStatus.noShow),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _mark(
    WidgetRef ref,
    BusinessEventCheckInParticipant participant,
    String attendanceStatus,
  ) async {
    await ref
        .read(businessEventCheckInControllerProvider(eventId).notifier)
        .markAttendance(
          participantUserId: participant.userId,
          attendanceStatus: attendanceStatus,
        );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.eventTitle});

  final String eventTitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eventTitle, style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Sadece onaylanmış işletme etkinliği katılımcıları listelenir.',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({
    required this.participant,
    required this.isLoading,
    required this.onCheckedIn,
    required this.onNoShow,
  });

  final BusinessEventCheckInParticipant participant;
  final bool isLoading;
  final VoidCallback onCheckedIn;
  final VoidCallback onNoShow;

  @override
  Widget build(BuildContext context) {
    final canMark = participant.canMarkAttendance && !isLoading;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.lgBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _Avatar(participant: participant),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        participant.displayName,
                        style: AppTextStyles.bodyStrong,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (participant.handleLabel != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          participant.handleLabel!,
                          style: AppTextStyles.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _StatusChip(label: participant.statusLabel),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canMark ? onCheckedIn : null,
                    icon: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: const Text('Geldi'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canMark ? onNoShow : null,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Gelmedi'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.participant});

  final BusinessEventCheckInParticipant participant;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = participant.avatarUrl;
    final trimmedName = participant.displayName.trim();
    final fallback = trimmedName.isEmpty
        ? '?'
        : trimmedName.substring(0, 1).toUpperCase();

    return CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.primarySoft,
      backgroundImage: avatarUrl == null || avatarUrl.trim().isEmpty
          ? null
          : NetworkImage(avatarUrl),
      child: avatarUrl == null || avatarUrl.trim().isEmpty
          ? Text(
              fallback,
              style: AppTextStyles.bodyStrong.copyWith(
                color: AppColors.primary,
              ),
            )
          : null,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
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
