import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/empty_state.dart';
import '../auth/auth_provider.dart';
import 'feed_models.dart';
import 'feed_provider.dart';
import 'widgets/comment_tile.dart';

class PostCommentsPage extends ConsumerStatefulWidget {
  const PostCommentsPage({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<PostCommentsPage> createState() => _PostCommentsPageState();
}

class _PostCommentsPageState extends ConsumerState<PostCommentsPage> {
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(feedControllerProvider.notifier).fetchComments(widget.postId);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write a comment first.')),
      );
      return;
    }

    final comment = await ref.read(feedControllerProvider.notifier).addComment(
          postId: widget.postId,
          comment: text,
        );

    if (comment != null) {
      _commentController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final comments = feedState.commentsByPostId[widget.postId] ?? const [];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => _goBack(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Comments'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _CommentsBody(
                comments: comments,
                currentUserId: authState.userId,
                isLoading: feedState.commentsLoading,
                message: feedState.commentsMessage,
              ),
            ),
            _CommentComposer(
              controller: _commentController,
              isLoading: feedState.commentsLoading,
              onSend: _sendComment,
            ),
          ],
        ),
      ),
    );
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.goNamed(RouteNames.home);
  }
}

class _CommentsBody extends StatelessWidget {
  const _CommentsBody({
    required this.comments,
    required this.currentUserId,
    required this.isLoading,
    required this.message,
  });

  final List<PostComment> comments;
  final String? currentUserId;
  final bool isLoading;
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (isLoading && comments.isEmpty) {
      return const AppLoader();
    }

    if (message != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            message!,
            style: const TextStyle(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (comments.isEmpty) {
      return const EmptyState(
        title: 'Henüz yorum yok',
        message: 'İlk yorumu sen yazabilirsin.',
        icon: Icons.mode_comment_outlined,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: comments.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        return CommentTile(
          comment: comments[index],
          currentUserId: currentUserId,
        );
      },
    );
  }
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.isLoading,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: AppTextField(
              label: 'Comment',
              hintText: 'Add a quick thought',
              controller: controller,
              prefixIcon: const Icon(Icons.mode_comment_outlined),
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onFieldSubmitted: (_) {
                if (!isLoading) onSend();
              },
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 96,
            child: AppButton(
              label: 'Send',
              isLoading: isLoading,
              onPressed: onSend,
            ),
          ),
        ],
      ),
    );
  }
}
