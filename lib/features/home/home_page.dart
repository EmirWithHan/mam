import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
                    const Icon(
                      Icons.sports_soccer,
                      color: AppColors.primary,
                      size: 44,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Find your next game',
                      style: AppTextStyles.headline,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Discover events, follow the community, and share match-day moments.',
                      style: AppTextStyles.body,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: 'Browse events',
                      onPressed: () => context.goNamed(RouteNames.events),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: 'Open feed',
                      variant: AppButtonVariant.secondary,
                      onPressed: () => context.goNamed(RouteNames.feed),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: 'Create',
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
