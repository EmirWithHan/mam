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
import '../business/business_models.dart';
import '../business/business_provider.dart';
import '../business/widgets/business_badge.dart';
import 'profile_activity_provider.dart';
import 'profile_models.dart';
import 'profile_provider.dart';
import 'widgets/profile_badges_section.dart';
import 'widgets/profile_event_list.dart';
import 'widgets/profile_gallery_grid.dart';
import 'widgets/safe_avatar.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  var _selectedTab = _ProfileActivityTab.gallery;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(profileControllerProvider.notifier).loadMyProfile();
      ref.read(profileActivityControllerProvider.notifier).loadActivity();
      ref.read(myBusinessAccountProvider.notifier).loadMyBusinessAccount();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const AppLogo(size: 32, showText: true),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => context.pushNamed(RouteNames.settings),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: _ProfileBody(
            profileState: profileState,
            selectedTab: _selectedTab,
            onTabSelected: (tab) => setState(() => _selectedTab = tab),
          ),
        ),
      ),
    );
  }
}

enum _ProfileActivityTab { gallery, events }

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({
    required this.profileState,
    required this.selectedTab,
    required this.onTabSelected,
  });

  final ProfileState profileState;
  final _ProfileActivityTab selectedTab;
  final ValueChanged<_ProfileActivityTab> onTabSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (profileState.isLoading) {
      return const AppLoader();
    }

    if (profileState.status == ProfileStatus.error) {
      return ErrorView(message: profileState.message ?? 'Profil yüklenemedi.');
    }

    final profile = profileState.profile;
    if (profile == null) {
      return _ProfileEmptyState();
    }
    final activityState = ref.watch(profileActivityControllerProvider);
    final publicDetailAsync = ref.watch(
      publicProfileDetailProvider(profile.userId),
    );
    final badgesAsync = ref.watch(profileBadgesProvider(profile.userId));
    final businessAccount = ref.watch(myBusinessAccountProvider).account;

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(profileControllerProvider.notifier).refreshMyProfile();
        await ref.read(profileActivityControllerProvider.notifier).refresh();
        ref.invalidate(publicProfileDetailProvider(profile.userId));
      },
      child: ListView(
        children: [
          _ProfileHeader(
            profile: profile,
            publicDetail: publicDetailAsync.valueOrNull,
            businessAccount: businessAccount,
          ),
          const SizedBox(height: AppSpacing.lg),
          ProfileBadgesSection.fromAsync(badgesAsync),
          const SizedBox(height: AppSpacing.lg),
          _ProfileActivityTabs(
            selectedTab: selectedTab,
            onTabSelected: onTabSelected,
          ),
          const SizedBox(height: AppSpacing.md),
          _ProfileActivityContent(
            selectedTab: selectedTab,
            activityState: activityState,
            onRetry: () =>
                ref.read(profileActivityControllerProvider.notifier).refresh(),
          ),
        ],
      ),
    );
  }
}

class _ProfileActivityTabs extends StatelessWidget {
  const _ProfileActivityTabs({
    required this.selectedTab,
    required this.onTabSelected,
  });

