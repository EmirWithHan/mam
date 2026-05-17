import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/error_view.dart';
import '../../services/maps_service.dart';
import '../auth/auth_provider.dart';
import '../chat/event_chat_list_provider.dart';
import '../chat/event_chat_provider.dart';
import '../profile/public_profile_provider.dart';
import '../profile/profile_provider.dart';
import '../profile/widgets/public_profile_avatar.dart';
import '../reports/reports_models.dart';
import '../reports/widgets/block_button.dart';
import '../reports/widgets/report_button.dart';
import 'events_models.dart';
import 'events_provider.dart';
import 'widgets/event_call_button.dart';
import 'join_requests_provider.dart';
import 'widgets/host_join_request_tile.dart';
import 'widgets/join_request_button.dart';

class EventDetailPage extends ConsumerStatefulWidget {
  const EventDetailPage({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends ConsumerState<EventDetailPage> {
  String? _loadedEventId;
  bool? _loadedForHost;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(profileControllerProvider.notifier).loadMyProfile();
    });
  }

  void _loadJoinState(Event event, bool isHost) {
    if (_loadedEventId == event.id && _loadedForHost == isHost) return;

    _loadedEventId = event.id;
    _loadedForHost = isHost;
    Future.microtask(() {
      final controller = ref.read(
        joinRequestControllerProvider(event.id).notifier,
      );
      if (isHost) {
        controller.loadHostRequests();
      } else {
        controller.loadMyRequest();
      }
    });
  }

  Future<void> _refreshEvent(Event event) async {
    ref.invalidate(eventDetailProvider(event.id));
    await ref.read(eventsControllerProvider.notifier).refreshEvents();
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventDetailProvider(widget.eventId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => _goBack(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const AppLogo(size: 32, showText: true),
      ),
      body: SafeArea(
        child: eventAsync.when(
          loading: () => const AppLoader(),
          error: (error, _) => ErrorView(message: '$error'),
          data: (event) {
            final authState = ref.watch(authControllerProvider);
            final isHost = event.isHost(authState.userId);
            _loadJoinState(event, isHost);

            return _EventDetailBody(
              event: event,
              isHost: isHost,
              onRefreshEvent: () => _refreshEvent(event),
            );
          },
        ),
      ),
    );
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.goNamed(RouteNames.events);
  }
}

class _EventDetailBody extends ConsumerWidget {
  const _EventDetailBody({
    required this.event,
    required this.isHost,
    required this.onRefreshEvent,
  });

