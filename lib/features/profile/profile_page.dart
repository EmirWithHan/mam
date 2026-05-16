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
import '../../core/widgets/error_view.dart';
import '../trust_score/widgets/trust_score_badge.dart';
import 'profile_models.dart';
import 'profile_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(profileControllerProvider.notifier).loadMyProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MaM'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => context.goNamed(RouteNames.settings),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: _ProfileBody(profileState: profileState),
        ),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.profileState});

  final ProfileState profileState;

  @override
  Widget build(BuildContext context) {
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

    return ListView(
      children: [
        _ProfileHeader(profile: profile),
        const SizedBox(height: AppSpacing.lg),
        if (!profile.isProfileCompleted) ...[
          const _ProfileIncompleteGuidance(),
          const SizedBox(height: AppSpacing.lg),
        ],
        _TrustCard(profile: profile),
        const SizedBox(height: AppSpacing.lg),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.lgBorder,
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                AppButton(
                  label: profile.isProfileCompleted
                      ? 'Edit profile'
                      : 'Complete profile',
                  onPressed: () => context.goNamed(RouteNames.profileComplete),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Trust score history',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => context.goNamed(RouteNames.trustScoreHistory),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileIncompleteGuidance extends StatelessWidget {
  const _ProfileIncompleteGuidance();

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
              onPressed: () => context.goNamed(RouteNames.profileComplete),
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
            const SizedBox(height: AppSpacing.md),
            _ProfileStatusPill(isCompleted: profile.isProfileCompleted),
            const SizedBox(height: AppSpacing.md),
            TrustScoreBadge(score: profile.trustScoreValue, compact: true),
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
            onPressed: () => context.goNamed(RouteNames.profileComplete),
          ),
        ],
      ),
    );
  }
}

class _TrustCard extends StatelessWidget {
  const _TrustCard({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.lgBorder,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trust score', style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.md),
            TrustScoreBadge(score: profile.trustScoreValue),
            const SizedBox(height: AppSpacing.sm),
            Text(
              profile.trustDescription,
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileStatusPill extends StatelessWidget {
  const _ProfileStatusPill({required this.isCompleted});

  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isCompleted
            ? AppColors.success.withValues(alpha: 0.12)
            : AppColors.warning.withValues(alpha: 0.16),
        borderRadius: AppRadius.pillBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Text(
          isCompleted ? 'Profile completed' : 'Profile incomplete',
          style: AppTextStyles.label.copyWith(
            color: isCompleted ? AppColors.success : AppColors.warning,
          ),
        ),
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
