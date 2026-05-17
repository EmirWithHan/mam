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
import 'profile_activity_provider.dart';
import 'profile_models.dart';
import 'profile_provider.dart';
import 'widgets/profile_event_list.dart';
import 'widgets/profile_gallery_grid.dart';

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

enum _ProfileActivityTab {
  gallery,
  events,
}

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
      return ErrorView(
        message: profileState.message ?? 'Could not load profile.',
      );
    }

    final profile = profileState.profile;
    if (profile == null) {
      return _ProfileEmptyState();
    }
    final activityState = ref.watch(profileActivityControllerProvider);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(profileControllerProvider.notifier).refreshMyProfile();
        await ref.read(profileActivityControllerProvider.notifier).refresh();
      },
      child: ListView(
        children: [
          _ProfileHeader(profile: profile),
          const SizedBox(height: AppSpacing.lg),
          _ProfileActivityTabs(
            selectedTab: selectedTab,
            onTabSelected: onTabSelected,
          ),
          const SizedBox(height: AppSpacing.md),
          _ProfileActivityContent(
            selectedTab: selectedTab,
            activityState: activityState,
            onRetry: () => ref
                .read(profileActivityControllerProvider.notifier)
                .refresh(),
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
              label: 'Eventlerim',
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
  const ProfileIncompleteGuidanceUnused();

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
                  child: Text(
                    'Profilini tamamla',
                    style: AppTextStyles.title,
                  ),
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
  const _ProfileHeader({required this.profile});

  final Profile profile;

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
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            _Avatar(profile: profile),
            const SizedBox(height: AppSpacing.md),
            Text(
              _displayName(profile),
              style: AppTextStyles.headline,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _displayHandle(profile),
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (profile.city?.trim().isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                profile.city!,
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ],
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile.avatarUrl;

    return CircleAvatar(
      radius: 42,
      backgroundColor: AppColors.primarySoft,
      backgroundImage: avatarUrl == null || avatarUrl.trim().isEmpty
          ? null
          : NetworkImage(avatarUrl),
      child: avatarUrl == null || avatarUrl.trim().isEmpty
          ? Text(
              _initials(profile),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 30,
              ),
            )
          : null,
    );
  }
}

String _initials(Profile profile) {
  final firstName = profile.firstName?.trim();
  final lastName = profile.lastName?.trim();
  final username = profile.username?.trim();
  final parts = [firstName, lastName]
      .where((part) => part != null && part.isNotEmpty)
      .cast<String>()
      .toList();

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

String _displayHandle(Profile profile) {
  final username = profile.username?.trim();
  final tag = profile.tag?.trim();
  if (username != null && username.isNotEmpty && tag != null && tag.isNotEmpty) {
    return '$username#$tag';
  }
  if (username != null && username.isNotEmpty) return username;
  return 'Your profile';
}

String _displayName(Profile profile) {
  final firstName = profile.firstName?.trim();
  final lastName = profile.lastName?.trim();
  final name = [
    firstName,
    lastName,
  ].where((part) => part != null && part.isNotEmpty).join(' ');

  if (name.isNotEmpty) return name;
  return 'MaM player';
}
