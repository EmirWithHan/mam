import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
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
    final comments = feedState.commentsByPostId[widget.postId] ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Comments')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _CommentsBody(
                comments: comments,
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
}

class _CommentsBody extends StatelessWidget {
  const _CommentsBody({
    required this.comments,
    required this.isLoading,
    required this.message,
  });

  final List<PostComment> comments;
  final bool isLoading;
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (isLoading && comments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
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
      return Center(
        child: Text(
          'No comments yet.',
          style: AppTextStyles.body,
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: comments.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        return CommentTile(comment: comments[index]);
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
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) {
                if (!isLoading) onSend();
              },
              decoration: const InputDecoration(
                labelText: 'Comment',
                hintText: 'Add a quick thought',
              ),
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
