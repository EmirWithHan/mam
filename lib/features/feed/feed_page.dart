import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import 'feed_provider.dart';
import 'widgets/post_card.dart';

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

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
      appBar: AppBar(title: const Text('MaM')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Home', style: AppTextStyles.headline),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Moments from the community',
                style: AppTextStyles.subtitle,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Share a moment',
                onPressed: () => context.goNamed(RouteNames.createPost),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(child: _FeedBody(feedState: feedState)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedBody extends ConsumerWidget {
  const _FeedBody({required this.feedState});

  final FeedState feedState;

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
      return const EmptyState(
        title: 'No moments yet.',
        message: 'Share the first photo from the community.',
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
