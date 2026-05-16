import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
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

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const AppLogo(size: 32, showText: true),
        actions: [
          if (widget.showNotificationBell)
            IconButton(
              tooltip: 'Bildirimler',
              onPressed: () => context.goNamed(RouteNames.notifications),
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: AppColors.primary,
              ),
            ),
          if (widget.showNotificationBell)
            const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              const SizedBox(height: AppSpacing.md),
              if (widget.showCreatePrompt) ...[
                DecoratedBox(
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
                            onPressed: () =>
                                context.goNamed(RouteNames.createPost),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              Expanded(
                child: _FeedBody(
                  feedState: feedState,
                  showCreateAction: widget.showCreatePrompt,
                ),
              ),
            ],
          ),
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
    if (feedState.isLoading) {
      return const AppLoader();
    }

    if (feedState.status == FeedStatus.error) {
      return ErrorView(
        message: feedState.message ?? 'Could not load feed.',
      );
    }

    if (feedState.posts.isEmpty) {
      return EmptyState(
        title: 'Henüz paylaşım yok',
        message: 'Bir fotoğraf paylaşarak topluluğa ilk anı sen bırakabilirsin.',
        icon: Icons.add_photo_alternate_outlined,
        actionLabel: showCreateAction ? 'Fotoğraf paylaş' : null,
        onAction:
            showCreateAction ? () => context.goNamed(RouteNames.createPost) : null,
        secondaryActionLabel: 'Etkinlikleri keşfet',
        onSecondaryAction: () => context.goNamed(RouteNames.events),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(feedControllerProvider.notifier).refreshPosts();
      },
      child: ListView.separated(
        itemCount: feedState.posts.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final item = feedState.posts[index];
          return PostCard(
            item: item,
            onToggleLike: () {
              ref.read(feedControllerProvider.notifier).toggleLike(item);
            },
            onOpenComments: () => context.goNamed(
              RouteNames.postComments,
              pathParameters: {'postId': item.post.id},
            ),
          );
        },
      ),
    );
  }
}
