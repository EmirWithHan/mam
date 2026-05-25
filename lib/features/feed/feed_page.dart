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
import '../notifications/notifications_provider.dart';
import 'feed_provider.dart';
import 'widgets/post_card.dart';

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
  late final ScrollController _scrollController;
  var _requestedInitialLoad = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(keepScrollOffset: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureFeedLoaded();
      _resetScrollOffset();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _ensureFeedLoaded() {
    if (!mounted || _requestedInitialLoad) return;

    final state = ref.read(feedControllerProvider);
    if (state.status != FeedStatus.initial || state.isLoading) return;

    _requestedInitialLoad = true;
    ref.read(feedControllerProvider.notifier).loadPosts();
  }

  void _resetScrollOffset() {
    if (!mounted || !_scrollController.hasClients) return;
    _scrollController.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedControllerProvider);

    return SafeArea(
      child: ListView.builder(
        controller: _scrollController,
        physics: const ClampingScrollPhysics(),
        primary: false,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          96,
        ),
        itemCount: _itemCount(feedState),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _FeedHeader(
                showCreatePrompt: widget.showCreatePrompt,
                showNotificationBell: widget.showNotificationBell,
              ),
            );
          }

          return _FeedItem(
            feedState: feedState,
            showCreateAction: widget.showCreatePrompt,
            index: index - 1,
          );
        },
      ),
    );
  }

  int _itemCount(FeedState state) {
    if (state.posts.isEmpty) return 2;
    return 1 + (state.posts.length * 2 - 1);
  }
}

class _FeedHeader extends ConsumerWidget {
  const _FeedHeader({
    required this.showCreatePrompt,
    required this.showNotificationBell,
  });

  final bool showCreatePrompt;
  final bool showNotificationBell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const AppLogo(size: 32, showText: true),
            if (showNotificationBell)
              _NotificationBell(
                unreadCount:
                    ref.watch(notificationsUnreadCountProvider).valueOrNull ??
                    0,
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

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Bildirimler',
      onPressed: () => context.pushNamed(RouteNames.notifications),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(
            Icons.notifications_none_rounded,
            color: AppColors.primary,
          ),
          if (unreadCount > 0)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
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

class _FeedItem extends ConsumerWidget {
  const _FeedItem({
    required this.feedState,
    required this.showCreateAction,
    required this.index,
  });

  final FeedState feedState;
  final bool showCreateAction;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (feedState.posts.isEmpty) {
      return _FeedStatePanel(
        feedState: feedState,
        showCreateAction: showCreateAction,
      );
    }

    if (index.isOdd) {
      return const SizedBox(height: AppSpacing.md);
    }

    final item = feedState.posts[index ~/ 2];
    return PostCard(
      key: ValueKey(item.post.id),
      item: item,
      onToggleLike: () {
        ref.read(feedControllerProvider.notifier).toggleLike(item);
      },
      onOpenComments: () => context.pushNamed(
        RouteNames.postComments,
        pathParameters: {'postId': item.post.id},
      ),
    );
  }
}

class _FeedStatePanel extends ConsumerWidget {
  const _FeedStatePanel({
    required this.feedState,
    required this.showCreateAction,
  });

  final FeedState feedState;
  final bool showCreateAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (feedState.status == FeedStatus.initial || feedState.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(child: AppLoader()),
      );
    }

    if (feedState.status == FeedStatus.error) {
      return ErrorView(
        message: feedState.message ?? 'Akış yüklenemedi.',
        onRetry: () {
          ref.read(feedControllerProvider.notifier).refreshPosts();
        },
      );
    }

    return EmptyState(
      title: 'Henüz paylaşım yok',
      message: 'Bir fotoğraf paylaşarak topluluğa ilk anı sen bırakabilirsin.',
      icon: Icons.add_photo_alternate_outlined,
      actionLabel: showCreateAction ? 'Fotoğraf paylaş' : null,
      onAction: showCreateAction
          ? () => context.pushNamed(RouteNames.createPost)
          : null,
      secondaryActionLabel: 'Etkinlikleri keşfet',
      onSecondaryAction: () => context.goNamed(RouteNames.events),
    );
  }
}
