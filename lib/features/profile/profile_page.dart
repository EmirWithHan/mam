import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
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
      appBar: AppBar(title: const Text('Profile')),
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
      return const Center(child: CircularProgressIndicator());
    }

    if (profileState.status == ProfileStatus.error) {
      return Center(
        child: Text(
          profileState.message ?? 'Could not load profile.',
          textAlign: TextAlign.center,
        ),
      );
    }

    final profile = profileState.profile;
    if (profile == null) {
      return _ProfileEmptyState();
    }

    return ListView(
      children: [
        Text(_displayHandle(profile), style: AppTextStyles.headline),
        const SizedBox(height: AppSpacing.sm),
        Text(_displayName(profile), style: AppTextStyles.body),
        if (profile.city?.trim().isNotEmpty == true) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(profile.city!, style: AppTextStyles.caption),
        ],
        const SizedBox(height: AppSpacing.lg),
        TrustScoreBadge(score: profile.trustScoreValue),
        const SizedBox(height: AppSpacing.sm),
        Text(profile.trustDescription, style: AppTextStyles.caption),
        const SizedBox(height: AppSpacing.lg),
        _ProfileStatusCard(profile: profile),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: profile.isProfileCompleted ? 'Edit profile' : 'Complete profile',
          onPressed: () => context.goNamed(RouteNames.profileComplete),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Trust score history',
          onPressed: () => context.goNamed(RouteNames.trustScoreHistory),
        ),
      ],
    );
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
    return 'Add your name to complete your player card.';
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

class _ProfileStatusCard extends StatelessWidget {
  const _ProfileStatusCard({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profile status', style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.xs),
            Text(
              profile.isProfileCompleted ? 'Completed' : 'Incomplete',
              style: AppTextStyles.body,
            ),
          ],
        ),
      ),
    );
  }
}
