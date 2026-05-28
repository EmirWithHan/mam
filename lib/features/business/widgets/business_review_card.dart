import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../business_reviews_models.dart';
import '../business_reviews_provider.dart';

class BusinessReviewCard extends ConsumerStatefulWidget {
  const BusinessReviewCard({
    super.key,
    required this.eventId,
    required this.businessId,
    required this.canReview,
  });

  final String eventId;
  final String businessId;
  final bool canReview;

  @override
  ConsumerState<BusinessReviewCard> createState() => _BusinessReviewCardState();
}

class _BusinessReviewCardState extends ConsumerState<BusinessReviewCard> {
  final _commentController = TextEditingController();
  var _rating = 5;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canReview) return const SizedBox.shrink();

    final args = BusinessReviewStatusArgs(
      eventId: widget.eventId,
      businessId: widget.businessId,
    );
    final statusAsync = ref.watch(businessReviewStatusProvider(args));
    final submitState = ref.watch(businessReviewControllerProvider);

    return statusAsync.maybeWhen(
      data: (status) {
        if (status.hasReviewed) {
          return const _ReviewShell(
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, color: AppColors.primary),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Değerlendirmen alındı.',
                    style: AppTextStyles.bodyStrong,
                  ),
                ),
              ],
            ),
          );
        }

        return _ReviewShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('İşletmeyi değerlendir', style: AppTextStyles.title),
              const SizedBox(height: AppSpacing.sm),
              _StarPicker(
                rating: _rating,
                onChanged: (value) => setState(() => _rating = value),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Yorum (opsiyonel)',
                controller: _commentController,
                maxLines: 3,
                helperText: 'En fazla 300 karakter.',
              ),
              if (submitState.message != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  submitState.message!,
                  style: AppTextStyles.caption.copyWith(color: AppColors.error),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: submitState.isLoading ? 'Gönderiliyor...' : 'Gönder',
                onPressed: submitState.isLoading ? null : _submit,
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Future<void> _submit() async {
    final sent = await ref
        .read(businessReviewControllerProvider.notifier)
        .submit(
          BusinessReviewInput(
            eventId: widget.eventId,
            businessId: widget.businessId,
            rating: _rating,
            comment: _commentController.text,
          ),
        );

    if (!sent || !mounted) return;
    FocusScope.of(context).unfocus();
  }
}

class _ReviewShell extends StatelessWidget {
  const _ReviewShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.lgBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: child,
      ),
    );
  }
}

class _StarPicker extends StatelessWidget {
  const _StarPicker({required this.rating, required this.onChanged});

  final int rating;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var value = 1; value <= 5; value += 1)
          IconButton(
            tooltip: '$value yıldız',
            onPressed: () => onChanged(value),
            icon: Icon(
              value <= rating ? Icons.star_rounded : Icons.star_border_rounded,
              color: AppColors.secondary,
              size: 32,
            ),
          ),
      ],
    );
  }
}
