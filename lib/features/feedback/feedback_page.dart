import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  int? _rating;
  String? _category;

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
      appBar: AppBar(title: const Text('Geri Bildirim')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Geri Bildirim', style: AppTextStyles.headline),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Deneyimini bize anlat. İyi gidenleri de sorun yaşadığın yerleri de güvenle paylaşabilirsin.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Puan', style: AppTextStyles.bodyStrong),
            const SizedBox(height: AppSpacing.sm),
            _RatingPicker(
              value: _rating,
              onChanged: (value) => setState(() => _rating = value),
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: FeedbackCategory.values
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() => _category = value),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Mesaj',
              hintText: 'Dilersen detay ekle',
              controller: _messageController,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Gönder',
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
      rating: _rating,
      category: _category,
      message: _messageController.text,
      source: 'settings',
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

class _RatingPicker extends StatelessWidget {
  const _RatingPicker({required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (var rating = 1; rating <= 5; rating += 1)
          ChoiceChip(
            selected: value == rating,
            label: Text('$rating'),
            avatar: Icon(
              Icons.star_rounded,
              size: 18,
              color: value == rating ? Colors.white : AppColors.primary,
            ),
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.primarySoft,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
            labelStyle: AppTextStyles.bodyStrong.copyWith(
              color: value == rating ? Colors.white : AppColors.primary,
            ),
            onSelected: (_) => onChanged(rating),
          ),
      ],
    );
  }
}