  final _ProfileActivityTab selectedTab;
  final ValueChanged<_ProfileActivityTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.pillBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Row(
          children: [
            _ProfileActivityTabButton(
              label: 'Galeri',
              selected: selectedTab == _ProfileActivityTab.gallery,
              onPressed: () => onTabSelected(_ProfileActivityTab.gallery),
            ),
            _ProfileActivityTabButton(
              label: 'Geçmiş Events',
              selected: selectedTab == _ProfileActivityTab.events,
              onPressed: () => onTabSelected(_ProfileActivityTab.events),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileActivityTabButton extends StatelessWidget {
  const _ProfileActivityTabButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: selected ? AppColors.primary : Colors.transparent,
          foregroundColor: selected ? AppColors.surface : AppColors.textMuted,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.label.copyWith(
            color: selected ? AppColors.surface : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _ProfileActivityContent extends StatelessWidget {
  const _ProfileActivityContent({
    required this.selectedTab,
    required this.activityState,
    required this.onRetry,
  });

  final _ProfileActivityTab selectedTab;
  final ProfileActivityState activityState;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (activityState.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: AppLoader(),
      );
    }

    if (activityState.status == ProfileActivityStatus.error) {
      return ErrorView(
        message: activityState.message ?? 'Profil aktivitesi yüklenemedi.',
        onRetry: onRetry,
      );
    }

    if (selectedTab == _ProfileActivityTab.events) {
      return ProfileEventList(events: activityState.events);
    }

    return ProfileGalleryGrid(posts: activityState.galleryPosts);
  }
}

class ProfileIncompleteGuidanceUnused extends StatelessWidget {
  const ProfileIncompleteGuidanceUnused({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.lgBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.assignment_ind_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text('Profilini tamamla', style: AppTextStyles.title),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Etkinlik oluşturmak ve katılım isteği göndermek için temel profil bilgilerini tamamlamalısın.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Profili tamamla',
              onPressed: () => context.pushNamed(RouteNames.profileComplete),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.publicDetail,
    required this.businessAccount,
  });

  final Profile profile;
  final PublicProfileDetail? publicDetail;
  final BusinessAccount? businessAccount;

  @override
  Widget build(BuildContext context) {
    final isBusinessIdentity =
        profile.isBusinessAccount && businessAccount != null;
    final avatarUrl = isBusinessIdentity
        ? businessAccount!.logoUrl ?? profile.avatarUrl
        : profile.avatarUrl;
    final fallbackText = isBusinessIdentity
        ? _businessInitials(businessAccount!)
        : _initials(profile);
    final title = isBusinessIdentity
        ? businessAccount!.displayName
        : _displayName(profile);
    final handle = isBusinessIdentity
        ? businessAccount!.displayHandle
        : profile.displayHandle;
    final location = isBusinessIdentity
        ? businessAccount!.locationLabel
        : profile.city?.trim();
    final description = isBusinessIdentity
        ? businessAccount!.description?.trim()
        : profile.bio?.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
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
        child: Column(
          children: [
            SafeAvatar(
              radius: 42,
              avatarUrl: avatarUrl,
              fallbackText: fallbackText,
              fontSize: 30,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: AppTextStyles.headline,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              handle ?? 'Your profile',
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (location?.isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                location!,
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
            ],
            if (isBusinessIdentity) ...[
              const SizedBox(height: AppSpacing.md),
              BusinessBadge(isVerified: businessAccount!.isVerified),
              const SizedBox(height: AppSpacing.xs),
              Text(
                businessAccount!.displayCategory,
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
            ],
            if (description?.isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                description!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            _OwnProfileStats(
              userId: profile.userId,
              followersCount: publicDetail?.followersCount ?? 0,
              followingCount: publicDetail?.followingCount ?? 0,
              trustScore: profile.trustScoreValue,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Güven Skoru etkinlik davranışlarına göre zamanla değişir.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnProfileStats extends StatelessWidget {
  const _OwnProfileStats({
    required this.userId,
    required this.followersCount,
    required this.followingCount,
    required this.trustScore,
  });

  final String userId;
  final int followersCount;
  final int followingCount;
  final int trustScore;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth < 420
            ? (constraints.maxWidth - AppSpacing.sm) / 2
            : (constraints.maxWidth - (AppSpacing.sm * 2)) / 3;

        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          alignment: WrapAlignment.center,
          children: [
            SizedBox(
              width: cardWidth.clamp(132.0, 220.0),
              child: _OwnProfileStatCard(
                value: followingCount,
                label: 'Takip Edilen',
                icon: Icons.person_add_alt_1_outlined,
                onTap: () => context.pushNamed(
                  RouteNames.profileFollowList,
                  pathParameters: {'userId': userId, 'type': 'following'},
                ),
              ),
            ),
            SizedBox(
              width: cardWidth.clamp(132.0, 220.0),
              child: _OwnProfileStatCard(
                value: followersCount,
                label: 'Takipçi',
                icon: Icons.groups_2_outlined,
                onTap: () => context.pushNamed(
                  RouteNames.profileFollowList,
                  pathParameters: {'userId': userId, 'type': 'followers'},
                ),
              ),
            ),
            SizedBox(
              width: cardWidth.clamp(132.0, 220.0),
              child: _OwnProfileStatCard(
                value: trustScore,
                label: 'Güven Skoru',
                icon: Icons.verified_outlined,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OwnProfileStatCard extends StatelessWidget {
  const _OwnProfileStatCard({
    required this.value,
    required this.label,
    required this.icon,
    this.onTap,
  });

  final int value;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.lgBorder,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: AppColors.border),
            borderRadius: AppRadius.lgBorder,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _compactCount(value),
                  style: AppTextStyles.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'No profile yet.',
            style: AppTextStyles.title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Complete profile',
            onPressed: () => context.pushNamed(RouteNames.profileComplete),
          ),
        ],
      ),
    );
  }
}

String _initials(Profile profile) {
  final firstName = profile.firstName?.trim();
  final username = profile.username?.trim();
  final parts = [
    firstName,
  ].where((part) => part != null && part.isNotEmpty).cast<String>().toList();

  if (parts.isNotEmpty) {
    return parts
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();
  }

  if (username != null && username.isNotEmpty) {
    return username.characters.first.toUpperCase();
  }

  return 'M';
}

String _businessInitials(BusinessAccount account) {
  final name = account.displayName.trim();
  if (name.isNotEmpty) return name.characters.first.toUpperCase();
  final username = account.username.trim();
  if (username.isNotEmpty) return username.characters.first.toUpperCase();
  return 'İ';
}

String _displayName(Profile profile) {
  final firstName = profile.firstName?.trim();
  final name = [
    firstName,
  ].where((part) => part != null && part.isNotEmpty).join(' ');

  if (name.isNotEmpty) return name;
  return 'MaM player';
}

String _compactCount(int value) {
  if (value >= 1000000) {
    final formatted = (value / 1000000).toStringAsFixed(
      value >= 10000000 ? 0 : 1,
    );
    return '${formatted.replaceAll('.0', '')}M';
  }
  if (value >= 1000) {
    final formatted = (value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1);
    return '${formatted.replaceAll('.0', '')}K';
  }
  return value.toString();
}
