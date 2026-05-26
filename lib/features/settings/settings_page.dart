import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_logo.dart';
import '../auth/auth_provider.dart';
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
      ref.read(profileControllerProvider.notifier).loadMyProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileControllerProvider).profile;
    final profileState = ref.watch(profileControllerProvider);
    final authState = ref.watch(authControllerProvider);

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
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Ayarlar', style: AppTextStyles.headline),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Hesap ayarlarınızı ve tercihlerinizi buradan yönetin.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.lg),
            _SettingsUserCard(profile: profile),
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
              icon: Icons.person_outline,
              title: 'Profili Düzenle',
              subtitle: 'Oyuncu kartı bilgilerini güncelle',
              onTap: () => context.pushNamed(RouteNames.profileComplete),
            ),
            const SizedBox(height: AppSpacing.md),
            SettingsMenuTile(
              icon: Icons.verified_user_outlined,
              title: 'Trust Score',
              subtitle: 'Güven puanı geçmişini görüntüle',
              onTap: () => context.pushNamed(RouteNames.trustScoreHistory),
            ),
            const SizedBox(height: AppSpacing.md),
            const SettingsMenuTile(
              icon: Icons.tune,
              title: 'Ayarlar',
              subtitle: 'Tercihler yakında burada olacak',
              trailing: Text('Yakında', style: AppTextStyles.caption),
            ),
            const SizedBox(height: AppSpacing.md),
            SettingsMenuTile(
              icon: Icons.block_outlined,
              title: 'Engellenenler',
              subtitle: 'Engellediğin kullanıcıları yönet',
              onTap: () => context.pushNamed(RouteNames.blockedUsers),
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
          'Gizli hesapta galeri ve Geçmiş Events sadece takipçilerine görünür.',
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
                  Text(_displayName(profile), style: AppTextStyles.title),
                  const SizedBox(height: AppSpacing.xs),
                  Text(_displayHandle(profile), style: AppTextStyles.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _displayName(Profile? profile) {
    final firstName = profile?.firstName?.trim();
    final name = [
      firstName,
    ].where((part) => part != null && part.isNotEmpty).join(' ');
    return name.isNotEmpty ? name : 'MaM Kullanıcısı';
  }

  String _displayHandle(Profile? profile) {
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