  final Event event;
  final bool isHost;
  final Future<void> Function() onRefreshEvent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileControllerProvider);
    final requestState = ref.watch(joinRequestControllerProvider(event.id));
    final attendanceStatusAsync = ref.watch(
      eventAttendanceStatusProvider(event.id),
    );
    final attendanceStatus = attendanceStatusAsync.valueOrNull;
    final hasAttendanceStatus = attendanceStatusAsync.hasValue;
    final hasLeftEvent =
        EventParticipationStatus.hasLeftEvent(attendanceStatus);
    final isApprovedByAttendance =
        EventParticipationStatus.isApprovedParticipant(attendanceStatus);
    final isApprovedParticipant = !hasLeftEvent &&
        (hasAttendanceStatus
            ? isApprovedByAttendance
            : requestState.myRequest?.isApproved == true);
    final requestController = ref.read(
      joinRequestControllerProvider(event.id).notifier,
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _EventHeroCard(event: event, isHost: isHost),
        const SizedBox(height: AppSpacing.lg),
        const _SectionTitle(title: 'Host'),
        const SizedBox(height: AppSpacing.sm),
        _HostPreviewCard(hostId: event.hostId),
        const SizedBox(height: AppSpacing.lg),
        const _SectionTitle(title: 'Event info'),
        const SizedBox(height: AppSpacing.sm),
        _DetailCard(
          children: [
            _InfoBlock(
              label: 'Description',
              value: event.descriptionLabel,
              muted: !event.hasDescription,
            ),
            const SizedBox(height: AppSpacing.md),
            _AreaTile(event: event),
            const SizedBox(height: AppSpacing.md),
            _LocationCard(event: event),
            const SizedBox(height: AppSpacing.md),
            _InfoTile(
              label: 'Date',
              value: DateFormatter.turkishEventDateTime(event.eventDate),
              icon: Icons.calendar_today_outlined,
            ),
            const SizedBox(height: AppSpacing.md),
            _InfoTile(
              label: 'Capacity',
              value: event.formattedCapacityLabel,
              icon: Icons.groups_outlined,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const _SectionTitle(title: 'Actions'),
        const SizedBox(height: AppSpacing.sm),
        if (isHost || isApprovedParticipant) ...[
          AppButton(
            label: 'Open chat',
            onPressed: () => context.pushNamed(
              RouteNames.eventChat,
              pathParameters: {'eventId': event.id},
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (!isHost && isApprovedParticipant) ...[
          EventCallButton(
            eventId: event.id,
            targetUserId: event.hostId,
            label: 'Call host',
          ),
          const SizedBox(height: AppSpacing.sm),
          _LeaveApprovedEventButton(
            onPressed: () => _confirmLeaveApprovedEvent(
              context,
              ref,
              requestController,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (isHost)
          _HostRequestsSection(
            eventId: event.id,
            state: requestState,
            onApprove: (requestId) async {
              await requestController.approveRequest(requestId);
              await onRefreshEvent();
            },
            onReject: (requestId) async {
              await requestController.rejectRequest(requestId);
              await onRefreshEvent();
            },
          )
        else
          JoinRequestButton(
            event: event,
            profileState: profileState,
            request: requestState.myRequest,
            isLoading: requestState.loading || profileState.isLoading,
            hasLeftEvent: hasLeftEvent,
            onRequest: () async {
              final requested = await ref
                  .read(eventsControllerProvider.notifier)
                  .requestToJoinEvent(event.id);
              if (!requested) {
                if (!context.mounted) return;
                final message = ref.read(eventsControllerProvider).message;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message ?? 'Could not request to join.'),
                  ),
                );
                return;
              }
              await requestController.loadMyRequest();
              await onRefreshEvent();
            },
            onCancel: () async {
              final request = requestState.myRequest;
              if (request == null) return;
              await requestController.cancelPendingRequest(request.id);
              await requestController.loadMyRequest();
              await onRefreshEvent();
            },
          ),
        if (requestState.message != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            requestState.message!,
            style: const TextStyle(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Future<void> _confirmLeaveApprovedEvent(
    BuildContext context,
    WidgetRef ref,
    JoinRequestController requestController,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Etkinlikten çıkılsın mı?'),
          content: const Text(
            'Bu etkinlikten çıkarsan katılımın iptal edilir ve trust score’un 5 puan düşer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgeç'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Etkinlikten çık'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    final left = await ref
        .read(eventsControllerProvider.notifier)
        .leaveApprovedEvent(event.id);
    ref.invalidate(eventAttendanceStatusProvider(event.id));
    ref.invalidate(eventDetailProvider(event.id));
    ref.invalidate(eventChatControllerProvider(event.id));
    ref.invalidate(eventChatListControllerProvider);
    await requestController.loadMyRequest();
    if (!context.mounted) return;

    if (left) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Etkinlikten çıkıldı. Trust score 5 puan düştü.'),
        ),
      );
      return;
    }

    final message = ref.read(eventsControllerProvider).message;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message ?? 'Etkinlikten çıkılamadı.')),
    );
  }
}

class _LeaveApprovedEventButton extends StatelessWidget {
  const _LeaveApprovedEventButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.error,
        side: const BorderSide(color: AppColors.error),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.logout_rounded),
      label: const Text('Etkinlikten çık'),
    );
  }
}

class _HostRequestsSection extends StatelessWidget {
  const _HostRequestsSection({
    required this.eventId,
    required this.state,
    required this.onApprove,
    required this.onReject,
  });

  final String eventId;
  final JoinRequestsState state;
  final Future<void> Function(String requestId) onApprove;
  final Future<void> Function(String requestId) onReject;

  @override
  Widget build(BuildContext context) {
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
            Text('You are the host', style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Review requests and keep your squad moving.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.md),
            if (state.loading && state.hostRequests.isEmpty)
              const AppLoader()
            else if (state.hostRequests.isEmpty)
              Text('No join requests yet.', style: AppTextStyles.body)
            else
              ...state.hostRequests.map(
                (request) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HostJoinRequestTile(
                      request: request,
                      isLoading: state.loading,
                      onApprove: () => onApprove(request.id),
                      onReject: () => onReject(request.id),
                    ),
                    if (request.isApproved) ...[
                      const SizedBox(height: AppSpacing.xs),
                      EventCallButton(
                        eventId: eventId,
                        targetUserId: request.userId,
                        label: 'Call participant',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EventHeroCard extends StatelessWidget {
  const _EventHeroCard({required this.event, required this.isHost});

  final Event event;
  final bool isHost;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.xlBorder,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(event.title, style: AppTextStyles.headline)),
                if (event.isSponsored)
                  _MiniChip(
                    label: 'Sponsored',
                    color: AppColors.tertiarySoft,
                    textColor: AppColors.warning,
                  ),
                const SizedBox(width: AppSpacing.xs),
                _EventOverflowButton(event: event, isHost: isHost),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _MiniChip(
                  label: event.sportType,
                  color: AppColors.primary,
                  textColor: Colors.white,
                  icon: Icons.sports_soccer,
                ),
                _MiniChip(
                  label: event.capacityLabel,
                  color: AppColors.primarySoft,
                  textColor: AppColors.primary,
                  icon: Icons.groups_outlined,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _DetailLine(label: 'Where', value: event.locationLabel),
            _DetailLine(label: 'When', value: _formatDateTime(event.eventDate)),
          ],
        ),
      ),
    );
  }
}

class _EventOverflowButton extends ConsumerWidget {
  const _EventOverflowButton({
    required this.event,
    required this.isHost,
  });

