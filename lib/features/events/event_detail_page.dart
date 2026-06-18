import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/layout/responsive_layout.dart';
import '../../core/router/route_names.dart';
import '../../core/constants/sport_types.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/event_cover_image.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/adaptive_dialog.dart';
import '../../services/maps_service.dart';
import '../auth/auth_provider.dart';
import '../business/business_reviews_models.dart';
import '../business/widgets/business_badge.dart';
import '../business/widgets/business_review_card.dart';
import '../chat/event_chat_list_provider.dart';
import '../chat/event_chat_provider.dart';
import '../profile/public_profile_provider.dart';
import '../profile/profile_provider.dart';
import '../profile/widgets/public_profile_avatar.dart';
import '../reports/reports_models.dart';
import '../reports/widgets/block_button.dart';
import '../reports/widgets/report_button.dart';
import 'business_event_check_in_page.dart';
import 'host_analytics_page.dart';
import 'events_models.dart';
import 'events_provider.dart';
import 'widgets/event_participants_preview.dart';
import 'join_requests_provider.dart';
import 'widgets/host_join_request_tile.dart';
import 'widgets/join_request_button.dart';
import 'widgets/event_share_sheet.dart';

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
      if (!mounted) return;
      ref.read(profileControllerProvider.notifier).loadMyProfile();
    });
  }

  void _loadJoinState(Event event, bool isHost) {
    if (_loadedEventId == event.id && _loadedForHost == isHost) return;

    _loadedEventId = event.id;
    _loadedForHost = isHost;
    Future.microtask(() {
      if (!mounted) return;
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
          tooltip: 'Geri',
          onPressed: () => _goBack(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const AppLogo(size: 32, showText: true),
        actions: eventAsync.valueOrNull == null
            ? null
            : [
                IconButton(
                  icon: const Icon(
                    Icons.share_outlined,
                    color: AppColors.primary,
                  ),
                  tooltip: 'Paylaş',
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) =>
                          EventShareSheet(event: eventAsync.valueOrNull!),
                    );
                  },
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
      ),
      body: SafeArea(
        child: eventAsync.when(
          loading: () => const AppLoader(),
          error: (error, _) => ErrorView(
            message: 'Etkinlik yüklenemedi.',
            onRetry: () => ref.invalidate(eventDetailProvider(widget.eventId)),
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
    final participantStatusesAsync = isHost
        ? ref.watch(eventParticipantAttendanceStatusesProvider(event.id))
        : null;
    final publicParticipantsAsync = ref.watch(
      eventPublicParticipantsProvider(event.id),
    );
    final capacityCountsAsync = ref.watch(
      eventCapacityBucketCountsProvider(event.id),
    );
    final myParticipationAsync = ref.watch(
      eventMyParticipationProvider(event.id),
    );
    final myParticipation = myParticipationAsync.valueOrNull;
    final hasMyParticipation = myParticipationAsync.hasValue;
    final hasLeftEvent = myParticipation?.hasLeftEvent ?? false;
    final canLeaveApprovedEvent =
        !event.isPast &&
        !isHost &&
        (myParticipation?.canLeaveApprovedEvent ?? false);
    final isFinalParticipant =
        !isHost &&
        !hasLeftEvent &&
        (hasMyParticipation
            ? myParticipation?.countsAsFinalParticipant(
                    isBusinessEvent: event.isBusinessEvent,
                  ) ==
                  true
            : requestState.myRequest?.isFinalParticipant(
                    isBusinessEvent: event.isBusinessEvent,
                  ) ==
                  true);
    final canViewPublicParticipants = isHost || isFinalParticipant;
    final requestController = ref.read(
      joinRequestControllerProvider(event.id).notifier,
    );
    final businessId = event.organizerBusinessId;
    final canReviewBusiness =
        businessId != null &&
        BusinessReviewRules.canReviewBusinessEvent(
          isBusinessEvent: event.isBusinessEvent,
          isOwner: isHost,
          attendanceStatus: myParticipation?.attendanceStatus,
        );
    final isQrWindowOpen = event.isAttendanceWindowOpen();
    final qrWindowMessage = event.isBeforeAttendanceWindow()
        ? 'Etkinlik zamanı gelmeden QR okutulamaz.'
        : event.isAfterAttendanceWindow()
        ? 'QR okutma süresi sona erdi. Gerekirse manuel düzeltme kullan.'
        : null;

    return ListView(
      padding: AppResponsive.pagePadding(context),
      children: [
        _EventHeroCard(event: event, isHost: isHost),
        const SizedBox(height: AppSpacing.lg),
        if (isHost) ...[
          _HostQrScanCard(
            isEnabled: isQrWindowOpen,
            helperText: qrWindowMessage,
            onScan: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BusinessEventCheckInPage(
                  eventId: event.id,
                  eventTitle: event.titleLabel,
                  openScannerOnLoad: true,
                  qrScannerEnabled: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ] else if (!isHost && isFinalParticipant) ...[
          _ParticipantQrCard(
            event: event,
            participation: myParticipation,
            userId: ref.watch(authControllerProvider).userId,
            isLoading: myParticipationAsync.isLoading,
            onOpen: myParticipation?.checkInToken == null
                ? null
                : () =>
                      _showCheckInQrModal(context, event, myParticipation, ref),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        const _SectionTitle(title: 'Ev sahibi'),
        const SizedBox(height: AppSpacing.sm),
        _HostPreviewCard(hostId: event.hostId),
        const SizedBox(height: AppSpacing.lg),
        const _SectionTitle(title: 'Etkinlik bilgileri'),
        const SizedBox(height: AppSpacing.sm),
        _DetailCard(
          children: [
            _InfoBlock(
              label: 'Açıklama',
              value: event.descriptionLabel,
              muted: !event.hasDescription,
            ),
            const SizedBox(height: AppSpacing.md),
            _AreaTile(event: event),
            const SizedBox(height: AppSpacing.md),
            _LocationCard(event: event),
            const SizedBox(height: AppSpacing.md),
            _InfoTile(
              label: 'Tarih',
              value: DateFormatter.turkishEventDateTime(event.eventDate),
              icon: Icons.calendar_today_outlined,
            ),
            const SizedBox(height: AppSpacing.md),
            _InfoTile(
              label: 'Kontenjan',
              value: _formatCapacityBreakdown(
                event,
                capacityCountsAsync.valueOrNull,
              ),
              icon: Icons.groups_outlined,
            ),
          ],
        ),
        if (canViewPublicParticipants) ...[
          const SizedBox(height: AppSpacing.lg),
          EventParticipantsPreview(
            participants: publicParticipantsAsync.valueOrNull ?? const [],
            isLoading: publicParticipantsAsync.isLoading,
            errorMessage: publicParticipantsAsync.hasError
                ? '${publicParticipantsAsync.error}'
                : null,
            onRetry: () =>
                ref.invalidate(eventPublicParticipantsProvider(event.id)),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        const _SectionTitle(title: 'İşlemler'),
        const SizedBox(height: AppSpacing.sm),
        if (!isHost && event.isBusinessEvent)
          _BusinessAttendanceNotice(status: myParticipation?.attendanceStatus),
        if (businessId != null && canReviewBusiness) ...[
          BusinessReviewCard(
            eventId: event.id,
            businessId: businessId,
            canReview: canReviewBusiness,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (isHost && event.isAfterAttendanceWindow()) ...[
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BusinessEventCheckInPage(
                  eventId: event.id,
                  eventTitle: event.titleLabel,
                  qrScannerEnabled: false,
                ),
              ),
            ),
            icon: const Icon(Icons.edit_note_outlined),
            label: const Text('Manuel düzeltme'),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (isHost) ...[
          OutlinedButton.icon(
            key: const Key('host_analytics_button'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => HostAnalyticsPage(
                  eventId: event.id,
                  eventTitle: event.titleLabel,
                ),
              ),
            ),
            icon: const Icon(Icons.analytics_outlined),
            label: const Text('Katılım Analizi'),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (!event.isPast && (isHost || isFinalParticipant)) ...[
          AppButton(
            label: 'Sohbeti aç',
            onPressed: () => context.pushNamed(
              RouteNames.eventChat,
              pathParameters: {'eventId': event.id},
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (!event.isPast && !isHost && isFinalParticipant) ...[
          if (canLeaveApprovedEvent) ...[
            _LeaveApprovedEventButton(
              onPressed: () =>
                  _confirmLeaveApprovedEvent(context, ref, requestController),
            ),
          ],
          if (myParticipation != null &&
              myParticipation.isActiveApprovedParticipant &&
              myParticipation.attendanceStatus !=
                  EventParticipationStatus.checkedIn &&
              !event.isPast) ...[
            const SizedBox(height: AppSpacing.sm),
            if (myParticipation.excuseText != null)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  border: Border.all(color: AppColors.border),
                  borderRadius: AppRadius.lgBorder,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Mazeret bildirdin: ${myParticipation.excuseText}',
                          style: AppTextStyles.body,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              AppButton(
                label: 'Gelemeyeceğim (Mazeret Bildir)',
                variant: AppButtonVariant.outlined,
                onPressed: () => _showExcuseDialog(context, ref, event.id),
              ),
          ],
          const SizedBox(height: AppSpacing.lg),
        ],
        if (isHost)
          _HostRequestsSection(
            eventId: event.id,
            state: requestState,
            isPastEvent: event.isPast,
            isBusinessEvent: event.isBusinessEvent,
            participantStatuses:
                participantStatusesAsync?.valueOrNull ?? const {},
            onApprove: (requestId) async {
              await requestController.approveRequest(requestId);
              ref.invalidate(
                eventParticipantAttendanceStatusesProvider(event.id),
              );
              ref.invalidate(eventPublicParticipantsProvider(event.id));
              await onRefreshEvent();
            },
            onReject: (requestId) async {
              await requestController.rejectRequest(requestId);
              ref.invalidate(
                eventParticipantAttendanceStatusesProvider(event.id),
              );
              ref.invalidate(eventPublicParticipantsProvider(event.id));
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
                    content: Text(message ?? 'Katılım isteği gönderilemedi.'),
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
            onConfirm: () async {
              final confirmed = await ref
                  .read(eventsControllerProvider.notifier)
                  .confirmBusinessParticipation(event.id);
              if (!confirmed) {
                if (!context.mounted) return;
                final message = ref.read(eventsControllerProvider).message;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message ?? 'KatÄ±lÄ±m doÄŸrulanamadÄ±.'),
                  ),
                );
                return;
              }
              await requestController.loadMyRequest();
              ref.invalidate(eventMyParticipationProvider(event.id));
              ref.invalidate(eventAttendanceStatusProvider(event.id));
              ref.invalidate(eventPublicParticipantsProvider(event.id));
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
    final eventStart = event.eventDate;
    final isLateCancellation =
        eventStart.difference(DateTime.now()).inHours < 24;

    String? excuseText;
    bool confirmed = false;

    if (isLateCancellation) {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) {
          final textController = TextEditingController();
          return AlertDialog(
            title: const Text('Etkinlikten Ayrıl'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Etkinliğe 24 saatten az süre kalmıştır. Ayrılma nedeninizi (mazeretinizi) belirterek güven skorunuzu koruyabilirsiniz. Yöneticiler mazeretinizi onaylarsa puan düşüşü geri alınacaktır.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: textController,
                  decoration: const InputDecoration(
                    labelText: 'Mazeretiniz (İsteğe bağlı)',
                    hintText: 'Mazeretini yaz',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Vazgeç'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop({
                    'confirmed': true,
                    'excuse': textController.text.trim(),
                  });
                },
                child: const Text('Etkinlikten Ayrıl'),
              ),
            ],
          );
        },
      );
      if (result != null && result['confirmed'] == true) {
        confirmed = true;
        final exc = result['excuse'] as String;
        if (exc.isNotEmpty) {
          excuseText = exc;
        }
      }
    } else {
      final res = await showAdaptiveConfirmDialog(
        context,
        title: 'Etkinlikten çıkılsın mı?',
        content:
            'Bu etkinlikten çıkmak istediğinize emin misiniz? Zamanında ayrıldığınız için güven puanınız etkilenmeyecektir.',
        confirmLabel: 'Etkinlikten çık',
        cancelLabel: 'Vazgeç',
        isDestructive: true,
      );
      if (res == true) {
        confirmed = true;
      }
    }

    if (!confirmed || !context.mounted) return;

    final left = await ref
        .read(eventsControllerProvider.notifier)
        .cancelParticipation(eventId: event.id, excuseText: excuseText);

    ref.invalidate(eventMyParticipationProvider(event.id));
    ref.invalidate(eventAttendanceStatusProvider(event.id));
    ref.invalidate(eventParticipantAttendanceStatusesProvider(event.id));
    ref.invalidate(eventPublicParticipantsProvider(event.id));
    ref.invalidate(eventDetailProvider(event.id));
    ref.invalidate(eventChatControllerProvider(event.id));
    ref.invalidate(eventChatListControllerProvider);
    await requestController.loadMyRequest();
    if (!context.mounted) return;

    if (left) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            excuseText != null
                ? 'Etkinlikten çıkıldı ve mazeretiniz iletildi.'
                : 'Etkinlikten çıkıldı.',
          ),
        ),
      );
      return;
    }

    final message = ref.read(eventsControllerProvider).message;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message ?? 'Etkinlikten çıkılamadı.')),
    );
  }

  void _showCheckInQrModal(
    BuildContext context,
    Event event,
    EventParticipation? participation,
    WidgetRef ref,
  ) {
    final userId = ref.read(authControllerProvider).userId ?? '';
    final token = participation?.checkInToken;
    if (token == null || token.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'QR kod olu\u015Fturulamad\u0131. L\u00FCtfen tekrar dene.',
          ),
        ),
      );
      return;
    }

    final qrData = '${event.id}:$userId:$token';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  event.titleLabel,
                  style: AppTextStyles.title,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'QR Kodum',
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  width: 220,
                  height: 220,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadius.lgBorder,
                    border: Border.all(color: AppColors.border, width: 2),
                  ),
                  child: Center(
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 190.0,
                      gapless: false,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  event.isBusinessEvent
                      ? 'Bunu işletmeye vardığınızda okutun.'
                      : 'Bunu etkinlik sahibine okutun.',
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                SelectableText(
                  'Kod: $token',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Kapat',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showExcuseDialog(BuildContext context, WidgetRef ref, String eventId) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Mazeret Bildir'),
          content: TextField(
            controller: textController,
            decoration: const InputDecoration(
              hintText: 'Neden katılamayacağınızı belirtin...',
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () async {
                final excuse = textController.text.trim();
                if (excuse.isNotEmpty) {
                  final success = await ref
                      .read(eventsControllerProvider.notifier)
                      .submitExcuse(eventId: eventId, excuseText: excuse);
                  if (context.mounted) {
                    Navigator.pop(context);
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Mazeretiniz kaydedildi.'),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Mazeret kaydedilemedi.')),
                      );
                    }
                  }
                }
              },
              child: const Text('Gönder'),
            ),
          ],
        );
      },
    );
  }
}

