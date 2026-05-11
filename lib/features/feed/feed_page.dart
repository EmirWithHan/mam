import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
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
      appBar: AppBar(title: const Text('Feed')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Moments from the community', style: AppTextStyles.title),
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
      return const Center(child: CircularProgressIndicator());
    }

    if (feedState.status == FeedStatus.error) {
      return Center(
        child: Text(
          feedState.message ?? 'Could not load feed.',
          textAlign: TextAlign.center,
        ),
      );
    }

    if (feedState.posts.isEmpty) {
      return Center(
        child: Text(
          'No moments yet. Share the first photo from the community.',
          style: AppTextStyles.body,
          textAlign: TextAlign.center,
        ),
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
          return PostCard(post: feedState.posts[index]);
        },
      ),
    );
  }
}
