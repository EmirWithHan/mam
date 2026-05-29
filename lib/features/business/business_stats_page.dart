import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/error_view.dart';
import 'business_models.dart';
import 'business_stats_models.dart';
import 'business_stats_provider.dart';

class BusinessStatsPage extends ConsumerWidget {
  const BusinessStatsPage({super.key, required this.account});

  final BusinessAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(businessStatsProvider(account.id));

    return Scaffold(
      appBar: AppBar(title: const AppLogo(size: 32, showText: true)),
      body: SafeArea(
        child: statsAsync.when(
          loading: () => const AppLoader(),
          error: (error, _) => ErrorView(
            message: 'İstatistikler yüklenemedi.',
            onRetry: () => ref.invalidate(businessStatsProvider(account.id)),
          ),
          data: (stats) => _BusinessStatsBody(account: account, stats: stats),
        ),
      ),
    );
  }
}

class _BusinessStatsBody extends StatelessWidget {
  const _BusinessStatsBody({required this.account, required this.stats});

  final BusinessAccount account;
  final BusinessStats stats;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(account.displayName, style: AppTextStyles.headline),
        const SizedBox(height: AppSpacing.xs),
        Text('İstatistikler', style: AppTextStyles.caption),
        if (stats.isEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const _EmptyStatsCard(),
        ],
        const SizedBox(height: AppSpacing.lg),
        GridView.count(
          crossAxisCount: MediaQuery.sizeOf(context).width > 520 ? 3 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1.35,
          children: [
            _StatTile(label: 'Toplam Etkinlik', value: '${stats.totalEvents}'),
            _StatTile(
              label: 'Yaklaşan Etkinlik',
              value: '${stats.upcomingEvents}',
            ),
            _StatTile(
              label: 'Toplam İstek',
              value: '${stats.totalJoinRequests}',
            ),
            _StatTile(
              label: 'Onaylı Katılımcı',
              value: '${stats.confirmedParticipants}',
            ),
            _StatTile(label: 'Check-in', value: '${stats.checkedInCount}'),
            _StatTile(label: 'Gelmedi', value: '${stats.noShowCount}'),
            _StatTile(label: 'Ortalama Puan', value: stats.averageRatingLabel),
            _StatTile(
              label: 'Sponsorlu Etkinlik',
              value: '${stats.sponsoredEventsCount}',
            ),
          ],
        ),
      ],
    );
  }
}

class _EmptyStatsCard extends StatelessWidget {
  const _EmptyStatsCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.lgBorder,
      ),
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Text('Henüz istatistik yok.', style: AppTextStyles.body),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.lgBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: AppTextStyles.headline.copyWith(color: AppColors.primary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: AppTextStyles.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
