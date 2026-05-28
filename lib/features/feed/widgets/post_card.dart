import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/sport_types.dart';
import '../../auth/auth_provider.dart';
import '../../follow/widgets/follow_button.dart';
import '../../profile/widgets/public_profile_preview_tile.dart';
import '../../reports/reports_models.dart';
import '../../reports/widgets/block_button.dart';
import '../../reports/widgets/report_button.dart';
import '../feed_models.dart';
import '../feed_provider.dart';

class PostCard extends ConsumerWidget {
  const PostCard({
    super.key,
    required this.item,
    required this.isLikeLoading,
    required this.onToggleLike,
    required this.onOpenComments,
  });

  final PostWithStats item;
  final bool isLikeLoading;
  final VoidCallback onToggleLike;
  final VoidCallback onOpenComments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = item.post;
    final caption = post.caption?.trim();
    final currentUserId = ref.watch(authControllerProvider).userId;
    final isMine = currentUserId != null && post.userId == currentUserId;
    final commentsLocked = post.commentsHidden && !isMine;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.xlBorder,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: PublicProfilePreviewTile(
                        userId: post.userId,
                        compact: true,
                      ),
                    ),
                    if (!isMine) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: FollowButton(
                          targetUserId: post.userId,
                          compact: true,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    if (currentUserId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: _PostOverflowButton(
                          postId: post.id,
                          userId: post.userId,
                          isMine: isMine,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: AppRadius.lgBorder,
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.network(
                      post.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const ColoredBox(
                          color: AppColors.border,
                          child: Center(child: Icon(Icons.image_not_supported)),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (post.eventId != null) ...[
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      const _FeedPostChip(
                        label: 'Bağlı etkinlik',
                        icon: Icons.event_outlined,
                      ),
                      if (post.eventSportType?.trim().isNotEmpty == true)
                        _FeedPostChip(
                          label: sportLabelFor(post.eventSportType),
                          icon: sportIconFor(post.eventSportType),
                          highlighted: true,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (caption != null && caption.isNotEmpty) ...[
                  Text(caption, style: AppTextStyles.body),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Text(_formatDate(post.createdAt), style: AppTextStyles.caption),
                const SizedBox(height: AppSpacing.md),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: AppRadius.pillBorder,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        TextButton.icon(
                          onPressed: isLikeLoading ? null : onToggleLike,
                          icon: isLikeLoading
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  item.isLikedByMe
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: item.isLikedByMe
                                      ? AppColors.primary
                                      : AppColors.textMuted,
                                ),
                          label: Text('${item.likeCount}'),
                        ),
                        TextButton.icon(
                          onPressed: commentsLocked ? null : onOpenComments,
                          icon: Icon(
                            commentsLocked
                                ? Icons.lock_outline
                                : Icons.mode_comment_outlined,
                            color: AppColors.textMuted,
                          ),
                          label: Text(
                            commentsLocked
                                ? 'Yorumlar gizlendi'
                                : '${item.commentCount}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }
}

class _FeedPostChip extends StatelessWidget {
  const _FeedPostChip({
    required this.label,
    required this.icon,
    this.highlighted = false,
  });

  final String label;
  final IconData icon;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final textColor = highlighted ? AppColors.primary : AppColors.textSecondary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: highlighted ? AppColors.primarySoft : AppColors.secondarySoft,
        borderRadius: AppRadius.pillBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: textColor, size: 15),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: AppTextStyles.label.copyWith(color: textColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _PostOverflowButton extends ConsumerWidget {
  const _PostOverflowButton({
    required this.postId,
    required this.userId,
    required this.isMine,
  });

  final String postId;
  final String userId;
  final bool isMine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: 'Post actions',
      icon: const Icon(Icons.more_horiz, color: AppColors.textMuted),
      onPressed: () => _showPostActions(context, ref),
    );
  }

  Future<void> _showPostActions(BuildContext context, WidgetRef ref) {
    final rootContext = context;

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: AppRadius.pillBorder,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Paylaşım işlemleri', style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.sm),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.lgBorder,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: isMine
                        ? [
                            _PostDeleteMenuItem(
                              onTap: () {
                                Navigator.of(sheetContext).pop();
                                _confirmDeletePost(rootContext, ref);
                              },
                            ),
                          ]
                        : [
                            ReportButton(
                              targetType: ReportTargetType.post,
                              targetId: postId,
                              menuItem: true,
                            ),
                            const Divider(height: 1, color: AppColors.border),
                            ReportButton(
                              targetType: ReportTargetType.user,
                              targetId: userId,
                              menuItem: true,
                            ),
                            const Divider(height: 1, color: AppColors.border),
                            BlockButton(targetUserId: userId, menuItem: true),
                          ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeletePost(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Paylaşım silinsin mi?'),
          content: const Text('Bu paylaşım kalıcı olarak kaldırılacak.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgeç'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    final deleted = await ref
        .read(feedControllerProvider.notifier)
        .deletePost(postId);
    if (!context.mounted) return;

    final message = deleted
        ? 'Paylaşım silindi.'
        : ref.read(feedControllerProvider).message;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message ?? 'Paylaşım silinemedi.')));
  }
}

class _PostDeleteMenuItem extends StatelessWidget {
  const _PostDeleteMenuItem({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.delete_outline, color: AppColors.error),
      title: Text(
        'Paylaşımı sil',
        style: AppTextStyles.bodyStrong.copyWith(color: AppColors.error),
      ),
      onTap: onTap,
    );
  }
}
