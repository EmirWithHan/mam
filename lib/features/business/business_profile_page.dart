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
import '../profile/profile_badges.dart';

import 'business_customization_page.dart';

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
          tooltip: 'Geri',
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
              ErrorView(message: 'İşletme profili yüklenemedi.'),
          data: (account) {
            if (account == null) {
              return const ErrorView(message: 'İşletme profili bulunamadı.');
            }
            final isOwner = account.ownerUserId == authState.userId;
            if (!account.isPubliclyVisible && !isOwner) {
              return const ErrorView(message: 'İşletme profili yayında değil.');
            }
            if (!isOwner) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;
                context.goNamed(
                  RouteNames.publicProfile,
                  pathParameters: {'userId': account.ownerUserId},
                );
              });
              return const AppLoader();
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
            title: 'Hakkında',
            child: Text(account.description!, style: AppTextStyles.body),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _SectionCard(
          title: 'İletişim',
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
                Text('İletişim bilgisi eklenmemiş.', style: AppTextStyles.body),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _BusinessBadgesSection(businessId: account.id),
        if (isOwner) ...[
          const SizedBox(height: AppSpacing.lg),
          _SubscriptionStatusCard(account: account),
          const SizedBox(height: AppSpacing.lg),
          _SectionCard(
            title: 'Özelleştirme ve Düzenleme',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppButton(
                  label: 'Profili Özelleştir',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          BusinessCustomizationPage(account: account),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'İşletmeyi Düzenle',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => context.pushNamed(RouteNames.businessCreate),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionCard(
            title: 'İstatistikler',
            child: AppButton(
              label: 'İstatistikler ve Analiz',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BusinessStatsPage(account: account),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SubscriptionStatusCard extends StatelessWidget {
  const _SubscriptionStatusCard({required this.account});

  final BusinessAccount account;

  static const String _businessPlusPrice = '499 TL / ay';

  @override
  Widget build(BuildContext context) {
    final isPlus = account.isPlusActive;

    return Card(
      elevation: 0,
      color: isPlus
          ? AppColors.tertiary.withValues(alpha: 0.15)
          : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.xlBorder,
        side: BorderSide(
          color: isPlus ? AppColors.tertiary : AppColors.border,
          width: isPlus ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isPlus ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: isPlus ? AppColors.tertiary : Colors.grey,
                  size: 28,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  isPlus
                      ? 'Business Plus Aktif ✦'
                      : 'Business Plus (Plus aktif değil)',
                  style: AppTextStyles.title.copyWith(
                    color: isPlus ? AppColors.textPrimary : AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (isPlus) ...[
              const _PlusBenefitLine(
                text: 'Ayda 30 etkinlik oluşturma hakkı (Kalan: Limitsiz)',
              ),
              const _PlusBenefitLine(text: 'Ayda 5 öne çıkarma hakkı'),
              const _PlusBenefitLine(
                text:
                    'Etkinlik ve işletme aramalarında üst sıralarda listelenme',
              ),
              const _PlusBenefitLine(text: 'Sponsorlu işletme rozeti aktif'),
              const _PlusBenefitLine(text: 'Öncelikli destek rozeti aktif'),
            ] else ...[
              Text(
                'İşletmenizi bir üst seviyeye taşımak için Business Plus\'a geçin!',
                style: AppTextStyles.bodyStrong,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Fiyat: $_businessPlusPrice',
                style: AppTextStyles.bodyStrong.copyWith(
                  color: AppColors.tertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const _PlusBenefitLine(text: 'Daha fazla görünürlük'),
              const _PlusBenefitLine(
                text: 'Etkinliklerini öne çıkarma altyapısı',
              ),
              const _PlusBenefitLine(text: 'QR katılım raporları'),
              const _PlusBenefitLine(text: 'Gelişmiş işletme istatistikleri'),
              const _PlusBenefitLine(text: 'Katılımcı dönüşüm verileri'),
              const _PlusBenefitLine(
                text: 'Popüler işletme ve güven rozetleri',
              ),
              const _PlusBenefitLine(text: 'Daha profesyonel işletme profili'),
              const _PlusBenefitLine(
                text: 'Gelecekte kampanya/öne çıkarma özelliklerine hazırlık',
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Plus\'a Geç',
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Business Plus'),
                      content: const Text(
                        'Business Plus satın alma yakında aktif olacak.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Tamam'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlusBenefitLine extends StatelessWidget {
  const _PlusBenefitLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
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

class _BusinessBadgesSection extends ConsumerWidget {
  const _BusinessBadgesSection({required this.businessId});

  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesAsync = ref.watch(businessBadgesProvider(businessId));

    return badgesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: AppLoader(),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (List<ProfileBadge> badges) {
        if (badges.isEmpty) return const SizedBox.shrink();

        final earnedCount = badges.where((b) => b.isEarned).length;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: AppRadius.lgBorder,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('İşletme Rozetleri', style: AppTextStyles.title),
                    Text(
                      '$earnedCount/${badges.length} Kazanıldı',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: badges.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                    mainAxisExtent: 105,
                  ),
                  itemBuilder: (context, index) {
                    final badge = badges[index];
                    final isEarned = badge.isEarned;
                    final color = isEarned
                        ? AppColors.primary
                        : AppColors.textMuted;

                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: isEarned
                            ? AppColors.primarySoft
                            : AppColors.background,
                        border: Border.all(
                          color: isEarned
                              ? AppColors.primary.withValues(alpha: 0.18)
                              : AppColors.border,
                        ),
                        borderRadius: AppRadius.mdBorder,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(badge.icon, color: color, size: 24),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              badge.label,
                              style: AppTextStyles.bodyStrong.copyWith(
                                color: isEarned
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                fontSize: 11,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              badge.description,
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 9,
                                color: AppColors.textMuted,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
