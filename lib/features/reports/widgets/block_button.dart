import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/auth_provider.dart';
import '../blocks_provider.dart';

class BlockButton extends ConsumerStatefulWidget {
  const BlockButton({
    super.key,
    required this.targetUserId,
    this.compact = false,
    this.menuItem = false,
  });

  final String targetUserId;
  final bool compact;
  final bool menuItem;

  @override
  ConsumerState<BlockButton> createState() => _BlockButtonState();
}

class _BlockButtonState extends ConsumerState<BlockButton> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref
          .read(blockControllerProvider(widget.targetUserId).notifier)
          .loadBlockState();
    });
  }

  Future<void> _toggleBlock() async {
    final success = await ref
        .read(blockControllerProvider(widget.targetUserId).notifier)
        .toggleBlock();

    if (!mounted) return;
    final state = ref.read(blockControllerProvider(widget.targetUserId));
    if (!success && state.message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.message!)));
      return;
    }

    final isBlocked = state.userBlockState?.isBlockedByMe ?? false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isBlocked
              ? 'Kullanıcı engellendi.'
              : 'Kullanıcının engeli kaldırıldı.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authControllerProvider).userId;
    if (currentUserId == widget.targetUserId) {
      return const SizedBox.shrink();
    }

    final state = ref.watch(blockControllerProvider(widget.targetUserId));
    final blockState = state.userBlockState;

    if (blockState?.isMe == true) {
      return const SizedBox.shrink();
    }

    final label = blockState?.isBlockedByMe == true
        ? 'Engeli kaldır'
        : 'Engelle';

    if (widget.menuItem) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        enabled: !state.loading && blockState != null,
        leading: state.loading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                Icons.block,
                color: blockState?.isBlockedByMe == true
                    ? AppColors.error
                    : AppColors.textMuted,
              ),
        title: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: blockState?.isBlockedByMe == true
                ? AppColors.error
                : AppColors.textSecondary,
          ),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
        ),
        onTap: state.loading || blockState == null ? null : _toggleBlock,
      );
    }

    if (widget.compact) {
      return TextButton.icon(
        onPressed: state.loading || blockState == null ? null : _toggleBlock,
        style: TextButton.styleFrom(
          foregroundColor: blockState?.isBlockedByMe == true
              ? AppColors.error
              : AppColors.textMuted,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: state.loading
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.block),
        label: Text(label),
      );
    }

    return OutlinedButton.icon(
      onPressed: state.loading || blockState == null ? null : _toggleBlock,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        side: const BorderSide(color: AppColors.border),
        shape: const StadiumBorder(),
      ),
      icon: state.loading
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.block),
      label: Text(label),
    );
  }
}
