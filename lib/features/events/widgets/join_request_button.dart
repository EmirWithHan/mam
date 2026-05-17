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
  });

  final Event event;
  final ProfileState profileState;
  final EventJoinRequest? request;
  final bool isLoading;
  final VoidCallback onRequest;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    if (profileState.isLoading) {
      return AppButton(
        label: 'Checking profile',
        isLoading: isLoading,
        onPressed: null,
      );
    }

    if (event.isFull) {
      return const _StatusPanel(
        icon: Icons.lock_outline,
        title: 'Event is full',
        message: 'This event has reached its approved capacity.',
        color: AppColors.textMuted,
      );
    }

    if (!profileState.canRequestToJoinEvent) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StatusPanel(
            icon: Icons.assignment_ind_outlined,
            title: 'Complete your player card',
            message: 'Finish your profile before requesting to join events.',
            color: AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Complete profile',
            onPressed: () => context.pushNamed(RouteNames.profileComplete),
          ),
        ],
      );
    }

    final currentRequest = request;
    if (currentRequest == null) {
      return AppButton(
        label: 'Request to join',
        isLoading: isLoading,
        onPressed: onRequest,
      );
    }

    if (currentRequest.isPending) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StatusPanel(
            icon: Icons.hourglass_top,
            title: 'Request pending',
            message: 'The host will review your request.',
            color: AppColors.warning,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: isLoading ? null : onCancel,
            child: const Text('Cancel request'),
          ),
        ],
      );
    }

    if (currentRequest.isApproved) {
      return const _StatusPanel(
        icon: Icons.check_circle_outline,
        title: 'Approved',
        message: 'You are in. Chat and call actions are available when allowed.',
        color: AppColors.success,
      );
    }

    if (currentRequest.isRejected) {
      return const _StatusPanel(
        icon: Icons.cancel_outlined,
        title: 'Request rejected',
        message: 'This request was not approved by the host.',
        color: AppColors.error,
      );
    }

    if (currentRequest.isCancelled) {
      return const _StatusPanel(
        icon: Icons.remove_circle_outline,
        title: 'Request cancelled',
        message: 'You cancelled this request.',
        color: AppColors.textMuted,
      );
    }

    return AppButton(label: currentRequest.status, onPressed: null);
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
