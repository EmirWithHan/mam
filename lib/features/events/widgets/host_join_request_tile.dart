import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../join_requests_models.dart';

class HostJoinRequestTile extends StatelessWidget {
  const HostJoinRequestTile({
    super.key,
    required this.request,
    required this.isLoading,
    required this.onApprove,
    required this.onReject,
  });

  final EventJoinRequest request;
  final bool isLoading;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(request.userId, style: AppTextStyles.body),
      subtitle: Text(request.status, style: AppTextStyles.caption),
      trailing: request.isPending
          ? Wrap(
              spacing: AppSpacing.xs,
              children: [
                TextButton(
                  onPressed: isLoading ? null : onApprove,
                  child: const Text('Approve'),
                ),
                TextButton(
                  onPressed: isLoading ? null : onReject,
                  child: const Text('Reject'),
                ),
              ],
            )
          : null,
    );
  }
}
