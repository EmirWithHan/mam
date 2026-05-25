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
    this.fullWidth = false,
    this.onChanged,
  });

  final String targetUserId;
  final bool compact;
  final bool fullWidth;
  final VoidCallback? onChanged;

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
    widget.onChanged?.call();

    if (!mounted) return;
    final message = ref
        .read(followControllerProvider(widget.targetUserId))
        .message;
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final followState = ref.watch(
      followControllerProvider(widget.targetUserId),
    );
    final stats = followState.stats;

    if (stats == null) {
      return widget.compact
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : AppButton(
              label: 'Yükleniyor',
              isLoading: true,
              onPressed: null,
              fullWidth: widget.fullWidth,
            );
    }

    if (stats.isMe) {
      return widget.compact
          ? const Text('Sen', style: AppTextStyles.caption)
          : AppButton(
              label: 'Sen',
              onPressed: null,
              fullWidth: widget.fullWidth,
            );
    }

    final label = stats.isFollowedByMe ? 'Takip Ediliyor' : 'Takip Et';
    final followerCount = stats.followerCount;

    if (widget.compact) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 132),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FilledButton.tonal(
              onPressed: followState.loading ? null : _toggleFollow,
              style: FilledButton.styleFrom(
                backgroundColor: stats.isFollowedByMe
                    ? AppColors.primarySoft
                    : AppColors.primary,
                foregroundColor: stats.isFollowedByMe
                    ? AppColors.primary
                    : Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
              child: followState.loading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(label),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$followerCount takipçi',
              style: AppTextStyles.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: widget.fullWidth
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.center,
      children: [
        AppButton(
          label: label,
          variant: stats.isFollowedByMe
              ? AppButtonVariant.secondary
              : AppButtonVariant.primary,
          isLoading: followState.loading,
          onPressed: _toggleFollow,
          fullWidth: widget.fullWidth,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '$followerCount takipçi',
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
