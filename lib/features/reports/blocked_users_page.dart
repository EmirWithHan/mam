import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../profile/widgets/public_profile_preview_tile.dart';
import 'blocks_models.dart';
import 'blocks_provider.dart';

class BlockedUsersPage extends ConsumerStatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  ConsumerState<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends ConsumerState<BlockedUsersPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(myBlocksControllerProvider.notifier).loadBlocks();
    });
  }

  Future<void> _unblock(Block block) async {
    final success = await ref
        .read(myBlocksControllerProvider.notifier)
        .unblockUser(block.blockedUserId);

    if (!mounted) return;
    final message = ref.read(myBlocksControllerProvider).message;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Engel kaldırıldı.' : message ?? 'Engel kaldırılamadı.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myBlocksControllerProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Geri',
          onPressed: () => _goBack(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Engellenenler'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(myBlocksControllerProvider.notifier).refreshBlocks(),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text('Engellenenler', style: AppTextStyles.headline),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Engellediğin kullanıcıları buradan yönetebilirsin.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (state.loading && state.blocks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: AppLoader(),
                )
              else if (state.message != null && state.blocks.isEmpty)
                ErrorView(
                  message: state.message!,
                  onRetry: () => ref
                      .read(myBlocksControllerProvider.notifier)
                      .refreshBlocks(),
                )
              else if (state.blocks.isEmpty)
                const EmptyState(
                  title: 'Engellenen kullanıcı yok',
                  message: 'Engellediğin kullanıcılar burada görünür.',
                  icon: Icons.block_outlined,
                )
              else
                ...state.blocks.map(
                  (block) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _BlockedUserCard(
                      block: block,
                      isLoading: state.loading,
                      onUnblock: () => _unblock(block),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.goNamed(RouteNames.settings);
  }
}

class _BlockedUserCard extends StatelessWidget {
  const _BlockedUserCard({
    required this.block,
    required this.isLoading,
    required this.onUnblock,
  });

  final Block block;
  final bool isLoading;
  final VoidCallback onUnblock;

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
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PublicProfilePreviewTile(
              userId: block.blockedUserId,
              subtitle: 'Engellendi: ${_formatDate(block.createdAt)}',
              compact: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: isLoading ? null : onUnblock,
                icon: isLoading
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_open_outlined),
                label: const Text('Engeli kaldır'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.border),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
