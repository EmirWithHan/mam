import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';

class SocialPage extends StatelessWidget {
  const SocialPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('MaM', style: AppTextStyles.logo),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: AppRadius.xlBorder,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textPrimary.withValues(alpha: 0.05),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: AppColors.primarySoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.groups_outlined,
                          color: AppColors.primary,
                          size: 34,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Social', style: AppTextStyles.headline, textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Event chats and community activity will live here.',
                      style: AppTextStyles.body,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'No one-to-one messaging here yet. Social stays centered on events.',
                      style: AppTextStyles.caption,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: 'Go to Events',
                      onPressed: () => context.goNamed(RouteNames.events),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: 'Go to Feed',
                      variant: AppButtonVariant.secondary,
                      onPressed: () => context.goNamed(RouteNames.feed),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: 'Create something',
                      variant: AppButtonVariant.outlined,
                      onPressed: () => context.goNamed(RouteNames.create),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
