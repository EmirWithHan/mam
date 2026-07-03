import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/error_view.dart';
import 'events_models.dart';
import 'events_provider.dart';

class BusinessEventCheckInPage extends ConsumerStatefulWidget {
  const BusinessEventCheckInPage({
    super.key,
    required this.eventId,
    required this.eventTitle,
    this.openScannerOnLoad = false,
    this.qrScannerEnabled = true,
  });

  final String eventId;
  final String eventTitle;
  final bool openScannerOnLoad;
  final bool qrScannerEnabled;

  @override
  ConsumerState<BusinessEventCheckInPage> createState() =>
      _BusinessEventCheckInPageState();
}

class _BusinessEventCheckInPageState
    extends ConsumerState<BusinessEventCheckInPage> {
  bool _openedInitialScanner = false;

  @override
  Widget build(BuildContext context) {
    final participantsAsync = ref.watch(
      businessEventCheckInParticipantsProvider(widget.eventId),
    );
    final state = ref.watch(
      businessEventCheckInControllerProvider(widget.eventId),
    );

    ref.listen<BusinessEventCheckInState>(
      businessEventCheckInControllerProvider(widget.eventId),
      (previous, next) {
        final message = next.message;
        if (message == null || message == previous?.message) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Katılımcı kontrolü'),
        actions: widget.qrScannerEnabled
            ? [
                IconButton(
                  key: const Key('qr_scanner_button'),
                  tooltip: 'QR Okut',
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed:
                      participantsAsync.valueOrNull == null ||
                          participantsAsync.valueOrNull!.isEmpty
                      ? null
                      : () => _openRealQrScanner(
                          context,
                          participantsAsync.valueOrNull!,
                        ),
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: participantsAsync.when(
          loading: () => const AppLoader(),
          error: (error, _) => ErrorView(
            message: 'Katılımcılar yüklenemedi.',
            onRetry: () => ref.invalidate(
              businessEventCheckInParticipantsProvider(widget.eventId),
            ),
          ),
          data: (participants) {
            _openInitialScannerIfNeeded(participants);
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
                  return _Header(eventTitle: widget.eventTitle);
                }

                final participant = participants[index - 1];
                final isExcuse =
                    participant.attendanceStatus ==
                        EventParticipationStatus.cancelled &&
                    participant.excuseText != null;

                return _ParticipantTile(
                  participant: participant,
                  isLoading: state.isLoading(participant.userId),
                  onCheckedIn: isExcuse
                      ? () => ref
                            .read(eventsControllerProvider.notifier)
                            .resolveParticipantExcuse(
                              eventId: widget.eventId,
                              participantUserId: participant.userId,
                              excuseStatus: 'accepted',
                            )
                      : () => _mark(
                          ref,
                          participant,
                          EventParticipationStatus.checkedIn,
                        ),
                  onNoShow: isExcuse
                      ? () => ref
                            .read(eventsControllerProvider.notifier)
                            .resolveParticipantExcuse(
                              eventId: widget.eventId,
                              participantUserId: participant.userId,
                              excuseStatus: 'rejected',
                            )
                      : () => _mark(
                          ref,
                          participant,
                          EventParticipationStatus.noShow,
                        ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _openInitialScannerIfNeeded(
    List<BusinessEventCheckInParticipant> participants,
  ) {
    if (!widget.qrScannerEnabled ||
        !widget.openScannerOnLoad ||
        _openedInitialScanner) {
      return;
    }
    if (participants.isEmpty) return;
    _openedInitialScanner = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openRealQrScanner(context, participants);
    });
  }

  void _openRealQrScanner(
    BuildContext context,
    List<BusinessEventCheckInParticipant> participants,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _RealQrScannerSheet(
          eventId: widget.eventId,
          eventTitle: widget.eventTitle,
          participants: participants,
          controller: ref.read(
            businessEventCheckInControllerProvider(widget.eventId).notifier,
          ),
        );
      },
    );
  }

  Future<void> _mark(
    WidgetRef ref,
    BusinessEventCheckInParticipant participant,
    String attendanceStatus,
  ) async {
    await ref
        .read(businessEventCheckInControllerProvider(widget.eventId).notifier)
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
            'Ana akış QR okutmadır. Aşağıdaki manuel düzeltme sadece istisnai durumlar içindir.',
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
            if (participant.excuseText != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.tertiarySoft,
                  borderRadius: AppRadius.mdBorder,
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppColors.warning,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Mazeret: ${participant.excuseText}',
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            if (participant.excuseText != null) ...[
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
                      label: const Text('Mazereti Kabul Et'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.success,
                        side: const BorderSide(color: AppColors.success),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: canMark ? onNoShow : null,
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Mazereti Reddet'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(
                'Manuel düzeltme',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
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
                      label: const Text('Manuel geldi'),
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

class _RealQrScannerSheet extends StatefulWidget {
  const _RealQrScannerSheet({
    required this.eventId,
    required this.eventTitle,
    required this.participants,
    required this.controller,
  });

  final String eventId;
  final String eventTitle;
  final List<BusinessEventCheckInParticipant> participants;
  final BusinessEventCheckInController controller;

  @override
  State<_RealQrScannerSheet> createState() => _RealQrScannerSheetState();
}

class _RealQrScannerSheetState extends State<_RealQrScannerSheet> {
  final MobileScannerController scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _isProcessing = false;
  String? _errorMessage;
  BusinessEventCheckInParticipant? _scannedParticipant;
  String? _scannedUserId;
  String? _scannedToken;

  @override
  void dispose() {
    scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: MobileScanner(
              controller: scannerController,
              onDetect: _onDetect,
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: QrScannerOverlayPainter(
                borderColor: AppColors.primary,
                borderRadius: 12,
                borderLength: 30,
                borderWidth: 4,
                cutOutSize: 240,
              ),
            ),
          ),
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Text(
                  'QR Okut',
                  style: AppTextStyles.title.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Katılımcının QR kodunu kameraya göster.',
                  style: AppTextStyles.caption.copyWith(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          if (_errorMessage != null)
            Positioned(
              bottom: 120,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.9),
                  borderRadius: AppRadius.mdBorder,
                ),
                child: Text(
                  _errorMessage!,
                  style: AppTextStyles.body.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          if (_scannedToken != null)
            Positioned(
              left: 20,
              right: 20,
              bottom: 120,
              child: _ScannedParticipantPreview(
                participant: _scannedParticipant,
                eventTitle: widget.eventTitle,
                isLoading: _isProcessing,
                onCancel: () {
                  setState(() {
                    _scannedParticipant = null;
                    _scannedUserId = null;
                    _scannedToken = null;
                    _errorMessage = null;
                    _isProcessing = false;
                  });
                  scannerController.start();
                },
                onConfirm: _confirmScannedParticipant,
              ),
            ),
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: AppButton(
              label: 'Kapat',
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || _scannedToken != null) return;

    final barcode = capture.barcodes.firstOrNull;
    final rawValue = barcode?.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final parts = rawValue.split(':');
    if (parts.length < 3) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Geçersiz QR kod formatı.';
      });
      return;
    }

    final scannedEventId = parts[0].trim();
    final scannedUserId = parts[1].trim();
    final scannedToken = parts[2].trim();

    if (scannedUserId.isEmpty || scannedToken.isEmpty) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Ge\u00E7ersiz QR kod format\u0131.';
      });
      return;
    }

    if (scannedEventId != widget.eventId) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Bu QR kod farklı bir etkinliğe ait.';
      });
      return;
    }

    final participant = widget.participants
        .cast<BusinessEventCheckInParticipant?>()
        .firstWhere(
          (item) => item?.userId == scannedUserId,
          orElse: () => null,
        );
    await scannerController.stop();
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _scannedParticipant = participant;
      _scannedUserId = scannedUserId;
      _scannedToken = scannedToken;
    });
  }

  Future<void> _confirmScannedParticipant() async {
    final participantUserId = _scannedUserId;
    final token = _scannedToken;
    if (participantUserId == null || token == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final result = await widget.controller.verifyAndCheckIn(
      participantUserId: participantUserId,
      token: token,
    );

    if (!mounted) return;

    if (result == null) {
      setState(() {
        _isProcessing = false;
        _errorMessage =
            widget.controller.message ??
            'QR do\u011Frulama ba\u015Far\u0131s\u0131z. L\u00FCtfen tekrar dene.';
      });
      return;
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == 'already_checked_in'
              ? 'Bu kat\u0131l\u0131mc\u0131 zaten geldi olarak i\u015Faretlenmi\u015F.'
              : 'Kat\u0131l\u0131mc\u0131 geldi olarak i\u015Faretlendi.',
        ),
      ),
    );
  }
}

