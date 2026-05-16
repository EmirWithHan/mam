import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../reports_models.dart';
import 'report_dialog.dart';

class ReportButton extends StatelessWidget {
  const ReportButton({
    super.key,
    required this.targetType,
    required this.targetId,
    this.compact = false,
  });

  final ReportTargetType targetType;
  final String targetId;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = _labelForTarget();

    if (compact) {
      return TextButton.icon(
        onPressed: () => _openDialog(context),
        icon: const Icon(Icons.flag_outlined),
        style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
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
        return 'Report user';
      case ReportTargetType.event:
        return 'Report event';
      case ReportTargetType.post:
        return 'Report post';
      case ReportTargetType.comment:
        return 'Report comment';
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report submitted.')),
    );
  }
}
