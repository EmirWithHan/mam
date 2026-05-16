import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/error_view.dart';
import '../auth/auth_provider.dart';
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
      appBar: AppBar(title: const Text('MaM')),
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
    final isApprovedParticipant = requestState.myRequest?.isApproved == true;
    final requestController = ref.read(
      joinRequestControllerProvider(event.id).notifier,
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: AppRadius.xlBorder,
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
                      Text(
                        'Sponsored',
                        style: AppTextStyles.label.copyWith(color: AppColors.warning),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(event.sportType, style: AppTextStyles.subtitle),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _HostPreviewCard(hostId: event.hostId),
        const SizedBox(height: AppSpacing.sm),
        _DetailCard(
          children: [
            _DetailLine(label: 'Description', value: event.description ?? '-'),
            _DetailLine(label: 'Area', value: event.locationLabel),
            _DetailLine(label: 'Location', value: event.locationText ?? '-'),
            _DetailLine(label: 'Date', value: _formatDateTime(event.eventDate)),
            _DetailLine(label: 'Capacity', value: event.capacityLabel),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (!isHost)
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              ReportButton(
                targetType: ReportTargetType.event,
                targetId: event.id,
                compact: true,
              ),
              ReportButton(
                targetType: ReportTargetType.user,
                targetId: event.hostId,
                compact: true,
              ),
              BlockButton(
                targetUserId: event.hostId,
                compact: true,
              ),
            ],
          ),
        const SizedBox(height: AppSpacing.lg),
        if (isHost || isApprovedParticipant) ...[
          AppButton(
            label: 'Open chat',
            onPressed: () => context.goNamed(
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
            onRequest: () async {
              await requestController.requestToJoin();
              await onRefreshEvent();
            },
            onCancel: () async {
              final request = requestState.myRequest;
              if (request == null) return;
              await requestController.cancelPendingRequest(request.id);
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
            const SizedBox(height: AppSpacing.md),
            if (state.loading && state.hostRequests.isEmpty)
              const Center(child: CircularProgressIndicator())
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

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.lgBorder,
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
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}
