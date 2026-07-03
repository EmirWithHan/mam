import 'package:flutter/material.dart';

Future<void> showInternalReviewPrompt({
  required BuildContext context,
  required VoidCallback onOpenFeedback,
}) async {
  final result = await showDialog<_InternalReviewPromptResult>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Akanzi deneyimin nasıldı?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(_InternalReviewPromptResult.problem),
            child: const Text('Sorun yaşadım'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(_InternalReviewPromptResult.good),
            child: const Text('İyi'),
          ),
        ],
      );
    },
  );

  if (!context.mounted || result == null) return;

  switch (result) {
    case _InternalReviewPromptResult.good:
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Teşekkürler! Yayına çıktığımızda mağaza değerlendirmeni isteyeceğiz.',
          ),
        ),
      );
    case _InternalReviewPromptResult.problem:
      onOpenFeedback();
  }
}

enum _InternalReviewPromptResult { good, problem }
