import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../reports_models.dart';
import '../reports_provider.dart';

class ReportDialog extends ConsumerStatefulWidget {
  const ReportDialog({
    super.key,
    required this.targetType,
    required this.targetId,
  });

  final ReportTargetType targetType;
  final String targetId;

  @override
  ConsumerState<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends ConsumerState<ReportDialog> {
  final _descriptionController = TextEditingController();
  ReportReason _reason = ReportReason.spam;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final success = await ref.read(reportsControllerProvider.notifier).submitReport(
          ReportInput(
            targetType: widget.targetType,
            targetId: widget.targetId,
            reason: _reason,
            description: _descriptionController.text,
          ),
        );

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportsControllerProvider);

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
      title: const Text('Report'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<ReportReason>(
            value: _reason,
            decoration: const InputDecoration(labelText: 'Reason'),
            items: ReportReason.values
                .map(
                  (reason) => DropdownMenuItem(
                    value: reason,
                    child: Text(reason.label),
                  ),
                )
                .toList(),
            onChanged: state.loading
                ? null
                : (reason) {
                    if (reason == null) return;
                    setState(() => _reason = reason);
                  },
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _descriptionController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Description optional',
            ),
          ),
          if (state.message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              state.message!,
              style: const TextStyle(color: AppColors.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: state.loading ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel', style: AppTextStyles.bodySmall),
        ),
        SizedBox(
          width: 120,
          child: AppButton(
            label: 'Submit',
            isLoading: state.loading,
            onPressed: _submit,
          ),
        ),
      ],
    );
  }
}
