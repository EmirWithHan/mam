import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../profile/widgets/public_profile_preview_tile.dart';
import '../join_requests_models.dart';

class HostJoinRequestTile extends StatelessWidget {
  const HostJoinRequestTile({
    super.key,
    required this.request,
    required this.isLoading,
    required this.onApprove,
    required this.onReject,
    this.actionsEnabled = true,
  });

  final EventJoinRequest request;
  final bool isLoading;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final bool actionsEnabled;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.lgBorder,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: PublicProfilePreviewTile(
          userId: request.userId,
          subtitle: 'Katılım isteği',
          compact: true,
          trailing: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _StatusChip(status: request.status),
              if (request.isPending && actionsEnabled) ...[
                TextButton(
                  onPressed: isLoading ? null : onApprove,
                  child: const Text('Onayla'),
                ),
                TextButton(
                  onPressed: isLoading ? null : onReject,
                  child: const Text('Reddet'),
                ),
              ] else if (request.isPending && !actionsEnabled) ...[
                const _PastEventChip(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PastEventChip extends StatelessWidget {
  const _PastEventChip();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.textMuted.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          'Geçmişte kaldı',
          style: AppTextStyles.label.copyWith(color: AppColors.textMuted),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'approved' => AppColors.success,
      'confirmed' => AppColors.success,
      'rejected' => AppColors.error,
      'cancelled' => AppColors.textMuted,
      'pending_confirmation' => AppColors.primary,
      'waitlisted' => AppColors.warning,
      _ => AppColors.warning,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          _statusLabel(status),
          style: AppTextStyles.label.copyWith(color: color),
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    return switch (status) {
      'approved' => 'Onaylandı',
      'pending_confirmation' => 'Doğrulama bekliyor',
      'confirmed' => 'Doğrulandı',
      'waitlisted' => 'Yedek listede',
      'rejected' => 'Reddedildi',
      'cancelled' => 'İptal edildi',
      'pending' => 'Bekliyor',
      _ => 'Bekliyor',
    };
  }
}
