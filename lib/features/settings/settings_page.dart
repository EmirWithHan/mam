import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/layout/responsive_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/phone_verification.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_logo.dart';
import '../auth/auth_provider.dart';
import '../business/business_models.dart';
import '../business/business_provider.dart';
import '../business/widgets/business_badge.dart';
import '../events/events_provider.dart';
import '../profile/profile_models.dart';
import '../profile/profile_provider.dart';
import 'widgets/settings_menu_tile.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(profileControllerProvider.notifier).loadMyProfile();
      ref.read(myBusinessAccountProvider.notifier).loadMyBusinessAccount();
      ref
          .read(myBusinessAccountProvider.notifier)
          .startApplicationRealtime(ref.read(authControllerProvider).userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileControllerProvider).profile;
    final profileState = ref.watch(profileControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final businessState = ref.watch(myBusinessAccountProvider);
    final businessAccount = businessState.account;
    final businessApplication = businessState.application;
    final isBusinessMode = profile?.isBusinessAccount == true;

    return Scaffold(
      appBar: AppBar(
        title: const AppLogo(size: 32, showText: true),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.goNamed(RouteNames.profile);
          },
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: AppResponsive.pagePadding(context),
          children: [
            Text('Ayarlar', style: AppTextStyles.headline),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Hesap ayarlarınızı ve tercihlerinizi buradan yönetin.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.lg),
            _SettingsUserCard(profile: profile),
            const SizedBox(height: AppSpacing.md),
            _PhoneVerificationTile(profile: profile),
            const SizedBox(height: AppSpacing.lg),
            _PrivacySection(
              profile: profile,
              isLoading: profileState.isLoading,
              onChanged: (value) async {
                final success = await ref
                    .read(profileControllerProvider.notifier)
                    .updatePrivacy(isPrivate: value);
                if (!context.mounted) return;
                if (!success) {
                  final message = ref.read(profileControllerProvider).message;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(message ?? 'İşlem tamamlanamadı.')),
                  );
                  return;
                }
                final userId = ref
                    .read(profileControllerProvider)
                    .profile
                    ?.userId;
                if (userId != null) {
                  ref.invalidate(publicProfileDetailProvider(userId));
                  ref.invalidate(publicProfileGalleryProvider(userId));
                  ref.invalidate(publicProfileEventHistoryProvider(userId));
                }
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            SettingsMenuTile(
              icon: isBusinessMode
                  ? Icons.storefront_outlined
                  : Icons.person_outline,
              title: isBusinessMode
                  ? 'İşletme hesabını düzenle'
                  : 'Kullanıcı hesabını düzenle',
              subtitle: isBusinessMode
                  ? 'İşletme bilgilerini güncelle'
                  : 'Oyuncu kartı bilgilerini güncelle',
              onTap: () {
                if (!isBusinessMode) {
                  context.pushNamed(RouteNames.profileComplete);
                  return;
                }
                if (businessAccount == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('İşletme hesabı bilgileri eksik.'),
                    ),
                  );
                  return;
                }
                context.pushNamed(RouteNames.businessCreate);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            SettingsMenuTile(
              icon: Icons.verified_user_outlined,
              title: 'Güven puanı',
              subtitle: 'Güven puanı geçmişini görüntüle',
              onTap: () => context.pushNamed(RouteNames.trustScoreHistory),
            ),
            const SizedBox(height: AppSpacing.md),
            SettingsMenuTile(
              icon: Icons.rate_review_outlined,
              title: 'Geri bildirim gönder',
              subtitle: 'Deneyimini ve önerilerini paylaş',
              onTap: () => context.pushNamed(RouteNames.feedback),
            ),
            const SizedBox(height: AppSpacing.md),
            SettingsMenuTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Gizlilik Politikası',
              subtitle: 'MVP gizlilik özeti ve veri kullanımı',
              onTap: () => context.pushNamed(RouteNames.privacyPolicy),
            ),
            const SizedBox(height: AppSpacing.md),
            SettingsMenuTile(
              icon: Icons.description_outlined,
              title: 'Kullanım Şartları',
              subtitle: 'Uygulama kuralları ve kullanıcı sorumlulukları',
              onTap: () => context.pushNamed(RouteNames.termsOfUse),
            ),
            const SizedBox(height: AppSpacing.md),
            SettingsMenuTile(
              icon: Icons.groups_outlined,
              title: 'Topluluk Kuralları',
              subtitle: 'Güvenli ve saygılı etkinlik topluluğu',
              onTap: () => context.pushNamed(RouteNames.communityGuidelines),
            ),
            const SizedBox(height: AppSpacing.md),
            SettingsMenuTile(
              icon: Icons.health_and_safety_outlined,
              title: 'Etkinlik Güvenliği ve Sorumluluk Reddi',
              subtitle:
                  'Etkinliklere katılım riskleri ve kullanıcı sorumlulukları',
              onTap: () => context.pushNamed(RouteNames.eventSafetyDisclaimer),
            ),
            const SizedBox(height: AppSpacing.md),
            SettingsMenuTile(
              icon: Icons.support_agent_outlined,
              title: 'Bize Ulaş / Destek',
              subtitle: 'Geri bildirim, güvenlik ve hesap talepleri',
              onTap: () => context.pushNamed(RouteNames.support),
            ),
            const SizedBox(height: AppSpacing.md),
            if (!isBusinessMode)
              SettingsMenuTile(
                icon: Icons.storefront_outlined,
                title: BusinessSettingsCopy.actionTitle(
                  isBusinessAccount: isBusinessMode,
                  application: businessApplication,
                ),
                subtitle: BusinessSettingsCopy.actionSubtitle(
                  isBusinessAccount: isBusinessMode,
                  account: businessAccount,
                  application: businessApplication,
                ),
                trailing: businessAccount == null
                    ? null
                    : BusinessBadge(isVerified: businessAccount.isVerified),
                onTap: () {
                  if (businessApplication?.isPending == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('İşletme başvurun inceleniyor.'),
                      ),
                    );
                    return;
                  }
                  context.pushNamed(RouteNames.businessCreate);
                },
              ),
            if (isBusinessMode) ...[
              const SizedBox(height: AppSpacing.md),
              SettingsMenuTile(
                icon: Icons.delete_outline,
                title: 'İşletme hesabımı sil',
                subtitle: 'İşletme modunu pasifleştir',
                onTap: businessState.isLoading
                    ? null
                    : () => _confirmDeleteBusinessAccount(context),
              ),
            ],
            if (businessState.isAdmin) ...[
              const SizedBox(height: AppSpacing.md),
              SettingsMenuTile(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Yönetici',
                subtitle: 'İşletme başvurularını incele',
                onTap: () => context.pushNamed(RouteNames.admin),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            SettingsMenuTile(
              icon: Icons.block_outlined,
              title: 'Engellenenler',
              subtitle: 'Engellediğin kullanıcıları yönet',
              onTap: () => context.pushNamed(RouteNames.blockedUsers),
            ),
            const SizedBox(height: AppSpacing.md),
            SettingsMenuTile(
              icon: Icons.delete_forever_outlined,
              title: 'Hesabımı sil',
              subtitle: 'Profilini pasifleştir ve silme talebi oluştur',
              onTap: profileState.isLoading
                  ? null
                  : () => _confirmDeleteAccount(context),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Çıkış Yap',
              isLoading: authState.isLoading,
              variant: AppButtonVariant.outlined,
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

  Future<void> _confirmDeleteBusinessAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('İşletme hesabını sil?'),
          content: const Text(
            'İşletme bilgilerin pasifleştirilecek ve gelecekteki işletme '
            'etkinliklerin yayından kaldırılacak. Hesabın kullanıcı hesabı '
            'olarak devam edecek.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgeç'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('İşletme hesabımı sil'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final success = await ref
        .read(myBusinessAccountProvider.notifier)
        .deleteMyBusinessAccount();
    if (!context.mounted) return;

    if (!success) {
      final message = ref.read(myBusinessAccountProvider).message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message ?? 'İşletme hesabı silinemedi. Tekrar dene.'),
        ),
      );
      return;
    }

    await ref.read(profileControllerProvider.notifier).loadMyProfile();
    final profile = ref.read(profileControllerProvider).profile;
    ref
        .read(authControllerProvider.notifier)
        .markProfileCompletion(isCompleted: profile?.hasCoreIdentity ?? false);
    await ref.read(myBusinessAccountProvider.notifier).loadMyBusinessAccount();
    await ref.read(eventsControllerProvider.notifier).refreshEvents();
    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('İşletme hesabı silindi.')));
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => const _AccountDeletionConfirmationDialog(),
    );

    if (confirmed != true) return;

    final success = await ref
        .read(profileControllerProvider.notifier)
        .requestAccountDeletion();
    if (!context.mounted) return;

    if (!success) {
      final message = ref.read(profileControllerProvider).message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message ?? 'Hesap silme talebi alınamadı. Tekrar dene.',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hesap silme talebin alındı.')),
    );
    await ref.read(authControllerProvider.notifier).signOut();
    if (context.mounted) context.goNamed(RouteNames.auth);
  }
}