class _ScannedParticipantPreview extends StatelessWidget {
  const _ScannedParticipantPreview({
    required this.participant,
    required this.eventTitle,
    required this.isLoading,
    required this.onCancel,
    required this.onConfirm,
  });

  final BusinessEventCheckInParticipant? participant;
  final String eventTitle;
  final bool isLoading;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final participant = this.participant;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (participant == null)
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primarySoft,
                    child: Icon(
                      Icons.qr_code_2_rounded,
                      color: AppColors.primary,
                    ),
                  )
                else
                  _Avatar(participant: participant),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        participant?.displayName ??
                            'Kat\u0131l\u0131mc\u0131 QR kodu do\u011Frulanacak',
                        style: AppTextStyles.bodyStrong,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        eventTitle,
                        style: AppTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              participant == null
                  ? 'Kat\u0131l\u0131mc\u0131 bilgisi yenileniyor; do\u011Frulama sunucuda yap\u0131lacak.'
                  : 'Durum: ${participant.statusLabel}',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Geldi onay\u0131 ver',
              isLoading: isLoading,
              onPressed: isLoading ? null : onConfirm,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: isLoading ? null : onCancel,
              child: const Text('Vazge\u00E7'),
            ),
          ],
        ),
      ),
    );
  }
}

class QrScannerOverlayPainter extends CustomPainter {
  QrScannerOverlayPainter({
    required this.borderColor,
    required this.borderRadius,
    required this.borderLength,
    required this.borderWidth,
    required this.cutOutSize,
  });

