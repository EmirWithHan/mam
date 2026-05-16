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
      appBar: AppBar(title: const Text('MaM')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: AppRadius.xlBorder,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.groups_outlined, color: AppColors.primary, size: 40),
                    const SizedBox(height: AppSpacing.md),
                    Text('Social', style: AppTextStyles.headline, textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Event chats and social activity will live here.',
                      style: AppTextStyles.body,
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
