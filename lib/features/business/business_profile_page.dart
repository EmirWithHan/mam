import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/error_view.dart';
import '../auth/auth_provider.dart';
import 'business_models.dart';
import 'business_provider.dart';
import 'business_reviews_models.dart';
import 'business_reviews_provider.dart';
import 'business_stats_page.dart';
import 'widgets/business_badge.dart';

class BusinessProfilePage extends ConsumerWidget {
  const BusinessProfilePage({super.key, required this.businessId});

  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(publicBusinessAccountProvider(businessId));
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.goNamed(RouteNames.settings);
          },
        ),
        title: const AppLogo(size: 32, showText: true),
      ),
      body: SafeArea(
        child: accountAsync.when(
          loading: () => const AppLoader(),
          error: (error, _) =>
              ErrorView(message: 'Isletme profili yuklenemedi.'),
          data: (account) {
            if (account == null) {
              return const ErrorView(message: 'Isletme profili bulunamadi.');
            }
            final isOwner = account.ownerUserId == authState.userId;
            if (!account.isPubliclyVisible && !isOwner) {
              return const ErrorView(message: 'Isletme profili yayinda degil.');
            }
            return _BusinessProfileBody(account: account, isOwner: isOwner);
          },
        ),
      ),
    );
  }
}

class _BusinessProfileBody extends ConsumerWidget {
  const _BusinessProfileBody({required this.account, required this.isOwner});

  final BusinessAccount account;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratingAsync = ref.watch(businessRatingSummaryProvider(account.id));

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.xlBorder,
            border: Border.all(color: AppColors.border),
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
              children: [
                _BusinessAvatar(account: account),
                const SizedBox(height: AppSpacing.md),
                Text(
                  account.displayName,
                  style: AppTextStyles.headline,
                  textAlign: TextAlign.center,
                ),
                if (account.displayHandle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    account.displayHandle!,
                    style: AppTextStyles.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                ratingAsync.maybeWhen(
                  data: (summary) => _RatingSummary(summary: summary),
                  orElse: () => const _RatingSummaryLoading(),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    BusinessBadge(isVerified: account.isVerified),
                    _InfoChip(label: account.displayCategory),
                    if (isOwner) _InfoChip(label: account.statusLabel),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _InfoLine(
                  icon: Icons.place_outlined,
                  label: account.locationLabel,
                ),
                if (account.address != null)
                  _InfoLine(icon: Icons.map_outlined, label: account.address!),
              ],
            ),
          ),
        ),
        if (account.description != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _SectionCard(
            title: 'Hakkinda',
            child: Text(account.description!, style: AppTextStyles.body),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _SectionCard(
          title: 'Iletisim',
          child: Column(
            children: [
              if (account.website != null)
                _ContactLine(
                  icon: Icons.language_outlined,
                  label: account.website!,
                ),
              if (account.instagram != null)
                _ContactLine(
                  icon: Icons.photo_camera_outlined,
                  label: '@${account.instagram!}',
                ),
              if (account.phone != null)
                _ContactLine(icon: Icons.phone_outlined, label: account.phone!),
              if (account.website == null &&
                  account.instagram == null &&
                  account.phone == null)
                Text('Iletisim bilgisi eklenmemis.', style: AppTextStyles.body),
            ],
          ),
        ),
        if (isOwner) ...[
          const SizedBox(height: AppSpacing.lg),
          _SectionCard(
            title: 'İstatistikler',
            child: AppButton(
              label: 'İstatistikler',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BusinessStatsPage(account: account),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Isletmeyi duzenle',
            onPressed: () => context.pushNamed(RouteNames.businessCreate),
          ),
        ],
      ],
    );
  }
}

class _BusinessAvatar extends StatelessWidget {
  const _BusinessAvatar({required this.account});

  final BusinessAccount account;

  @override
  Widget build(BuildContext context) {
    final logoUrl = account.logoUrl;
    return CircleAvatar(
      radius: 44,
      backgroundColor: AppColors.primarySoft,
      backgroundImage: logoUrl == null ? null : NetworkImage(logoUrl),
      child: logoUrl == null
          ? Text(
              account.displayName.characters.first.toUpperCase(),
              style: AppTextStyles.headline.copyWith(color: AppColors.primary),
            )
          : null,
    );
  }
}

class _RatingSummary extends StatelessWidget {
  const _RatingSummary({required this.summary});

  final BusinessRatingSummary summary;

  @override
  Widget build(BuildContext context) {
    if (!summary.hasRatings) {
      return Text(
        summary.countLabel,
        style: AppTextStyles.caption,
        textAlign: TextAlign.center,
      );
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      alignment: WrapAlignment.center,
      children: [
        Text(
          summary.averageLabel,
          style: AppTextStyles.bodyStrong.copyWith(color: AppColors.secondary),
        ),
        Text(summary.countLabel, style: AppTextStyles.caption),
      ],
    );
  }
}

class _RatingSummaryLoading extends StatelessWidget {
  const _RatingSummaryLoading();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Henüz değerlendirme yok.',
      style: AppTextStyles.caption,
      textAlign: TextAlign.center,
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(label, style: AppTextStyles.label),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactLine extends StatelessWidget {
  const _ContactLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: AppTextStyles.bodySmall)),
        ],
      ),
    );
  }
}