class _BusinessAttendanceNotice extends StatelessWidget {
  const _BusinessAttendanceNotice({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final message = switch (status) {
      EventParticipationStatus.checkedIn => 'Katılımın işaretlendi.',
      EventParticipationStatus.noShow =>
        'Bu etkinlikte gelmedi olarak işaretlendin.',
      _ => null,
    };

    if (message == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          border: Border.all(color: AppColors.border),
          borderRadius: AppRadius.lgBorder,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(message, style: AppTextStyles.body)),
            ],
          ),
        ),
      ),
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
    required this.isPastEvent,
    required this.isBusinessEvent,
    required this.participantStatuses,
    required this.onApprove,
    required this.onReject,
  });

  final String eventId;
  final JoinRequestsState state;
  final bool isPastEvent;
  final bool isBusinessEvent;
  final Map<String, String> participantStatuses;
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
            Text('Ev sahibi sensin', style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.xs),
            Text(
              isPastEvent
                  ? 'Bu etkinlik geçmişte kaldı. Yeni katılım işlemi yapılamaz.'
                  : 'Katılım isteklerini inceleyip ekibi hazır tutabilirsin.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.md),
            if (state.loading && state.hostRequests.isEmpty)
              const AppLoader()
            else if (state.hostRequests.isEmpty)
              Text('Henüz katılım isteği yok.', style: AppTextStyles.body)
            else
              ...state.hostRequests.map(
                (request) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HostJoinRequestTile(
                      request: request,
                      isLoading: state.loading,
                      actionsEnabled: !isPastEvent,
                      onApprove: () => onApprove(request.id),
                      onReject: () => onReject(request.id),
                    ),
                    if (EventParticipationStatus.countsAsFinalParticipant(
                      isBusinessEvent: isBusinessEvent,
                      status: participantStatuses[request.userId],
                    )) ...[
                      const SizedBox(height: AppSpacing.xs),
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
        padding: AppResponsive.cardPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EventCoverImage(sportType: event.sportType, height: 154),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(event.title, style: AppTextStyles.headline),
                ),
                if (event.isActiveSponsoredPlacement(DateTime.now()))
                  _MiniChip(
                    label: 'Sponsorlu',
                    color: const Color(0xFFFF7E79),
                    textColor: Colors.white,
                  ),
                if (event.isPast)
                  _MiniChip(
                    label: 'Geçmiş',
                    color: AppColors.border,
                    textColor: AppColors.textMuted,
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
                if (event.isBusinessEvent) ...[
                  BusinessBadge(
                    isVerified: event.businessOrganizer?.isVerified ?? false,
                  ),
                  _MiniChip(
                    label: event.priceLabel,
                    color: AppColors.secondarySoft,
                    textColor: AppColors.secondary,
                    icon: Icons.payments_outlined,
                  ),
                ],
                _MiniChip(
                  label: sportLabelFor(event.sportType),
                  color: AppColors.primary,
                  textColor: Colors.white,
                  icon: sportIconFor(event.sportType),
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
            _DetailLine(label: 'Nerede', value: event.locationLabel),
            _DetailLine(
              label: 'Ne zaman',
              value: _formatDateTime(event.eventDate),
            ),
            if (event.isBusinessEvent) ...[
              _DetailLine(label: 'Düzenleyen', value: 'İşletme etkinliği'),
            ],
          ],
        ),
      ),
    );
  }
}

