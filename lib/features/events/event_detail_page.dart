import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../auth/auth_provider.dart';
import '../profile/profile_provider.dart';
import 'events_models.dart';
import 'events_provider.dart';
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
      appBar: AppBar(title: const Text('Event detail')),
      body: SafeArea(
        child: eventAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                '$error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
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
    final requestController = ref.read(
      joinRequestControllerProvider(event.id).notifier,
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(event.title, style: AppTextStyles.headline)),
            if (event.isSponsored)
              const Text(
                'Sponsored',
                style: TextStyle(color: AppColors.accent),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(event.sportType, style: AppTextStyles.title),
        const SizedBox(height: AppSpacing.lg),
        _DetailLine(label: 'Description', value: event.description ?? '-'),
        _DetailLine(label: 'Area', value: event.locationLabel),
        _DetailLine(label: 'Location', value: event.locationText ?? '-'),
        _DetailLine(label: 'Date', value: _formatDateTime(event.eventDate)),
        _DetailLine(label: 'Capacity', value: event.capacityLabel),
        const SizedBox(height: AppSpacing.lg),
        if (isHost)
          _HostRequestsSection(
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
    required this.state,
    required this.onApprove,
    required this.onReject,
  });

  final JoinRequestsState state;
  final Future<void> Function(String requestId) onApprove;
  final Future<void> Function(String requestId) onReject;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
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
                (request) => HostJoinRequestTile(
                  request: request,
                  isLoading: state.loading,
                  onApprove: () => onApprove(request.id),
                  onReject: () => onReject(request.id),
                ),
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
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}