class AccountDeletionConfirmation {
  const AccountDeletionConfirmation._();

  static const confirmationText = 'SİL';

  static bool isConfirmed(String value) {
    return value.trim().toUpperCase() == confirmationText;
  }
}

class _AccountDeletionConfirmationDialog extends StatefulWidget {
  const _AccountDeletionConfirmationDialog();

  @override
  State<_AccountDeletionConfirmationDialog> createState() =>
      _AccountDeletionConfirmationDialogState();
}

class _AccountDeletionConfirmationDialogState
    extends State<_AccountDeletionConfirmationDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmed = AccountDeletionConfirmation.isConfirmed(
      _controller.text,
    );

    return AlertDialog(
      title: const Text('Hesabını sil?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profilin pasifleştirilecek, herkese açık kimliğin gizlenecek ve '
            'gelecekteki etkinliklerin yayından kaldırılacak. Nihai veri silme '
            'işlemi beta sürecinde manuel olarak tamamlanır.',
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('Devam etmek için SİL yaz.'),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: 'SİL'),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Vazgeç'),
        ),
        TextButton(
          onPressed: isConfirmed ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Hesabımı sil'),
        ),
      ],
    );
  }
}

class _PhoneVerificationTile extends StatelessWidget {
  const _PhoneVerificationTile({required this.profile});

