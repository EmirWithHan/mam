import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_logo.dart';
import 'auth_provider.dart';

class AccountDeletionPendingPage extends ConsumerWidget {
  const AccountDeletionPendingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const SizedBox(height: AppSpacing.xl),
            const Center(child: AppLogo(size: 56, showText: true)),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Hesap silme talebin işleme alındı.',
              style: AppTextStyles.headline,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Profilin ve herkese açık kimliğin pasifleştirildi. Nihai '
              'veri silme işlemi beta sürecinde manuel olarak tamamlanır.',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Çıkış Yap',
              isLoading: authState.isLoading,
              onPressed: () async {
                await ref.read(authControllerProvider.notifier).signOut();
                if (context.mounted) context.goNamed(RouteNames.auth);
              },
            ),
          ],
        ),
      ),
    );
  }
}
