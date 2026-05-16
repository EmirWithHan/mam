import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../auth/auth_provider.dart';
import '../blocks_provider.dart';

class BlockButton extends ConsumerStatefulWidget {
  const BlockButton({
    super.key,
    required this.targetUserId,
    this.compact = false,
  });

  final String targetUserId;
  final bool compact;

  @override
  ConsumerState<BlockButton> createState() => _BlockButtonState();
}

class _BlockButtonState extends ConsumerState<BlockButton> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.message!)),
      );
      return;
    }

    final isBlocked = state.userBlockState?.isBlockedByMe ?? false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isBlocked ? 'User blocked.' : 'User unblocked.')),
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

    final label = blockState?.isBlockedByMe == true ? 'Unblock' : 'Block';

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
