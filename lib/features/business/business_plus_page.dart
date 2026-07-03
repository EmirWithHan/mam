import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/error_view.dart';
import 'business_models.dart';
import 'business_provider.dart';

class BusinessPlusPage extends ConsumerWidget {
  const BusinessPlusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessState = ref.watch(myBusinessAccountProvider);
    final account = businessState.account;

    return Scaffold(
      appBar: AppBar(title: const AppLogo(size: 32, showText: true)),
      body: SafeArea(
        child: businessState.isLoading && account == null
            ? const AppLoader()
            : account == null
            ? const ErrorView(
                message: 'Business Plus için aktif bir işletme hesabı gerekir.',
              )
            : _BusinessPlusContent(account: account),
      ),
    );
  }
}

class _BusinessPlusContent extends StatelessWidget {
  const _BusinessPlusContent({required this.account});

  final BusinessAccount account;

  @override
  Widget build(BuildContext context) {
    final isPlusActive = account.isPlusActive;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: isPlusActive
                ? AppColors.tertiary.withValues(alpha: 0.14)
                : AppColors.surface,
            borderRadius: AppRadius.xlBorder,
            border: Border.all(
              color: isPlusActive ? AppColors.tertiary : AppColors.border,
              width: isPlusActive ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.05),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.tertiary.withValues(alpha: 0.16),
                        borderRadius: AppRadius.lgBorder,
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        color: AppColors.tertiary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Business Plus', style: AppTextStyles.headline),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            isPlusActive
                                ? 'Business Plus aktif'
                                : 'İşletme hesabınız için profesyonel Akanzi deneyimi.',
                            style: AppTextStyles.body,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                if (isPlusActive)
                  const _StatusPill(text: 'Business Plus aktif')
                else
                  const _StatusPill(text: 'Satın alma yakında aktif olacak'),
                const SizedBox(height: AppSpacing.lg),
                const _BenefitLine(text: 'Daha esnek etkinlik planlama'),
                const _BenefitLine(
                  text: 'İşletme profilinde Plus ayrıcalıkları',
                ),
                const _BenefitLine(text: 'Profesyonel işletme deneyimi'),
                const _BenefitLine(
                  text:
                      'Akanzi içindeki işletme araçlarına hazır Plus altyapısı',
                ),
                if (!isPlusActive) ...[
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Business Plus’a Geç',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Satın alma yakında aktif olacak.'),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Text(text, style: AppTextStyles.bodyStrong),
    );
  }
}

class _BenefitLine extends StatelessWidget {
  const _BenefitLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}
