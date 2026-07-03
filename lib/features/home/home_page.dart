import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/responsive_layout.dart';
import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../auth/auth_provider.dart';
import '../events/events_models.dart';
import '../events/widgets/event_card.dart';
import '../feed/feed_models.dart';
import '../feed/feed_provider.dart';
import '../feed/widgets/post_card.dart';
import '../notifications/notifications_provider.dart';
import 'home_feed_provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(homeFeedProvider.notifier).loadFeed();
      ref
          .read(notificationsControllerProvider.notifier)
          .startRealtime(ref.read(authControllerProvider).userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<FeedState>(feedControllerProvider, (previous, next) {
      if (next.message != null && next.message != previous?.message) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.message!)));
      }
    });

    final feedState = ref.watch(homeFeedProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const AppLogo(size: 32, showText: true),
        actions: [
          _NotificationBell(
            unreadCount:
                ref.watch(notificationsUnreadCountProvider).valueOrNull ?? 0,
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(homeFeedProvider.notifier).refreshFeed(),
          child: _buildBody(feedState),
        ),
      ),
    );
  }

  Widget _buildBody(HomeFeedState feedState) {
    if (feedState.isLoading && feedState.items.isEmpty) {
      return const Center(child: AppLoader());
    }

    if (feedState.status == HomeFeedStatus.error && feedState.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppResponsive.pagePadding(context),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.5,
            child: ErrorView(
              message: feedState.message ?? 'Akış yüklenirken bir hata oluştu.',
              onRetry: () => ref.read(homeFeedProvider.notifier).refreshFeed(),
            ),
          ),
        ],
      );
    }

    if (feedState.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppResponsive.pagePadding(context),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.5,
            child: EmptyState(
              title: 'Henüz paylaşım yok',
              message:
                  'Takip ettiğin kişilerin paylaşımları ve topluluk anları burada görünecek.',
              icon: Icons.add_photo_alternate_outlined,
              actionLabel: 'Fotoğraf Paylaş',
              onAction: () => context.pushNamed(RouteNames.createPost),
              secondaryActionLabel: 'Etkinlikleri Keşfet',
              onSecondaryAction: () => context.goNamed(RouteNames.events),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppResponsive.pagePadding(context),
      itemCount: feedState.items.length + 1,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Senin İçin Seçilenler',
                    style: AppTextStyles.headline.copyWith(fontSize: 20),
                  ),
                ),
              ],
            ),
          );
        }

        final item = feedState.items[index - 1];

        if (item is PostWithStats) {
          final feedState = ref.watch(feedControllerProvider);
          final updatedItem = feedState.posts.firstWhere(
            (p) => p.post.id == item.post.id,
            orElse: () => item,
          );
          return PostCard(
            key: ValueKey(updatedItem.post.id),
            item: updatedItem,
            isLikeLoading: feedState.isLikeLoading(updatedItem.post.id),
            onToggleLike: () {
              ref.read(feedControllerProvider.notifier).toggleLike(updatedItem);
            },
            onOpenComments: () => context.pushNamed(
              RouteNames.postComments,
              pathParameters: {'postId': updatedItem.post.id},
            ),
          );
        } else if (item is Event) {
          return EventCard(event: item);
        }

        return const SizedBox.shrink();
      },
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