  final Profile? profile;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.lgBorder,
      ),
      child: ListTile(
        leading: Icon(
          PhoneVerification.isPhoneVerified(profile)
              ? Icons.verified_outlined
              : Icons.phone_android_outlined,
          color: AppColors.primary,
        ),
        title: Text('Telefon doğrulama', style: AppTextStyles.bodyStrong),
        subtitle: Text(PhoneVerification.statusLabel(profile)),
        trailing: TextButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Telefon doğrulama yakında eklenecek.'),
              ),
            );
          },
          child: const Text('Telefonu doğrula'),
        ),
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection({
    required this.profile,
    required this.isLoading,
    required this.onChanged,
  });

  final Profile? profile;
  final bool isLoading;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isPrivate = profile?.isPrivate ?? false;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.lgBorder,
      ),
      child: SwitchListTile.adaptive(
        value: isPrivate,
        onChanged: isLoading || profile == null ? null : onChanged,
        activeThumbColor: AppColors.primary,
        secondary: const Icon(Icons.lock_outline, color: AppColors.primary),
        title: Text('Gizli hesap', style: AppTextStyles.bodyStrong),
        subtitle: const Text(
          'Gizli hesapta galeri ve geçmiş etkinlikler sadece takipçilerine görünür.',
        ),
      ),
    );
  }
}

class _SettingsUserCard extends StatelessWidget {
  const _SettingsUserCard({required this.profile});

  final Profile? profile;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.xlBorder,
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
        child: Row(
          children: [
            _Avatar(profile: profile),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_displayName(), style: AppTextStyles.title),
                  const SizedBox(height: AppSpacing.xs),
                  Text(_displayHandle(), style: AppTextStyles.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _displayName() {
    final firstName = profile?.firstName?.trim();
    final name = [
      firstName,
    ].where((part) => part != null && part.isNotEmpty).join(' ');
    return name.isNotEmpty ? name : 'Match A Man kullanıcısı';
  }

  String _displayHandle() {
    final username = profile?.username?.trim();
    final tag = profile?.tag?.trim();
    if (username != null &&
        username.isNotEmpty &&
        tag != null &&
        tag.isNotEmpty) {
      return '$username#$tag';
    }
    if (username != null && username.isNotEmpty) return username;
    return 'Profil bilgileri';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile});

  final Profile? profile;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile?.avatarUrl;

    return CircleAvatar(
      radius: 30,
      backgroundColor: AppColors.primarySoft,
      backgroundImage: avatarUrl == null || avatarUrl.trim().isEmpty
          ? null
          : NetworkImage(avatarUrl),
      child: avatarUrl == null || avatarUrl.trim().isEmpty
          ? const Icon(Icons.person, color: AppColors.primary, size: 30)
          : null,
    );
  }
}