class _EventOverflowButton extends ConsumerWidget {
  const _EventOverflowButton({required this.event, required this.isHost});

  final Event event;
  final bool isHost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: 'Etkinlik işlemleri',
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
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
                Text('Etkinlik işlemleri', style: AppTextStyles.title),
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
                            if (event.canBeEdited) ...[
                              _EventEditMenuItem(
                                onTap: () {
                                  Navigator.of(sheetContext).pop();
                                  rootContext.pushNamed(
                                    RouteNames.editEvent,
                                    pathParameters: {'eventId': event.id},
                                  );
                                },
                              ),
                              const Divider(height: 1, color: AppColors.border),
                            ],
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
    final confirmed = await showAdaptiveConfirmDialog(
      context,
      title: 'Etkinlik silinsin mi?',
      content:
          'Bu etkinlik kaldırılacak. Etkinlik sohbeti ve katılım istekleri de kaldırılır.',
      confirmLabel: 'Sil',
      cancelLabel: 'Vazgeç',
      isDestructive: true,
    );

    if (confirmed != true || !context.mounted) return;

    final deleted = await ref
        .read(eventsControllerProvider.notifier)
        .deleteEvent(event.id);
    ref.invalidate(eventDetailProvider(event.id));
    if (!context.mounted) return;

    if (deleted) {
      final messenger = ScaffoldMessenger.of(context);
      context.goNamed(RouteNames.events);
      messenger.showSnackBar(
        const SnackBar(content: Text('Etkinlik silindi.')),
      );
      return;
    }