  final Color borderColor;
  final double borderRadius;
  final double borderLength;
  final double borderWidth;
  final double cutOutSize;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final cutOutRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: cutOutSize,
      height: cutOutSize,
    );

    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final cutoutPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)),
      );

    final path = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );
    canvas.drawPath(path, backgroundPaint);

    final rrect = RRect.fromRectAndRadius(
      cutOutRect,
      Radius.circular(borderRadius),
    );

    canvas.drawPath(
      Path()
        ..moveTo(rrect.left, rrect.top + borderLength)
        ..lineTo(rrect.left, rrect.top + borderRadius)
        ..arcToPoint(
          Offset(rrect.left + borderRadius, rrect.top),
          radius: Radius.circular(borderRadius),
        )
        ..lineTo(rrect.left + borderLength, rrect.top),
      borderPaint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(rrect.right - borderLength, rrect.top)
        ..lineTo(rrect.right - borderRadius, rrect.top)
        ..arcToPoint(
          Offset(rrect.right, rrect.top + borderRadius),
          radius: Radius.circular(borderRadius),
          clockwise: true,
        )
        ..lineTo(rrect.right, rrect.top + borderLength),
      borderPaint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(rrect.left, rrect.bottom - borderLength)
        ..lineTo(rrect.left, rrect.bottom - borderRadius)
        ..arcToPoint(
          Offset(rrect.left + borderRadius, rrect.bottom),
          radius: Radius.circular(borderRadius),
          clockwise: false,
        )
        ..lineTo(rrect.left + borderLength, rrect.bottom),
      borderPaint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(rrect.right - borderLength, rrect.bottom)
        ..lineTo(rrect.right - borderRadius, rrect.bottom)
        ..arcToPoint(
          Offset(rrect.right, rrect.bottom - borderRadius),
          radius: Radius.circular(borderRadius),
          clockwise: true,
        )
        ..lineTo(rrect.right, rrect.bottom - borderLength),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
