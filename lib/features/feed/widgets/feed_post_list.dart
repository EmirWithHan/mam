import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../feed_models.dart';
import 'post_card.dart';

class FeedPostList extends StatelessWidget {
  const FeedPostList({
    super.key,
    required this.posts,
    required this.onToggleLike,
    required this.onOpenComments,
    this.bottomPadding = AppSpacing.xl,
  });

  final List<PostWithStats> posts;
  final ValueChanged<PostWithStats> onToggleLike;
  final ValueChanged<PostWithStats> onOpenComments;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final itemCount = posts.isEmpty ? 0 : posts.length * 2 - 1;

    return SliverPadding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index.isOdd) {
              return const SizedBox(height: AppSpacing.md);
            }

            final item = posts[index ~/ 2];
            return PostCard(
              key: ValueKey(item.post.id),
              item: item,
              onToggleLike: () => onToggleLike(item),
              onOpenComments: () => onOpenComments(item),
            );
          },
          childCount: itemCount,
        ),
      ),
    );
  }
}
