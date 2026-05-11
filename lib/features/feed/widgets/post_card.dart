import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../feed_models.dart';

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.item,
    required this.onToggleLike,
    required this.onOpenComments,
  });

  final PostWithStats item;
  final VoidCallback onToggleLike;
  final VoidCallback onOpenComments;

  @override
  Widget build(BuildContext context) {
    final post = item.post;
    final caption = post.caption?.trim();

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
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
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.eventId != null) ...[
                  const Text(
                    'Linked event',
                    style: TextStyle(color: AppColors.primary),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
                if (caption != null && caption.isNotEmpty) ...[
                  Text(caption, style: AppTextStyles.body),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Text(_formatDate(post.createdAt), style: AppTextStyles.caption),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: onToggleLike,
                      icon: Icon(
                        item.isLikedByMe
                            ? Icons.favorite
                            : Icons.favorite_border,
                      ),
                      label: Text('${item.likeCount}'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    TextButton.icon(
                      onPressed: onOpenComments,
                      icon: const Icon(Icons.mode_comment_outlined),
                      label: Text('${item.commentCount}'),
                    ),
                  ],
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
