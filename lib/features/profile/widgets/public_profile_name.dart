import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../public_profile_provider.dart';

class PublicProfileName extends ConsumerWidget {
  const PublicProfileName({
    super.key,
    required this.userId,
    this.showUsernameTag = true,
    this.compact = false,
    this.textStyle,
  });

  final String userId;
  final bool showUsernameTag;
  final bool compact;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfile = ref.watch(publicProfilePreviewProvider(userId));

    return asyncProfile.maybeWhen(
      data: (profile) {
        final usernameTag = profile?.usernameTag;
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.pushNamed(
            RouteNames.publicProfile,
            pathParameters: {'userId': userId},
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                profile?.displayName ?? 'Match A Man kullanıcısı',
                style:
                    textStyle ??
                    (compact
                        ? AppTextStyles.caption
                        : AppTextStyles.bodyStrong),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (showUsernameTag &&
                  usernameTag != null &&
                  usernameTag.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  usernameTag,
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        );
      },
      loading: () => Text(
        'Match A Man kullanıcısı',
        style:
            textStyle ??
            (compact ? AppTextStyles.caption : AppTextStyles.bodyStrong),
      ),
      orElse: () => Text(
        'Match A Man kullanıcısı',
        style:
            textStyle ??
            (compact ? AppTextStyles.caption : AppTextStyles.bodyStrong),
      ),
    );
  }
}
