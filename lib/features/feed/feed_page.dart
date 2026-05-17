import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import 'feed_provider.dart';
import 'widgets/feed_post_list.dart';

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({
    super.key,
    this.showCreatePrompt = true,
    this.showNotificationBell = false,
  });

  final bool showCreatePrompt;
  final bool showNotificationBell;

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(feedControllerProvider.notifier).loadPosts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedControllerProvider);

    return SafeArea(
      child: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            sliver: SliverToBoxAdapter(
              child: _FeedHeader(
                showCreatePrompt: widget.showCreatePrompt,
                showNotificationBell: widget.showNotificationBell,
              ),
            ),
          ),
          _FeedBody(
            feedState: feedState,
            showCreateAction: widget.showCreatePrompt,
          ),
        ],
      ),
    );
  }
}

class _FeedHeader extends StatelessWidget {
  const _FeedHeader({
    required this.showCreatePrompt,
    required this.showNotificationBell,
  });

  final bool showCreatePrompt;
  final bool showNotificationBell;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const AppLogo(size: 32, showText: true),
            if (showNotificationBell)
              IconButton(
                tooltip: 'Bildirimler',
                onPressed: () => context.pushNamed(RouteNames.notifications),
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(child: Text('Moments', style: AppTextStyles.headline)),
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.photo_camera_outlined,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Sports days, match energy, and community snapshots.',
          style: AppTextStyles.body,
        ),
        if (showCreatePrompt) ...[
          const SizedBox(height: AppSpacing.md),
          const _CreatePostPrompt(),
        ],
      ],
    );
  }
}

class _CreatePostPrompt extends StatelessWidget {
  const _CreatePostPrompt();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
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
        child: Row(
          children: [
            const Icon(
              Icons.add_photo_alternate_outlined,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Share a photo from your day or activity.',
                style: AppTextStyles.bodySmall,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 132,
              child: AppButton(
                label: 'Post photo',
                onPressed: () => context.pushNamed(RouteNames.createPost),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedBody extends ConsumerWidget {
  const _FeedBody({
    required this.feedState,
    required this.showCreateAction,
  });

  final FeedState feedState;
  final bool showCreateAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (feedState.isLoading && feedState.posts.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Center(child: AppLoader()),
        ),
      );
    }

    if (feedState.status == FeedStatus.error && feedState.posts.isEmpty) {
      return SliverToBoxAdapter(
        child: ErrorView(
          message: feedState.message ?? 'Could not load feed.',
          onRetry: () {
            ref.read(feedControllerProvider.notifier).refreshPosts();
          },
        ),
      );
    }

    if (feedState.posts.isEmpty) {
      return SliverToBoxAdapter(
        child: EmptyState(
          title: 'Henüz paylaşım yok',
          message:
              'Bir fotoğraf paylaşarak topluluğa ilk anı sen bırakabilirsin.',
          icon: Icons.add_photo_alternate_outlined,
          actionLabel: showCreateAction ? 'Fotoğraf paylaş' : null,
          onAction: showCreateAction
              ? () => context.pushNamed(RouteNames.createPost)
              : null,
          secondaryActionLabel: 'Etkinlikleri keşfet',
          onSecondaryAction: () => context.goNamed(RouteNames.events),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      sliver: FeedPostList(
        posts: feedState.posts,
        bottomPadding: 96,
        onToggleLike: (item) {
          ref.read(feedControllerProvider.notifier).toggleLike(item);
        },
        onOpenComments: (item) => context.pushNamed(
          RouteNames.postComments,
          pathParameters: {'postId': item.post.id},
        ),
      ),
    );
  }
}
