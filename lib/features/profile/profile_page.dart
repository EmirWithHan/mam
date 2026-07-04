import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/responsive_layout.dart';
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
import '../business/widgets/business_plus_badge.dart';
import 'profile_activity_provider.dart';
import 'profile_models.dart';
import 'profile_provider.dart';
import 'widgets/profile_badges_section.dart';
import 'widgets/profile_event_list.dart';
import 'widgets/profile_gallery_grid.dart';
import 'widgets/profile_stats_box.dart';
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
      if (!mounted) return;
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
          padding: AppResponsive.pagePadding(context),
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
            eventCount: activityState.events.length,
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
              label: 'Geçmiş Etkinlikler',
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
        padding: AppResponsive.cardPadding(context),
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
              'Fotoğraf, bio ve şehir bilgilerini ekleyerek profilini güçlendirebilirsin.',
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
    required this.eventCount,
  });

  final Profile profile;
  final PublicProfileDetail? publicDetail;
  final BusinessAccount? businessAccount;
  final int eventCount;

  @override
  Widget build(BuildContext context) {
    final isBusinessIdentity =
        profile.isBusinessAccount && businessAccount != null;
    final avatarUrl = profile.avatarUrl;
    final fallbackText = _initials(profile);
    final title = _displayName(profile);
    final handle = profile.displayHandle;
    final location = profile.city?.trim();
    final description = profile.bio?.trim();

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
              handle ?? 'Profilin',
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
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.center,
                children: [
                  BusinessBadge(isVerified: businessAccount!.isVerified),
                  if (businessAccount!.isPlusActive) const BusinessPlusBadge(),
                ],
              ),
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
              eventCount: eventCount,
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
    required this.eventCount,
  });

  final String userId;
  final int followersCount;
  final int followingCount;
  final int eventCount;

  @override
  Widget build(BuildContext context) {
    return ProfileStatsBox(
      items: [
        ProfileStatItem(
          value: followingCount,
          label: 'Takip',
          onTap: () => context.pushNamed(
            RouteNames.profileFollowList,
            pathParameters: {'userId': userId, 'type': 'following'},
          ),
        ),
        ProfileStatItem(
          value: followersCount,
          label: 'Takipçi',
          onTap: () => context.pushNamed(
            RouteNames.profileFollowList,
            pathParameters: {'userId': userId, 'type': 'followers'},
          ),
        ),
        ProfileStatItem(value: eventCount, label: 'Etkinlik'),
      ],
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
            'Henüz profil yok.',
            style: AppTextStyles.title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Profili tamamla',
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

String _displayName(Profile profile) {
  final firstName = profile.firstName?.trim();
  final name = [
    firstName,
  ].where((part) => part != null && part.isNotEmpty).join(' ');

  if (name.isNotEmpty) return name;
  return 'Akanzi kullanıcısı';
}
