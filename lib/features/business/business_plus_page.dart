import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/business_plus_products.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/error_view.dart';
import 'business_models.dart';
import 'business_plus_billing_provider.dart';
import 'business_provider.dart';

class BusinessPlusPage extends ConsumerStatefulWidget {
  const BusinessPlusPage({super.key});

  @override
  ConsumerState<BusinessPlusPage> createState() => _BusinessPlusPageState();
}

class _BusinessPlusPageState extends ConsumerState<BusinessPlusPage> {
  bool _isRefreshingStatus = false;
  String? _refreshMessage;
  DateTime? _lastRefreshTime;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(myBusinessAccountProvider.notifier).loadMyBusinessAccount();
      ref.read(businessPlusBillingProvider.notifier).loadProduct();
    });
  }

  @override
  Widget build(BuildContext context) {
    final businessState = ref.watch(myBusinessAccountProvider);
    final billingState = ref.watch(businessPlusBillingProvider);
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
            : _BusinessPlusContent(
                account: account,
                subscription: businessState.plusSubscription,
                billingState: billingState,
                isRefreshingStatus: _isRefreshingStatus,
                refreshMessage: _refreshMessage,
                onStartPurchase: () {
                  ref
                      .read(businessPlusBillingProvider.notifier)
                      .startPurchase();
                },
                onRestorePurchases: () {
                  ref
                      .read(businessPlusBillingProvider.notifier)
                      .restorePurchases();
                },
                onRefreshStatus: () {
                  _refreshStatus();
                },
                onManageSubscription: () {
                  _openGooglePlaySubscriptionPage();
                },
              ),
      ),
    );
  }

  Future<void> _refreshStatus() async {
    if (_isRefreshingStatus) return;
    if (_lastRefreshTime != null &&
        DateTime.now().difference(_lastRefreshTime!).inMinutes < 2) {
      setState(() {
        _refreshMessage = 'Durum kısa süre önce yenilendi.';
      });
      return;
    }

    setState(() {
      _isRefreshingStatus = true;
      _refreshMessage = null;
    });

    try {
      final result = await ref
          .read(businessPlusBillingProvider.notifier)
          .refreshSubscriptionStatus();
      await ref.read(businessPlusBillingProvider.notifier).loadProduct();
      if (!mounted) return;
      setState(() {
        _lastRefreshTime = DateTime.now();
        _refreshMessage = result.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _refreshMessage = 'Durum yenilenemedi. Lütfen tekrar deneyin.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingStatus = false;
        });
      }
    }
  }

  Future<void> _openGooglePlaySubscriptionPage() async {
    final uri = Uri.parse(
      'https://play.google.com/store/account/subscriptions'
      '?sku=${BusinessPlusProducts.monthlyProductId}&package=com.matchaman.app',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google Play abonelik sayfası açılamadı.'),
        ),
      );
    }
  }
}

class _BusinessPlusContent extends StatelessWidget {
  const _BusinessPlusContent({
    required this.account,
    required this.subscription,
    required this.billingState,
    required this.isRefreshingStatus,
    required this.refreshMessage,
    required this.onStartPurchase,
    required this.onRestorePurchases,
    required this.onRefreshStatus,
    required this.onManageSubscription,
  });

  final BusinessAccount account;
  final BusinessPlusSubscription? subscription;
  final BusinessPlusBillingState billingState;
  final bool isRefreshingStatus;
  final String? refreshMessage;
  final VoidCallback onStartPurchase;
  final VoidCallback onRestorePurchases;
  final VoidCallback onRefreshStatus;
  final VoidCallback onManageSubscription;

