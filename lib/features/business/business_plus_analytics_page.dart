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
import 'business_models.dart';
import 'business_plus_analytics_models.dart';
import 'business_plus_analytics_provider.dart';

class BusinessPlusAnalyticsPage extends ConsumerWidget {
  const BusinessPlusAnalyticsPage({super.key, required this.account});

  final BusinessAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlusActive = account.isPlusActive;

    if (!isPlusActive) {
      return Scaffold(
        appBar: AppBar(title: const AppLogo(size: 32, showText: true)),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: AppColors.tertiary,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Business Plus Analizleri',
                  style: AppTextStyles.headline,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Business Plus analizleri aktif Business Plus hesaplara özeldir. Business Plus’a geçerek detaylı etkinlik analizlerini, katılımcı yoklama oranlarını ve öne çıkarma istatistiklerini görüntüleyebilirsiniz.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Business Plus Satın Al',
                  onPressed: () => context.pushNamed(RouteNames.businessPlus),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Geri Dön',
                  variant: AppButtonVariant.outlined,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final analyticsAsync = ref.watch(businessPlusAnalyticsProvider(account.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Business Plus Analizleri')),
      body: SafeArea(
        child: analyticsAsync.when(
          loading: () => const AppLoader(),
          error: (error, _) => ErrorView(
            message: 'Analizler yüklenemedi.',
            onRetry: () =>
                ref.invalidate(businessPlusAnalyticsProvider(account.id)),
          ),
          data: (analytics) {
            if (analytics.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.bar_chart_outlined,
                      size: 64,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Henüz analiz oluşturacak veri yok.',
                      style: AppTextStyles.headline,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Analizleri görüntülemek için öncelikle işletme hesabı üzerinden etkinlik oluşturmanız gerekmektedir.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: 'Geri Dön',
                      variant: AppButtonVariant.outlined,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              );
            }

            return _AnalyticsBody(analytics: analytics);
          },
        ),
      ),
    );
  }
}

class _AnalyticsBody extends StatelessWidget {
  const _AnalyticsBody({required this.analytics});

  final BusinessPlusAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1.4,
          children: [
            _SummaryCard(
              label: 'Etkinlikler',
              value: '${analytics.totalEvents}',
              subtitle:
                  '${analytics.upcomingEvents} aktif / ${analytics.pastEvents} geçmiş',
              icon: Icons.calendar_month,
              iconColor: AppColors.primary,
            ),
            _SummaryCard(
              label: 'Katılımcılar',
              value: '${analytics.totalParticipants}',
              subtitle: '${analytics.totalCheckedIn} katılım onaylı',
              icon: Icons.people_outline,
              iconColor: AppColors.secondary,
            ),
            _SummaryCard(
              label: 'Yoklama oranı',
              value: '%${analytics.attendanceRate}',
              subtitle:
                  'Gelmeyen: ${analytics.totalParticipants - analytics.totalCheckedIn}',
              icon: Icons.qr_code_scanner,
              iconColor: AppColors.success,
            ),
            _SummaryCard(
              label: 'Öne çıkarma hakkı',
              value: '${analytics.monthlyBoostsRemaining}/5',
              subtitle:
                  '${analytics.activeBoosts} aktif / ${analytics.expiredBoosts} geçmiş',
              icon: Icons.star,
              iconColor: AppColors.tertiary,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _BoostUsageSection(analytics: analytics),
        const SizedBox(height: AppSpacing.lg),
        _TopEventsSection(topEvents: analytics.topEvents),
        const SizedBox(height: AppSpacing.lg),
        _RecentPerformanceSection(recentEvents: analytics.recentEvents),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: AppTextStyles.caption),
                Icon(icon, color: iconColor, size: 20),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: AppTextStyles.headline),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BoostUsageSection extends StatelessWidget {
  const _BoostUsageSection({required this.analytics});

  final BusinessPlusAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgBorder,
        side: const BorderSide(color: AppColors.border),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.star, color: AppColors.tertiary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Öne Çıkarma İstatistikleri',
                  style: AppTextStyles.bodyStrong,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _StatsRow(
              label: 'Bu ay kullanılan öne çıkarma hakkı',
              value: '${analytics.monthlyBoostsUsed}/5',
            ),
            const Divider(color: AppColors.border, height: AppSpacing.lg),
            _StatsRow(
              label: 'Kalan hak',
              value: '${analytics.monthlyBoostsRemaining}/5',
              valueColor: AppColors.tertiary,
            ),
            const Divider(color: AppColors.border, height: AppSpacing.lg),
            _StatsRow(
              label: 'Aktif öne çıkarılan etkinlik sayısı',
              value: '${analytics.activeBoosts}',
            ),
          ],
        ),
      ),
    );
  }
}

class _TopEventsSection extends StatelessWidget {
  const _TopEventsSection({required this.topEvents});

  final List<BusinessPlusTopEvent> topEvents;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgBorder,
        side: const BorderSide(color: AppColors.border),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.trending_up, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text('En Popüler Etkinlikler', style: AppTextStyles.bodyStrong),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (topEvents.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text(
                  'Henüz katılımcısı olan etkinlik yok.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: topEvents.length,
                separatorBuilder: (_, index) => const Divider(
                  color: AppColors.border,
                  height: AppSpacing.lg,
                ),
                itemBuilder: (context, index) {
                  final event = topEvents[index];
                  return Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.1,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              style: AppTextStyles.bodyStrong,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDate(event.eventDate),
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${event.participantCount} Katılımcı',
                            style: AppTextStyles.bodyStrong,
                          ),
                          if (event.participantCount > 0)
                            Text(
                              '${event.checkInCount} Giriş yapıldı',
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.success,
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _RecentPerformanceSection extends StatelessWidget {
  const _RecentPerformanceSection({required this.recentEvents});

  final List<BusinessPlusRecentEvent> recentEvents;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgBorder,
        side: const BorderSide(color: AppColors.border),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: AppColors.secondary),
                const SizedBox(width: AppSpacing.sm),
                Text('Son Performans Özeti', style: AppTextStyles.bodyStrong),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (recentEvents.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text(
                  'Henüz geçmiş etkinlik bulunmuyor.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentEvents.length,
                separatorBuilder: (_, index) => const Divider(
                  color: AppColors.border,
                  height: AppSpacing.lg,
                ),
                itemBuilder: (context, index) {
                  final event = recentEvents[index];
                  final checkInRate = event.participantCount > 0
                      ? ((event.checkInCount * 100) / event.participantCount)
                            .round()
                      : 0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              event.title,
                              style: AppTextStyles.bodyStrong,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            _formatDate(event.eventDate),
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _PerformanceBadge(
                            label: 'Giriş: %$checkInRate',
                            color: AppColors.success.withValues(alpha: 0.1),
                            textColor: AppColors.success,
                          ),
                          _PerformanceBadge(
                            label: 'Katılımcı: ${event.participantCount}',
                            color: AppColors.primary.withValues(alpha: 0.1),
                            textColor: AppColors.primary,
                          ),
                          _PerformanceBadge(
                            label: 'Başvuru: ${event.joinRequestsCount}',
                            color: AppColors.secondary.withValues(alpha: 0.1),
                            textColor: AppColors.secondary,
                          ),
                          _PerformanceBadge(
                            label: 'Gelmedi: ${event.noShowCount}',
                            color: AppColors.error.withValues(alpha: 0.1),
                            textColor: AppColors.error,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _PerformanceBadge extends StatelessWidget {
  const _PerformanceBadge({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodyStrong.copyWith(
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year;
  return '$day.$month.$year';
}
