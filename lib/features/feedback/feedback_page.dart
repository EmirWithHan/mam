import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/responsive_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import 'feedback_models.dart';
import 'feedback_provider.dart';

class FeedbackPage extends ConsumerStatefulWidget {
  const FeedbackPage({super.key});

  @override
  ConsumerState<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends ConsumerState<FeedbackPage> {
  final _messageController = TextEditingController();
  String _category = FeedbackCategory.suggestion;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(feedbackControllerProvider, (previous, next) {
      final message = next.message;
      if (message == null || message == previous?.message) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      if (next.success && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });

    final state = ref.watch(feedbackControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('\u0130stek & \u00D6neri')),
      body: SafeArea(
        child: ListView(
          padding: AppResponsive.pagePadding(context),
          children: [
            Text('\u0130stek & \u00D6neri', style: AppTextStyles.headline),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Bize \u00F6nerini, sorununu veya iste\u011Fini g\u00F6nder.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Kategori', style: AppTextStyles.bodyStrong),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final category in FeedbackCategory.values)
                  ChoiceChip(
                    selected: _category == category,
                    label: Text(category),
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.primarySoft,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.pillBorder,
                    ),
                    labelStyle: AppTextStyles.bodyStrong.copyWith(
                      color: _category == category
                          ? Colors.white
                          : AppColors.primary,
                    ),
                    onSelected: (_) => setState(() => _category = category),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Mesaj',
              hintText: 'En az 10 karakter yaz',
              controller: _messageController,
              maxLines: 7,
              helperText: 'En az 10, en fazla 1000 karakter.',
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Hesab\u0131na ba\u011Fl\u0131 kullan\u0131c\u0131 bilgin talebi takip etmek i\u00E7in eklenir.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'G\u00F6nder',
              isLoading: state.isSubmitting,
              onPressed: state.isSubmitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final input = UserFeedbackInput(
      category: _category,
      message: _messageController.text,
      source: 'settings_request_suggestion',
    );
    final validationError = input.validationError;
    if (validationError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    await ref.read(feedbackControllerProvider.notifier).submit(input);
  }
}
