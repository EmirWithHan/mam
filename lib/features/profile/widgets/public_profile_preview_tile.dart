import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../public_profile_provider.dart';
import 'public_profile_avatar.dart';

class PublicProfilePreviewTile extends ConsumerWidget {
  const PublicProfilePreviewTile({
    super.key,
    required this.userId,
    this.subtitle,
    this.trailing,
    this.compact = false,
    this.enableNavigation = true,
  });

  final String userId;
  final String? subtitle;
  final Widget? trailing;
  final bool compact;
  final bool enableNavigation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trimmedUserId = userId.trim();
    final canNavigate = enableNavigation && trimmedUserId.isNotEmpty;
    if (trimmedUserId.isEmpty) {
      return _PreviewFallbackTile(compact: compact, trailing: trailing);
    }

    final asyncProfile = ref.watch(publicProfilePreviewProvider(userId));

    return asyncProfile.maybeWhen(
      data: (profile) {
        final secondaryText =
            subtitle ?? profile?.usernameTag ?? profile?.city ?? '';

        final tile = Container(
          padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
          decoration: BoxDecoration(
            color: compact ? Colors.transparent : AppColors.surface,
            border: compact ? null : Border.all(color: AppColors.border),
            borderRadius: AppRadius.lgBorder,
          ),
          child: Row(
            children: [
              PublicProfileAvatar(
                profile: profile,
                radius: compact ? 16 : 22,
                enableNavigation: false,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      profile?.displayName ?? 'Akanzi kullanıcısı',
                      style: compact
                          ? AppTextStyles.caption
                          : AppTextStyles.bodyStrong,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (secondaryText.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        secondaryText,
                        style: AppTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                ?trailing,
              ],
            ],
          ),
        );

        if (!canNavigate) return tile;

        return InkWell(
          borderRadius: AppRadius.lgBorder,
          onTap: () => context.pushNamed(
            RouteNames.publicProfile,
            pathParameters: {'userId': trimmedUserId},
          ),
          child: tile,
        );
      },
      orElse: () => _PreviewFallbackTile(compact: compact, trailing: trailing),
    );
  }
}

class _PreviewFallbackTile extends StatelessWidget {
  const _PreviewFallbackTile({required this.compact, required this.trailing});

  final bool compact;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
      decoration: BoxDecoration(
        color: compact ? Colors.transparent : AppColors.surface,
        border: compact ? null : Border.all(color: AppColors.border),
        borderRadius: AppRadius.lgBorder,
      ),
      child: Row(
        children: [
          PublicProfileAvatar(radius: compact ? 16 : 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Akanzi kullanıcısı',
              style: compact ? AppTextStyles.caption : AppTextStyles.bodyStrong,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}
