import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_button.dart';
import '../event_call_provider.dart';

class EventCallButton extends ConsumerWidget {
  const EventCallButton({
    super.key,
    required this.eventId,
    required this.targetUserId,
    required this.label,
  });

  final String eventId;
  final String targetUserId;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callState = ref.watch(eventCallControllerProvider);
    final isCalling =
        callState.loading && callState.activeTargetUserId == targetUserId;

    return AppButton(
      label: label,
      isLoading: isCalling,
      onPressed: callState.loading
          ? null
          : () async {
              final success = await ref
                  .read(eventCallControllerProvider.notifier)
                  .callEventContact(
                    eventId: eventId,
                    targetUserId: targetUserId,
                  );

              if (!context.mounted) return;
              if (!success) {
                final message = ref.read(eventCallControllerProvider).message;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message ?? 'Could not start call.')),
                );
              }
            },
    );
  }
}