    final message = ref.read(eventsControllerProvider).message;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message ?? 'Etkinlik silinemedi.')));
  }
}

class _EventEditMenuItem extends StatelessWidget {
  const _EventEditMenuItem({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
      title: Text('Etkinliği düzenle', style: AppTextStyles.bodyStrong),
      onTap: onTap,
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
        'Etkinliği sil',
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
    final trimmedHostId = hostId.trim();
    final asyncProfile = ref.watch(publicProfilePreviewProvider(hostId));

    return asyncProfile.maybeWhen(
      data: (profile) {
        final secondaryText = profile?.usernameTag ?? 'Ev sahibi';
        final trustScore = profile?.trustScore;

        return InkWell(
          borderRadius: AppRadius.lgBorder,
          onTap: trimmedHostId.isEmpty
              ? null
              : () => context.pushNamed(
                  RouteNames.publicProfile,
                  pathParameters: {'userId': trimmedHostId},
                ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: AppRadius.lgBorder,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  PublicProfileAvatar(
                    profile: profile,
                    radius: 24,
                    enableNavigation: false,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.displayName ?? 'Match A Man kullanıcısı',
                          style: AppTextStyles.bodyStrong,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          secondaryText,
                          style: AppTextStyles.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                          '$trustScore güven',
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  if (trimmedHostId.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.sm),
                    const Icon(Icons.chevron_right, color: AppColors.textMuted),
                  ],
                ],
              ),
            ),
          ),
        );
      },
      orElse: () => InkWell(
        borderRadius: AppRadius.lgBorder,
        onTap: trimmedHostId.isEmpty
            ? null
            : () => context.pushNamed(
                RouteNames.publicProfile,
                pathParameters: {'userId': trimmedHostId},
              ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: AppRadius.lgBorder,
          ),
          child: const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                PublicProfileAvatar(radius: 24, enableNavigation: false),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Match A Man kullanıcısı',
                    style: AppTextStyles.bodyStrong,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HostQrScanCard extends StatelessWidget {
  const _HostQrScanCard({
    required this.isEnabled,
    required this.helperText,
    required this.onScan,
  });

  final bool isEnabled;
  final String? helperText;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kat\u0131l\u0131mc\u0131 QR okut',
                    style: AppTextStyles.title,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Etkinlik günü katılımcının QR kodunu okutarak gelişini onayla.',
                    style: AppTextStyles.body,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(label: 'QR okut', onPressed: isEnabled ? onScan : null),
        if (helperText != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            helperText!,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (!isEnabled && helperText!.startsWith('Etkinlik zamanı')) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'QR okutma etkinlik günü aktif olacak.',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ],
    );
  }
}

