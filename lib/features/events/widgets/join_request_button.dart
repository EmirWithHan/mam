import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../profile/profile_provider.dart';
import '../events_models.dart';
import '../join_requests_models.dart';

class JoinRequestButton extends StatelessWidget {
  const JoinRequestButton({
    super.key,
    required this.event,
    required this.profileState,
    required this.request,
    required this.isLoading,
    required this.onRequest,
    required this.onCancel,
    this.onConfirm,
    this.hasLeftEvent = false,
  });

  final Event event;
  final ProfileState profileState;
  final EventJoinRequest? request;
  final bool isLoading;
  final VoidCallback onRequest;
  final VoidCallback onCancel;
  final VoidCallback? onConfirm;
  final bool hasLeftEvent;

  @override
  Widget build(BuildContext context) {
    final currentRequest = request;

    if (event.isPast) {
      return const _StatusPanel(
        icon: Icons.event_busy_outlined,
        title: 'Bu etkinlik geçmişte kaldı.',
        message: 'Geçmiş etkinlikler için katılım işlemi yapılamaz.',
        color: AppColors.textMuted,
      );
    }

    if (hasLeftEvent) {
      return const _StatusPanel(
        icon: Icons.logout_rounded,
        title: 'Bu etkinlikten çıktın.',
        message: 'Katılımın iptal edildi. Chat ve çağrı erişimi kapatıldı.',
        color: AppColors.textMuted,
      );
    }

    if (currentRequest?.isPending == true) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StatusPanel(
            icon: Icons.hourglass_top,
            title: 'İstek beklemede',
            message: 'Ev sahibi katılım isteğini inceleyecek.',
            color: AppColors.warning,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: isLoading ? null : onCancel,
            child: const Text('İsteği iptal et'),
          ),
        ],
      );
    }

    if (event.isBusinessEvent &&
        currentRequest?.isPendingConfirmation == true) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StatusPanel(
            icon: Icons.verified_user_outlined,
            title: 'KatÄ±lÄ±mÄ±n onaylandÄ±.',
            message: 'Yerini ayÄ±rmak iÃ§in katÄ±lÄ±mÄ±nÄ± doÄŸrula.',
            color: AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'KatÄ±lÄ±mÄ± doÄŸrula',
            isLoading: isLoading,
            onPressed: isLoading ? null : onConfirm,
          ),
        ],
      );
    }

    if (event.isBusinessEvent && currentRequest?.isConfirmed == true) {
      return const _StatusPanel(
        icon: Icons.check_circle_outline,
        title: 'KatÄ±lÄ±m doÄŸrulandÄ±',
        message: 'Ä°ÅŸletme etkinliÄŸindeki yerin kesinleÅŸti.',
        color: AppColors.success,
      );
    }

    if (event.isBusinessEvent && currentRequest?.isWaitlisted == true) {
      return const _StatusPanel(
        icon: Icons.pending_actions_outlined,
        title: 'Yedek listedesin',
        message:
            'Yer aÃ§Ä±lÄ±rsa iÅŸletme etkinliÄŸi iÃ§in tekrar bilgilendirileceksin.',
        color: AppColors.warning,
      );
    }

    if (currentRequest?.isApproved == true) {
      return const _StatusPanel(
        icon: Icons.check_circle_outline,
        title: 'Onaylandı',
        message:
            'Etkinliğe katıldın. İzin verilen durumlarda chat ve çağrı erişimin açık.',
        color: AppColors.success,
      );
    }

    if (currentRequest?.isRejected == true) {
      return const _StatusPanel(
        icon: Icons.cancel_outlined,
        title: 'İstek reddedildi',
        message: 'Bu katılım isteği ev sahibi tarafından onaylanmadı.',
        color: AppColors.error,
      );
    }

    if (event.isFull) {
      return const _StatusPanel(
        icon: Icons.lock_outline,
        title: 'Etkinlik dolu',
        message: 'Bu etkinlik şu anda dolu.',
        color: AppColors.textMuted,
      );
    }

    if (profileState.isLoading) {
      return AppButton(
        label: 'Profil kontrol ediliyor',
        isLoading: isLoading,
        onPressed: null,
      );
    }

    if (profileState.status == ProfileStatus.error) {
      return const _StatusPanel(
        icon: Icons.info_outline,
        title: 'Profil bilgileri kontrol edilemedi.',
        message: 'Birazdan tekrar deneyebilirsin.',
        color: AppColors.error,
      );
    }

    if (!profileState.canRequestToJoinEvent) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StatusPanel(
            icon: Icons.assignment_ind_outlined,
            title: 'Etkinliklere katılmak için profilini tamamlamalısın.',
            message: 'Gerekli bilgiler: şehir, ilçe ve doğum tarihi.',
            color: AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Profili tamamla',
            onPressed: () => context.pushNamed(
              RouteNames.profileComplete,
              queryParameters: {
                'mode': RoutePaths.profileCompleteModeEventRequirements,
                'returnTo': _currentReturnPath(context),
              },
            ),
          ),
        ],
      );
    }

    if (currentRequest == null || currentRequest.isCancelled) {
      return AppButton(
        label: 'Katılım isteği gönder',
        isLoading: isLoading,
        onPressed: isLoading ? null : onRequest,
      );
    }

    return AppButton(label: currentRequest.status, onPressed: null);
  }

  String _currentReturnPath(BuildContext context) {
    final uri = GoRouterState.of(context).uri;
    return uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadius.lgBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyStrong.copyWith(color: color),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(message, style: AppTextStyles.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
