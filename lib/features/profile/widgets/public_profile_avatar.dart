import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../public_profile_models.dart';
import '../public_profile_provider.dart';

class PublicProfileAvatar extends ConsumerWidget {
  const PublicProfileAvatar({
    super.key,
    this.userId,
    this.profile,
    this.radius = 20,
    this.enableNavigation = true,
  });

  final String? userId;
  final PublicProfilePreview? profile;
  final double radius;
  final bool enableNavigation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = profile;
    if (preview != null) {
      if (!enableNavigation) return _Avatar(profile: preview, radius: radius);
      return _TappableProfile(
        userId: preview.userId,
        child: _Avatar(profile: preview, radius: radius),
      );
    }

    final id = userId;
    if (id == null || id.trim().isEmpty) {
      return _Avatar(profile: null, radius: radius);
    }

    final asyncProfile = ref.watch(publicProfilePreviewProvider(id));
    return asyncProfile.maybeWhen(
      data: (profile) {
        final avatar = _Avatar(profile: profile, radius: radius);
        if (!enableNavigation) return avatar;
        return _TappableProfile(userId: id, child: avatar);
      },
      orElse: () => _Avatar(profile: null, radius: radius),
    );
  }
}

class _TappableProfile extends StatelessWidget {
  const _TappableProfile({required this.userId, required this.child});

  final String userId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (userId.trim().isEmpty) return child;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.pushNamed(
        RouteNames.publicProfile,
        pathParameters: {'userId': userId},
      ),
      child: child,
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile, required this.radius});

  final PublicProfilePreview? profile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile?.avatarUrl?.trim();

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primarySoft,
      backgroundImage: avatarUrl == null || avatarUrl.isEmpty
          ? null
          : NetworkImage(avatarUrl),
      child: avatarUrl == null || avatarUrl.isEmpty
          ? Text(
              profile?.initials ?? 'M',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: radius * 0.8,
              ),
            )
          : null,
    );
  }
}
