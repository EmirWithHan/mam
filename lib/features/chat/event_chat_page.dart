import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_text_field.dart';
import '../auth/auth_provider.dart';
import 'event_chat_provider.dart';
import 'widgets/message_bubble.dart';

class EventChatPage extends ConsumerStatefulWidget {
  const EventChatPage({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<EventChatPage> createState() => _EventChatPageState();
}

class _EventChatPageState extends ConsumerState<EventChatPage> {
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(eventChatControllerProvider(widget.eventId).notifier).loadMessages();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final sent = await ref
        .read(eventChatControllerProvider(widget.eventId).notifier)
        .sendMessage(_messageController.text);

    if (sent) {
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(eventChatControllerProvider(widget.eventId));
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MaM'),
        actions: [
          IconButton(
            onPressed: chatState.loading
                ? null
                : () => ref
                    .read(eventChatControllerProvider(widget.eventId).notifier)
                    .refreshMessages(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _ChatBody(
                state: chatState,
                currentUserId: authState.userId,
              ),
            ),
            if (chatState.access.canRead && !chatState.access.canWrite)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'This chat is archived.',
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
              ),
            if (chatState.access.canWrite)
              _MessageComposer(
                controller: _messageController,
                isSending: chatState.sending,
                onSend: _sendMessage,
              ),
          ],
        ),
      ),
    );
  }
}

class _ChatBody extends StatelessWidget {
  const _ChatBody({
    required this.state,
    required this.currentUserId,
  });

  final EventChatState state;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    if (state.loading && state.messages.isEmpty) {
      return const AppLoader();
    }

    if (state.message != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            state.message!,
            style: const TextStyle(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (!state.access.canRead) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            state.access.reason ??
                'Only the host and approved participants can access this chat.',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (state.messages.isEmpty) {
      return Center(
        child: Text(
          'No messages yet.',
          style: AppTextStyles.body,
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: state.messages.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final message = state.messages[index];
        return MessageBubble(
          message: message,
          isMine: message.isMine(currentUserId),
        );
      },
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
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
                label: 'Message',
                hintText: 'Write to the group',
                controller: controller,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onFieldSubmitted: (_) {
                  if (!isSending) onSend();
                },
              ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 96,
            child: AppButton(
              label: 'Send',
              isLoading: isSending,
              onPressed: onSend,
            ),
          ),
        ],
      ),
    );
  }
}
