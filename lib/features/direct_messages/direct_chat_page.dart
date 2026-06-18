import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/responsive_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../auth/auth_provider.dart';
import 'direct_messages_models.dart';
import 'direct_messages_provider.dart';
import 'widgets/direct_message_bubble.dart';

class DirectChatPage extends ConsumerStatefulWidget {
  const DirectChatPage({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<DirectChatPage> createState() => _DirectChatPageState();
}

class _DirectChatPageState extends ConsumerState<DirectChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref
          .read(directChatControllerProvider(widget.conversationId).notifier)
          .loadMessages();

      // If conversations list in inbox is empty, load it to fetch participant names/avatars
      final inboxState = ref.read(directInboxProvider);
      if (inboxState.conversations.isEmpty) {
        ref.read(directInboxProvider.notifier).loadInbox();
      }
    });
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text;
    if (text.trim().isEmpty) return;

    final sent = await ref
        .read(directChatControllerProvider(widget.conversationId).notifier)
        .sendMessage(text);

    if (sent) {
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<DirectChatState>(
      directChatControllerProvider(widget.conversationId),
      (previous, next) {
        final sendFailure = next.sendFailureMessage;
        if (sendFailure != null &&
            sendFailure.isNotEmpty &&
            sendFailure != previous?.sendFailureMessage) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(sendFailure)));
        }
      },
    );

    final chatState = ref.watch(
      directChatControllerProvider(widget.conversationId),
    );
    final myUserId = ref.watch(authControllerProvider).userId;

    // Try to find the conversation details from the inbox provider to get name/avatar
    final inboxState = ref.watch(directInboxProvider);
    final conversation = inboxState.conversations
        .cast<DirectConversation?>()
        .firstWhere((c) => c?.id == widget.conversationId, orElse: () => null);
    final other = conversation?.getOtherParticipant(myUserId);

    final titleText = other?.displayName ?? 'Sohbet';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            if (other != null) ...[
              other.avatarUrl != null && other.avatarUrl!.trim().isNotEmpty
                  ? CircleAvatar(
                      radius: 18,
                      backgroundImage: NetworkImage(other.avatarUrl!),
                    )
                  : CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primarySoft,
                      child: Text(
                        other.displayName.isNotEmpty
                            ? other.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Text(
                titleText,
                style: AppTextStyles.bodyStrong,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _buildChatArea(chatState, myUserId, titleText, other),
            ),
            if (chatState.replyToMessage != null)
              _ReplyPreviewBanner(
                replyToMessage: chatState.replyToMessage!,
                senderName: chatState.replyToMessage!.isMine(myUserId)
                    ? 'Sen'
                    : titleText,
                onCancel: () => ref
                    .read(
                      directChatControllerProvider(
                        widget.conversationId,
                      ).notifier,
                    )
                    .setReplyToMessage(null),
              ),
            if (!chatState.isUnavailable &&
                !(chatState.message != null && chatState.messages.isEmpty))
              _buildComposer(chatState),
          ],
        ),
      ),
    );
  }

  Widget _buildChatArea(
    DirectChatState state,
    String? myUserId,
    String senderName,
    DirectParticipant? other,
  ) {
    if (state.loading && state.messages.isEmpty) {
      return const Center(child: AppLoader());
    }

    if (state.isUnavailable) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ErrorView(
          message:
              state.message ?? 'Mesajlaşma özelliği şu anda kullanılamıyor.',
          onRetry: () => ref
              .read(
                directChatControllerProvider(widget.conversationId).notifier,
              )
              .loadMessages(),
        ),
      );
    }

    if (state.message != null && state.messages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ErrorView(
          message: state.message!,
          onRetry: () => ref
              .read(
                directChatControllerProvider(widget.conversationId).notifier,
              )
              .loadMessages(),
        ),
      );
    }

    if (state.messages.isEmpty) {
      return const EmptyState(
        title: 'Sohbeti başlatın',
        message: 'İlk mesajınızı yazarak sohbeti başlatabilirsiniz.',
        icon: Icons.forum_outlined,
      );
    }

    // Reverse messages list so that bottom is index 0 for reverse: true list view
    final reversedList = state.messages.reversed.toList();
    DirectMessage? latestOwnMessage;
    for (final candidate in reversedList) {
      if (candidate.isMine(myUserId)) {
        latestOwnMessage = candidate;
        break;
      }
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: AppResponsive.pagePadding(context),
      itemCount: reversedList.length,
      itemBuilder: (context, index) {
        final message = reversedList[index];
        final isMine = message.isMine(myUserId);

        final parentMessage = message.replyToMessageId == null
            ? null
            : state.messages.cast<DirectMessage?>().firstWhere(
                (m) => m?.id == message.replyToMessageId,
                orElse: () => null,
              );

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: DirectMessageBubble(
            message: message,
            isMine: isMine,
            senderName: senderName,
            senderAvatarUrl: other?.avatarUrl,
            replyToMessage: parentMessage,
            replySenderName: parentMessage == null
                ? null
                : parentMessage.isMine(myUserId)
                ? 'Sen'
                : senderName,
            hasReply: message.replyToMessageId != null,
            reactions: state.reactions[message.id] ?? const {},
            showSeen:
                isMine &&
                latestOwnMessage?.id == message.id &&
                _isMessageSeenByOther(message, other),
            onReact: (emoji) async {
              final controller = ref.read(
                directChatControllerProvider(widget.conversationId).notifier,
              );
              final ok = await controller.addReaction(message.id, emoji);
              if (!context.mounted || ok) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Tepki \u015Fu anda g\u00F6nderilemedi. L\u00FCtfen tekrar dene.',
                  ),
                ),
              );
            },
            onReply: () {
              ref
                  .read(
                    directChatControllerProvider(
                      widget.conversationId,
                    ).notifier,
                  )
                  .setReplyToMessage(message);
            },
            onCopy: () {
              Clipboard.setData(ClipboardData(text: message.body));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Mesaj kopyalandı.')),
              );
            },
            onReport: () => _showSafeReportDialog(
              context,
              ref,
              widget.conversationId,
              message.id,
            ),
          ),
        );
      },
    );
  }

  bool _isMessageSeenByOther(DirectMessage message, DirectParticipant? other) {
    if (other == null) return false;
    if (other.lastReadMessageId == message.id) return true;

    final lastReadAt = other.lastReadAt;
    if (lastReadAt == null) return false;
    return !message.createdAt.isAfter(lastReadAt);
  }

  Widget _buildComposer(DirectChatState state) {
    final hasText = _messageController.text.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: AppTextField(
              label: 'Mesaj',
              controller: _messageController,
              hintText: 'Mesajınızı yazın...',
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onFieldSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox.square(
            dimension: 48,
            child: FilledButton(
              onPressed: state.sending || !hasText ? null : _sendMessage,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: state.sending
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyPreviewBanner extends StatelessWidget {
  const _ReplyPreviewBanner({
    required this.replyToMessage,
    required this.senderName,
    required this.onCancel,
  });

  final DirectMessage replyToMessage;
  final String senderName;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceSoft,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Yan\u0131tlanan mesaj',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  senderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  replyToMessage.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
void _showReportDialog(
  BuildContext context,
  WidgetRef ref,
  String conversationId,
  String messageId,
) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Mesajı şikayet et'),
        content: const Text('Bu mesajı inceleme için bildirmek istiyor musun?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(directChatControllerProvider(conversationId).notifier)
                  .reportMessage(messageId, 'Kullanıcı şikayeti');
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Şikayet alındı.')));
            },
            child: const Text('Şikayet et'),
          ),
        ],
      );
    },
  );
}

void _showSafeReportDialog(
  BuildContext context,
  WidgetRef ref,
  String conversationId,
  String messageId,
) {
  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Mesaj\u0131 \u015Fikayet et'),
        content: const Text(
          'Bu mesaj\u0131 inceleme i\u00E7in bildirmek istiyor musun?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazge\u00E7'),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(dialogContext);
              final ok = await ref
                  .read(directChatControllerProvider(conversationId).notifier)
                  .reportMessage(
                    messageId,
                    'Kullan\u0131c\u0131 \u015Fikayeti',
                  );
              if (!dialogContext.mounted) return;
              navigator.pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? '\u015Eikayet al\u0131nd\u0131.'
                        : '\u015Eikayet \u015Fu anda g\u00F6nderilemedi. L\u00FCtfen tekrar dene.',
                  ),
                ),
              );
            },
            child: const Text('\u015Eikayet et'),
          ),
        ],
      );
    },
  );
}