class _ParticipantQrCard extends StatelessWidget {
  const _ParticipantQrCard({
    required this.event,
    required this.participation,
    required this.userId,
    required this.isLoading,
    required this.onOpen,
  });

  final Event event;
  final EventParticipation? participation;
  final String? userId;
  final bool isLoading;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final token = participation?.checkInToken;
    final canShowQr =
        userId != null && token != null && token.trim().isNotEmpty;
    final qrData = canShowQr ? '${event.id}:$userId:$token' : null;

    return _DetailCard(
      children: [
        Text('QR Kodum', style: AppTextStyles.title),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Etkinlik günü geldiğinde bu kodu etkinlik sahibine okut.',
          style: AppTextStyles.body,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Katılımın onaylandı.',
          style: AppTextStyles.caption.copyWith(color: AppColors.success),
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Container(
            width: 260,
            height: 260,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppRadius.xlBorder,
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: Center(
              child: isLoading
                  ? Text(
                      'QR kod haz\u0131rlan\u0131yor...',
                      style: AppTextStyles.body,
                      textAlign: TextAlign.center,
                    )
                  : qrData == null
                  ? Text(
                      'QR kod olu\u015Fturulamad\u0131. L\u00FCtfen tekrar dene.',
                      style: AppTextStyles.body,
                      textAlign: TextAlign.center,
                    )
                  : QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 220,
                      gapless: false,
                    ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'QR kodu b\u00FCy\u00FCt',
          variant: AppButtonVariant.secondary,
          onPressed: canShowQr ? onOpen : null,
        ),
      ],
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
        padding: AppResponsive.cardPadding(context),
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
      label: 'Şehir / ilçe',
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
        child: _DetailLine(label: 'Konum', value: 'Konum bilgisi eklenmemiş.'),
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
                      const _InfoLabel('Etkinlik konumu'),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        event.locationLabel,
                        style: AppTextStyles.bodyStrong,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (event.locationDisplayLabel !=
                          event.locationLabel) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          event.locationDisplayLabel,
                          style: AppTextStyles.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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
        city: event.city,
        district: event.district,
        label: event.title,
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harita uygulaması açılamadı.')),
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: DecoratedBox(
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
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.label.copyWith(color: textColor),
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

String _formatCapacityBreakdown(Event event, Map<String, int>? counts) {
  final genericUsed = counts?[EventCapacityBucket.generic] ?? 0;
  final maleUsed = counts?[EventCapacityBucket.male] ?? 0;
  final femaleUsed = counts?[EventCapacityBucket.female] ?? 0;
  return [
    'Karışık: $genericUsed/${event.genericCapacity}',
    'Erkek: $maleUsed/${event.maleCapacity}',
    'Kadın: $femaleUsed/${event.femaleCapacity}',
    'Toplam: ${event.safeApprovedCount}/${event.safeCapacityTotal}',
  ].join(' • ');
}
