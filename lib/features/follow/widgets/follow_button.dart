import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../follow_provider.dart';

class FollowButton extends ConsumerStatefulWidget {
  const FollowButton({
    super.key,
    required this.targetUserId,
    this.compact = false,
  });

  final String targetUserId;
  final bool compact;

  @override
  ConsumerState<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<FollowButton> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref
          .read(followControllerProvider(widget.targetUserId).notifier)
          .loadStats();
    });
  }

  Future<void> _toggleFollow() async {
    final controller = ref.read(
      followControllerProvider(widget.targetUserId).notifier,
    );

    await controller.toggleFollow();

    if (!mounted) return;
    final message =
        ref.read(followControllerProvider(widget.targetUserId)).message;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final followState = ref.watch(followControllerProvider(widget.targetUserId));
    final stats = followState.stats;

    if (stats == null) {
      return widget.compact
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const AppButton(
              label: 'Loading',
              isLoading: true,
              onPressed: null,
            );
    }

    if (stats.isMe) {
      return widget.compact
          ? const Text('You', style: AppTextStyles.caption)
          : const AppButton(label: 'You', onPressed: null);
    }

    final label = stats.isFollowedByMe ? 'Following' : 'Follow';
    final followerCount = stats.followerCount;

    if (widget.compact) {
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.sm,
        children: [
          OutlinedButton(
            onPressed: followState.loading ? null : _toggleFollow,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryDark,
              side: const BorderSide(color: AppColors.border),
              shape: const StadiumBorder(),
            ),
            child: followState.loading
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(label),
          ),
          Text(
            '$followerCount followers',
            style: AppTextStyles.caption,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(
          label: label,
          variant: stats.isFollowedByMe
              ? AppButtonVariant.secondary
              : AppButtonVariant.primary,
          isLoading: followState.loading,
          onPressed: _toggleFollow,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '$followerCount followers',
          style: AppTextStyles.caption,
          textAlign: TextAlign.center,
        ),
        if (followState.message != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            followState.message!,
            style: const TextStyle(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