  final Event event;
  final bool isHost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: 'Event actions',
      icon: const Icon(Icons.more_horiz, color: AppColors.textMuted),
      onPressed: () => _showEventActions(context, ref),
    );
  }

  Future<void> _showEventActions(BuildContext context, WidgetRef ref) {
    final rootContext = context;

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: AppRadius.pillBorder,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Event actions', style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.sm),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.lgBorder,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: isHost
                        ? [
                            _EventDeleteMenuItem(
                              onTap: () {
                                Navigator.of(sheetContext).pop();
                                _confirmDeleteEvent(rootContext, ref);
                              },
                            ),
                          ]
                        : [
                            ReportButton(
                              targetType: ReportTargetType.event,
                              targetId: event.id,
                              menuItem: true,
                            ),
                            const Divider(height: 1, color: AppColors.border),
                            ReportButton(
                              targetType: ReportTargetType.user,
                              targetId: event.hostId,
                              menuItem: true,
                            ),
                            const Divider(height: 1, color: AppColors.border),
                            BlockButton(
                              targetUserId: event.hostId,
                              menuItem: true,
                            ),
                          ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteEvent(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete event?'),
          content: const Text(
            'This event will be removed. Event chat and join requests will also be removed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    final deleted = await ref.read(eventsControllerProvider.notifier).deleteEvent(
          event.id,
        );
    ref.invalidate(eventDetailProvider(event.id));
    if (!context.mounted) return;

    if (deleted) {
      final messenger = ScaffoldMessenger.of(context);
      context.goNamed(RouteNames.events);
      messenger.showSnackBar(const SnackBar(content: Text('Event deleted.')));
      return;
    }

    final message = ref.read(eventsControllerProvider).message;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message ?? 'Could not delete event.')),
    );
  }
}

class _EventDeleteMenuItem extends StatelessWidget {
  const _EventDeleteMenuItem({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.delete_outline, color: AppColors.error),
      title: Text(
        'Delete event',
        style: AppTextStyles.bodyStrong.copyWith(color: AppColors.error),
      ),
      onTap: onTap,
    );
  }
}

class _HostPreviewCard extends ConsumerWidget {
  const _HostPreviewCard({required this.hostId});

  final String hostId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfile = ref.watch(publicProfilePreviewProvider(hostId));

    return asyncProfile.maybeWhen(
      data: (profile) {
        final secondaryText = profile?.usernameTag ?? profile?.city ?? 'Host';
        final trustScore = profile?.trustScore;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: AppRadius.lgBorder,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                PublicProfileAvatar(profile: profile, radius: 24),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?.displayName ?? 'MaM User',
                        style: AppTextStyles.bodyStrong,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(secondaryText, style: AppTextStyles.caption),
                    ],
                  ),
                ),
                if (trustScore != null)
                  DecoratedBox(
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
                        '$trustScore trust',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
      orElse: () => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: AppRadius.lgBorder,
        ),
        child: const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              PublicProfileAvatar(radius: 24),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text('MaM User', style: AppTextStyles.bodyStrong),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppTextStyles.title);
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.label,
    required this.value,
    this.muted = false,
  });

  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoLabel(label),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: AppTextStyles.body.copyWith(
            color: muted ? AppColors.textMuted : AppColors.textPrimary,
            fontWeight: muted ? FontWeight.w500 : FontWeight.w700,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _AreaTile extends StatelessWidget {
  const _AreaTile({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    return _InfoTile(
      label: 'Area',
      value: event.locationLabel,
      icon: Icons.place_outlined,
      highlighted: true,
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
    this.highlighted = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.primarySoft.withValues(alpha: 0.58)
            : AppColors.background,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoLabel(label),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    value,
                    style: AppTextStyles.bodyStrong.copyWith(height: 1.25),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoLabel extends StatelessWidget {
  const _InfoLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.label.copyWith(
        color: AppColors.textMuted,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    if (!event.hasLocation) {
      return const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.sm),
        child: _DetailLine(
          label: 'Location',
          value: 'Konum bilgisi eklenmemiş.',
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: AppColors.background,
        borderRadius: AppRadius.lgBorder,
        child: InkWell(
          borderRadius: AppRadius.lgBorder,
          onTap: () => _openMaps(context),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.map_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _InfoLabel('Location'),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        event.locationDisplayLabel,
                        style: AppTextStyles.bodyStrong,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Haritada aç',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(Icons.open_in_new, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openMaps(BuildContext context) async {
    try {
      await const MapsService().openEventLocation(
        latitude: event.locationLat,
        longitude: event.locationLng,
        locationText: event.locationText,
        label: event.title,
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.label,
    required this.color,
    required this.textColor,
    this.icon,
  });

  final String label;
  final Color color;
  final Color textColor;
  final IconData? icon;

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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: textColor),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              label,
              style: AppTextStyles.label.copyWith(color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: AppTextStyles.body),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  return DateFormatter.turkishEventDateTime(value);
}
