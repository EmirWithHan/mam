import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
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
      return const AppButton(label: 'Event is full', onPressed: null);
    }

    if (!profileState.canRequestToJoinEvent) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Complete your profile before requesting to join events.',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Complete profile',
            onPressed: () => context.goNamed(RouteNames.profileComplete),
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
          AppButton(
            label: 'Request pending',
            isLoading: isLoading,
            onPressed: null,
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
      return const AppButton(label: 'Approved', onPressed: null);
    }

    if (currentRequest.isRejected) {
      return const AppButton(label: 'Request rejected', onPressed: null);
    }

    if (currentRequest.isCancelled) {
      return const AppButton(label: 'Request cancelled', onPressed: null);
    }

    return AppButton(label: currentRequest.status, onPressed: null);
  }
}