  @override
  Widget build(BuildContext context) {
    final isPlusActive =
        _subscriptionActiveValue(subscription) ?? account.isPlusActive;
    final priceLabel = billingState.priceLabel;
    final canStartPurchase = !isPlusActive && billingState.canStartPurchase;
    final canRestorePurchases = !isPlusActive && billingState.canRestore;
    final showManageButton =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

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
                  _StatusPill(text: _billingStatusText(billingState)),
                if (!isPlusActive && priceLabel != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Play fiyatı: $priceLabel',
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: AppColors.tertiary,
                    ),
                  ),
                ],
                if (!isPlusActive && billingState.message != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _BillingMessage(text: billingState.message!),
                ],
                const SizedBox(height: AppSpacing.lg),
                _SubscriptionStatusCard(
                  account: account,
                  subscription: subscription,
                  isRefreshing: isRefreshingStatus,
                  refreshMessage: refreshMessage,
                  onRefresh: onRefreshStatus,
                  onManageSubscription: showManageButton
                      ? onManageSubscription
                      : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                const _BenefitLine(
                  text: 'Daha ileri tarihlere etkinlik planlama özgürlüğü',
                ),
                const _BenefitLine(text: 'Ayda 30 etkinlik oluşturma hakkı'),
                const _BenefitLine(
                  text: 'Ayda 5 etkinliği 24 saat öne çıkarma hakkı',
                ),
                const _BenefitLine(
                  text: 'İşletmeni daha profesyonel sunan Plus görünümü',
                ),
                const _BenefitLine(
                  text: 'İşletme profilinde Business Plus ayrıcalıkları',
                ),
                const _BenefitLine(
                  text: 'Gelişmiş işletme özelliklerine erişim',
                ),
                const _BenefitLine(text: 'Profesyonel işletme görünümü'),
                const _BenefitLine(
                  text: 'Etkinlik yönetimi için gelişmiş işletme altyapısı',
                ),
                if (!isPlusActive) ...[
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: priceLabel == null
                        ? 'Business Plus’a Geç'
                        : 'Business Plus’a Geç - $priceLabel',
                    isLoading:
                        billingState.status ==
                            BusinessPlusBillingStatus.purchasing ||
                        billingState.status ==
                            BusinessPlusBillingStatus.verifying,
                    onPressed: canStartPurchase ? onStartPurchase : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Satın almayı geri yükle',
                    variant: AppButtonVariant.secondary,
                    onPressed: canRestorePurchases ? onRestorePurchases : null,
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

class _SubscriptionStatusCard extends StatelessWidget {
  const _SubscriptionStatusCard({
    required this.account,
    required this.subscription,
    required this.isRefreshing,
    required this.refreshMessage,
    required this.onRefresh,
    required this.onManageSubscription,
  });

  final BusinessAccount account;
  final BusinessPlusSubscription? subscription;
  final bool isRefreshing;
  final String? refreshMessage;
  final VoidCallback onRefresh;
  final VoidCallback? onManageSubscription;

  @override
  Widget build(BuildContext context) {
    final status = _subscriptionStatusText(account, subscription);
    final periodEnd = subscription?.currentPeriodEnd;
    final autoRenewEnabled = subscription?.autoRenewEnabled;
    final statusMessage = _subscriptionStatusMessage(subscription);
    final dateLabel = autoRenewEnabled == true
        ? 'Yenileme tarihi'
        : 'Bitiş tarihi';

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
          children: [
            Text('Abonelik durumu', style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.sm),
            _StatusRow(label: 'Durum', value: status),
            if (periodEnd != null)
              _StatusRow(
                label: dateLabel,
                value: _formatBusinessPlusDate(periodEnd),
              ),
            if (autoRenewEnabled != null)
              _StatusRow(
                label: 'Yenileme',
                value: autoRenewEnabled ? 'Yenileme açık' : 'Yenileme kapalı',
              ),
            if (statusMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(statusMessage, style: AppTextStyles.bodySmall),
            ],
            if (refreshMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _BillingMessage(text: refreshMessage!),
            ],
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Durumu yenile',
              variant: AppButtonVariant.secondary,
              isLoading: isRefreshing,
              onPressed: isRefreshing ? null : onRefresh,
            ),
            if (onManageSubscription != null) ...[
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Aboneliği Google Play’de yönet',
                variant: AppButtonVariant.secondary,
                onPressed: onManageSubscription,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(label, style: AppTextStyles.bodySmall),
          ),
          Expanded(child: Text(value, style: AppTextStyles.bodyStrong)),
        ],
      ),
    );
  }
}

class _BillingMessage extends StatelessWidget {
  const _BillingMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(text, style: AppTextStyles.bodySmall),
      ),
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

String _billingStatusText(BusinessPlusBillingState state) {
  switch (state.status) {
    case BusinessPlusBillingStatus.initial:
    case BusinessPlusBillingStatus.loading:
      return 'Ürün bilgisi yükleniyor';
    case BusinessPlusBillingStatus.available:
      return 'Satın alma hazır';
    case BusinessPlusBillingStatus.unavailable:
      return 'Satın alma şu anda kullanılamıyor';
    case BusinessPlusBillingStatus.unsupportedPlatform:
      return 'Satın alma bu platformda desteklenmiyor';
    case BusinessPlusBillingStatus.productNotFound:
      return 'Business Plus ürünü bulunamadı';
    case BusinessPlusBillingStatus.purchasing:
      return 'Satın alma açılıyor';
    case BusinessPlusBillingStatus.verifying:
      return 'Satın alma doğrulanıyor';
    case BusinessPlusBillingStatus.pending:
      return 'Satın alma beklemede';
    case BusinessPlusBillingStatus.verificationPending:
      return 'Doğrulama bekleniyor';
    case BusinessPlusBillingStatus.verifiedActive:
      return 'Business Plus aktif edildi';
    case BusinessPlusBillingStatus.error:
      return 'Satın alma tamamlanamıyor';
  }
}

String _subscriptionStatusText(
  BusinessAccount account,
  BusinessPlusSubscription? subscription,
) {
  if (subscription == null) {
    return account.isPlusActive ? 'Aktif' : 'Bilinmiyor';
  }
  if (subscription.isCanceledButActive) {
    return 'İptal edildi, dönem sonuna kadar aktif';
  }

  switch (subscription.entitlementStatus) {
    case 'active':
      return 'Aktif';
    case 'expired':
      return 'Süresi doldu';
    case 'billing_retry':
    case 'grace_period':
      return 'Ödeme sorunu / yenileme bekleniyor';
    case 'paused':
      return 'Yenileme beklemede';
    case 'cancelled':
      return subscription.hasFuturePeriodEnd
          ? 'İptal edildi, dönem sonuna kadar aktif'
          : 'Süresi doldu';
    default:
      return 'Bilinmiyor';
  }
}

bool? _subscriptionActiveValue(BusinessPlusSubscription? subscription) {
  if (subscription == null) return null;
  if (subscription.isCanceledButActive) return true;
  switch (subscription.entitlementStatus) {
    case 'active':
    case 'grace_period':
      return subscription.currentPeriodEnd == null ||
          subscription.currentPeriodEnd!.isAfter(DateTime.now());
    default:
      return false;
  }
}

String? _subscriptionStatusMessage(BusinessPlusSubscription? subscription) {
  if (subscription == null) return null;
  if (subscription.isCanceledButActive) {
    return 'Aboneliğin iptal edilmiş. Business Plus, ödenmiş dönem bitene kadar aktif kalır.';
  }
  if (subscription.entitlementStatus == 'expired') {
    return 'Business Plus süren dolmuş. Tekrar abone olarak ayrıcalıkları yeniden açabilirsin.';
  }
  return null;
}

String _formatBusinessPlusDate(DateTime value) {
  final local = value.toLocal();
  return '${_twoDigits(local.day)}.${_twoDigits(local.month)}.${local.year} '
      '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

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
