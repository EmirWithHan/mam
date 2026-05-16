import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

class CreateHubPage extends StatelessWidget {
  const CreateHubPage({super.key});

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
            Text('Create', style: AppTextStyles.headline),
            const SizedBox(height: AppSpacing.sm),
            Text('Start an event or share a moment.', style: AppTextStyles.body),
            const SizedBox(height: AppSpacing.xl),
            _CreateActionCard(
              title: 'Create Event',
              subtitle: 'Gather people for a sport or social activity.',
              icon: Icons.event_available,
              accentColor: AppColors.primary,
              accentBackground: AppColors.primarySoft,
              onTap: () => context.goNamed(RouteNames.createEvent),
            ),
            const SizedBox(height: AppSpacing.md),
            _CreateActionCard(
              title: 'Share a Moment',
              subtitle: 'Post a photo from your day, match, or activity.',
              icon: Icons.photo_camera_outlined,
              accentColor: AppColors.secondary,
              accentBackground: AppColors.secondarySoft,
              onTap: () => context.goNamed(RouteNames.createPost),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateActionCard extends StatelessWidget {
  const _CreateActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.accentBackground,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Color accentBackground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
        borderRadius: AppRadius.xlBorder,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: accentBackground,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: accentColor, size: 28),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_rounded, color: accentColor),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(title, style: AppTextStyles.title),
              const SizedBox(height: AppSpacing.xs),
              Text(subtitle, style: AppTextStyles.bodySmall),
              const SizedBox(height: AppSpacing.md),
              Container(
                width: 54,
                height: 4,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: AppRadius.pillBorder,
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
