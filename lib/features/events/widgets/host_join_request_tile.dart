import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../profile/widgets/public_profile_preview_tile.dart';
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadius.mdBorder,
      ),
      child: PublicProfilePreviewTile(
        userId: request.userId,
        subtitle: request.status,
        compact: true,
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
      ),
    );
  }
}
