import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/auth_provider.dart';
import '../reports_models.dart';
import 'report_dialog.dart';

class ReportButton extends ConsumerWidget {
  const ReportButton({
    super.key,
    required this.targetType,
    required this.targetId,
    this.compact = false,
    this.menuItem = false,
  });

  final ReportTargetType targetType;
  final String targetId;
  final bool compact;
  final bool menuItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(authControllerProvider).userId;
    if (targetType == ReportTargetType.user && targetId == currentUserId) {
      return const SizedBox.shrink();
    }

    final label = _labelForTarget();

    if (menuItem) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        leading: const Icon(Icons.flag_outlined, color: AppColors.error),
        title: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
        ),
        onTap: () => _openDialog(context),
      );
    }

    if (compact) {
      return TextButton.icon(
        onPressed: () => _openDialog(context),
        icon: const Icon(Icons.flag_outlined),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textMuted,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        label: Text(label),
      );
    }

    return OutlinedButton.icon(
      onPressed: () => _openDialog(context),
      icon: const Icon(Icons.flag_outlined),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        side: const BorderSide(color: AppColors.border),
        shape: const StadiumBorder(),
      ),
      label: Text(label),
    );
  }

  String _labelForTarget() {
    switch (targetType) {
      case ReportTargetType.user:
        return 'Kullanıcıyı şikayet et';
      case ReportTargetType.event:
        return 'Etkinliği şikayet et';
      case ReportTargetType.post:
        return 'Paylaşımı şikayet et';
      case ReportTargetType.comment:
        return 'Yorumu şikayet et';
    }
  }

  Future<void> _openDialog(BuildContext context) async {
    final reported = await showDialog<bool>(
      context: context,
      builder: (context) {
        return ReportDialog(targetType: targetType, targetId: targetId);
      },
    );

    if (!context.mounted || reported != true) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Şikayet gönderildi.')));
  }
}
