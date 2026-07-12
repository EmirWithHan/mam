import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/responsive_layout.dart';
import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_text_field.dart';
import '../auth/auth_provider.dart';
import '../events/events_models.dart';
import '../events/events_provider.dart';
import '../profile/widgets/public_profile_name.dart';
import 'event_chat_models.dart';
import 'event_chat_list_provider.dart';
import 'event_chat_provider.dart';
import 'widgets/message_bubble.dart';
import 'widgets/poll_card.dart';

class EventChatPage extends ConsumerStatefulWidget {
  const EventChatPage({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<EventChatPage> createState() => _EventChatPageState();
}

class _EventChatPageState extends ConsumerState<EventChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageTextChanged);
    Future.microtask(() {
      if (!mounted) return;
      ref
          .read(eventChatControllerProvider(widget.eventId).notifier)
          .loadMessages()
          .then((_) => _scrollToBottom(jump: true));
    });
  }

  @override
  void dispose() {
    _messageController.removeListener(_onMessageTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onMessageTextChanged() {
    setState(() {});
  }

  String? _getMentionQuery() {
    final text = _messageController.text;
    final selection = _messageController.selection;
    if (!selection.isValid || selection.baseOffset <= 0) return null;

    final beforeCursor = text.substring(0, selection.baseOffset);
    final lastWordStart = beforeCursor.lastIndexOf(' ');
    final currentWord = lastWordStart == -1
        ? beforeCursor
        : beforeCursor.substring(lastWordStart + 1);

    if (currentWord.startsWith('@')) {
      return currentWord.substring(1);
    }
    return null;
  }

  List<String> _extractMentionUserIds(
    String text,
    List<EventPublicParticipant> participants,
  ) {
    final words = text.split(RegExp(r'\s+'));
    final userIds = <String>[];
    for (final word in words) {
      if (word.startsWith('@')) {
        final username = word.substring(1).replaceAll(RegExp(r'[^\w\d_]'), '');
        final match = participants.cast<EventPublicParticipant?>().firstWhere(
          (p) => (p?.username ?? '').toLowerCase() == username.toLowerCase(),
          orElse: () => null,
        );
        if (match != null && !userIds.contains(match.userId)) {
          userIds.add(match.userId);
        }
      }
    }
    return userIds;
  }

  Future<void> _sendMessage() async {
    final chatState = ref.read(eventChatControllerProvider(widget.eventId));
    final mentionIds = _extractMentionUserIds(
      _messageController.text,
      chatState.participants,
    );

    final sent = await ref
        .read(eventChatControllerProvider(widget.eventId).notifier)
        .sendMessage(_messageController.text, mentionUserIds: mentionIds);

    if (sent) {
      _messageController.clear();
      _scrollToBottom();
    }
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (jump) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<EventChatState>(eventChatControllerProvider(widget.eventId), (
      previous,
      next,
    ) {
      final sendFailure = next.sendFailureMessage;
      if (sendFailure != null &&
          sendFailure.isNotEmpty &&
          sendFailure != previous?.sendFailureMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(sendFailure)));
      }

      final previousLastId = previous?.messages.lastOrNull?.id;
      final nextLastId = next.messages.lastOrNull?.id;
      if (previousLastId != nextLastId) {
        _scrollToBottom();
      }
    });
    final chatState = ref.watch(eventChatControllerProvider(widget.eventId));
    final authState = ref.watch(authControllerProvider);
    final attendanceStatusAsync = ref.watch(
      eventAttendanceStatusProvider(widget.eventId),
    );
    final eventAsync = ref.watch(eventDetailProvider(widget.eventId));
    final hasLeftEvent = EventParticipationStatus.hasLeftEvent(
      attendanceStatusAsync.valueOrNull,
    );

    final mentionQuery = _getMentionQuery();
    List<EventPublicParticipant> filteredParticipants = [];
    if (mentionQuery != null) {
      filteredParticipants = chatState.participants.where((p) {
        final name = (p.username ?? '').toLowerCase();
        final firstName = (p.firstName ?? '').toLowerCase();
        final q = mentionQuery.toLowerCase();
        return name.contains(q) || firstName.contains(q);
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Geri',
          onPressed: () => _goBack(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              eventAsync.when(
                data: (event) => event.titleLabel,
                loading: () => 'Yükleniyor...',
                error: (err, stack) => 'Etkinlik Sohbeti',
              ),
              style: AppTextStyles.bodyStrong.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Text(
              'Etkinlik sohbeti',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete_history') {
                _confirmDeleteEventChatHistory();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete_history',
                child: Text('Sohbet geçmişinden sil'),
              ),
            ],
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
                hasLeftEvent: hasLeftEvent,
                scrollController: _scrollController,
                onRetry: () => ref
                    .read(eventChatControllerProvider(widget.eventId).notifier)
                    .refreshMessages(),
              ),
            ),
            if (filteredParticipants.isNotEmpty)
              _buildMentionSuggestions(filteredParticipants),
            if (chatState.replyToMessage != null)
              _ReplyPreviewBanner(
                replyToMessage: chatState.replyToMessage!,
                onCancel: () => ref
                    .read(eventChatControllerProvider(widget.eventId).notifier)
                    .setReplyToMessage(null),
              ),
            if (!hasLeftEvent &&
                chatState.access.canRead &&
                !chatState.access.canWrite)
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: _ChatNotice(
                  icon: Icons.lock_clock_outlined,
                  message: 'Bu sohbet arşivlendi.',
                  color: AppColors.warning,
                  background: AppColors.tertiarySoft,
                ),
              ),
            if (!hasLeftEvent &&
                chatState.access.canWrite &&
                chatState.message == null)
              _MessageComposer(
                controller: _messageController,
                isSending: chatState.sending,
                onSend: _sendMessage,
                onOpenPollDialog: () =>
                    _showCreatePollDialog(context, ref, widget.eventId),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMentionSuggestions(List<EventPublicParticipant> participants) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 60),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        itemCount: participants.length,
        itemBuilder: (context, index) {
          final p = participants[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ActionChip(
              avatar: p.avatarUrl != null && p.avatarUrl!.trim().isNotEmpty
                  ? CircleAvatar(backgroundImage: NetworkImage(p.avatarUrl!))
                  : CircleAvatar(
                      child: Text(
                        (p.firstName?.isNotEmpty == true)
                            ? p.firstName![0].toUpperCase()
                            : '?',
                      ),
                    ),
              label: Text('@${p.username}'),
              onPressed: () {
                final text = _messageController.text;
                final selection = _messageController.selection;
                final beforeCursor = text.substring(0, selection.baseOffset);
                final lastWordStart = beforeCursor.lastIndexOf(' ');
                final prefix = lastWordStart == -1
                    ? ''
                    : beforeCursor.substring(0, lastWordStart + 1);
                final suffix = text.substring(selection.baseOffset);

                _messageController.text = '$prefix@${p.username} $suffix';
                _messageController.selection = TextSelection.fromPosition(
                  TextPosition(offset: '$prefix@${p.username} '.length),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteEventChatHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sohbet geçmişinden silinsin mi?'),
        content: const Text(
          'Bu işlem sohbeti yalnızca senin geçmişinden kaldırır. Mesajlar karşı taraftan silinmez. Yeni mesaj gelirse sohbet tekrar görünür.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(eventChatListControllerProvider.notifier)
                  .deleteEventChatFromHistory(widget.eventId);
              if (mounted) {
                _goBack(context);
              }
            },
            child: const Text(
              'Sil',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.goNamed(RouteNames.events);
  }
}

class _ChatBody extends StatelessWidget {
  const _ChatBody({
    required this.state,
    required this.currentUserId,
    required this.hasLeftEvent,
    required this.scrollController,
    required this.onRetry,
  });

  final EventChatState state;
  final String? currentUserId;
  final bool hasLeftEvent;
  final ScrollController scrollController;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.loading && state.messages.isEmpty) {
      return const AppLoader();
    }

    if (state.message != null) {
      return ErrorView(message: state.message!, onRetry: onRetry);
    }

    if (hasLeftEvent) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: _ChatNotice(
            icon: Icons.logout_rounded,
            message: 'Bu etkinlikten çıktığın için sohbet erişimin kapatıldı.',
            color: AppColors.textMuted,
            background: AppColors.border,
          ),
        ),
      );
    }

    if (!state.access.canRead) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: _ChatNotice(
            icon: Icons.lock_outline,
            message:
                state.access.reason ??
                'Sadece ev sahibi ve onaylı katılımcılar bu sohbete erişebilir.',
            color: AppColors.primary,
            background: AppColors.primarySoft,
          ),
        ),
      );
    }

    if (state.messages.isEmpty) {
      return const EmptyState(
        title: 'Henüz mesaj yok.',
        message: 'İlk mesajı sen gönder.',
        icon: Icons.forum_outlined,
      );
    }

    return ListView.separated(
      controller: scrollController,
      reverse: false,
      padding: AppResponsive.pagePadding(context),
      itemCount: state.messages.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final message = state.messages[index];
        final isPoll = message.metadata['type'] == 'poll';
        if (isPoll && message.metadata['poll_id'] != null) {
          return PollCard(
            pollId: message.metadata['poll_id'].toString(),
            eventId: message.eventId,
          );
        }

        final parentMessage = message.replyToMessageId == null
            ? null
            : state.messages.cast<EventMessage?>().firstWhere(
                (m) => m?.id == message.replyToMessageId,
                orElse: () => null,
              );

        return Consumer(
          builder: (context, ref, child) {
            final controller = ref.read(
              eventChatControllerProvider(message.eventId).notifier,
            );
            return MessageBubble(
              message: message,
              isMine: message.isMine(currentUserId),
              replyToMessage: parentMessage,
              hasReply: message.replyToMessageId != null,
              reactions: state.reactions[message.id] ?? const {},
              readBy: state.readReceipts[message.id] ?? const [],
              onReact: (emoji) async {
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
              onReply: () => controller.setReplyToMessage(message),
              onCopy: () {
                Clipboard.setData(ClipboardData(text: message.message));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mesaj kopyalandı.')),
                );
              },
              onReport: () => _showSafeReportDialog(
                context,
                ref,
                message.eventId,
                message.id,
              ),
            );
          },
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
    required this.onOpenPollDialog,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onOpenPollDialog;

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.trim().isNotEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Padding(
        padding: AppResponsive.cardPadding(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              tooltip: 'Ekle',
              onPressed: () => _showChatActionSheet(context),
              icon: const Icon(
                Icons.add_circle_outline_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: AppTextField(
                label: 'Mesaj',
                hintText: 'Gruba yaz',
                controller: controller,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onFieldSubmitted: (_) {
                  if (!isSending && hasText) onSend();
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox.square(
              dimension: 52,
              child: Tooltip(
                message: 'Mesaj gönder',
                child: FilledButton(
                  onPressed: isSending || !hasText ? null : onSend,
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.mdBorder,
                    ),
                  ),
                  child: isSending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChatActionSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.poll_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('Anket oluştur'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onOpenPollDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChatNotice extends StatelessWidget {
  const _ChatNotice({
    required this.icon,
    required this.message,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String message;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.lgBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: Text(
                message,
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.left,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplyPreviewBanner extends StatelessWidget {
  const _ReplyPreviewBanner({
    required this.replyToMessage,
    required this.onCancel,
  });

  final EventMessage replyToMessage;
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
                PublicProfileName(
                  userId: replyToMessage.senderId,
                  showUsernameTag: false,
                  compact: true,
                  textStyle: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  replyToMessage.message,
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

void _showCreatePollDialog(
  BuildContext context,
  WidgetRef ref,
  String eventId,
) {
  showDialog(
    context: context,
    builder: (context) {
      return _CreatePollDialog(eventId: eventId);
    },
  );
}

class _CreatePollDialog extends ConsumerStatefulWidget {
  const _CreatePollDialog({required this.eventId});

  final String eventId;

  @override
  ConsumerState<_CreatePollDialog> createState() => _CreatePollDialogState();
}

class _CreatePollDialogState extends ConsumerState<_CreatePollDialog> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final _options = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_options.length >= 5) return;
    setState(() {
      _options.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_options.length <= 2) return;
    setState(() {
      final c = _options.removeAt(index);
      c.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Anket oluştur'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _questionController,
                decoration: const InputDecoration(
                  labelText: 'Soru',
                  hintText: 'Sormak istediğin soru nedir?',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Soru gerekli.';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              ...List.generate(_options.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _options[index],
                          decoration: InputDecoration(
                            labelText: '${index + 1}. Seçenek',
                            hintText: 'Seçenek yaz',
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Seçenek gerekli.';
                            }
                            return null;
                          },
                        ),
                      ),
                      if (_options.length > 2)
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            color: AppColors.error,
                          ),
                          onPressed: () => _removeOption(index),
                        ),
                    ],
                  ),
                );
              }),
              if (_options.length < 5)
                TextButton.icon(
                  onPressed: _addOption,
                  icon: const Icon(Icons.add),
                  label: const Text('Seçenek ekle'),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              final question = _questionController.text.trim();
              final optionTexts = _options.map((c) => c.text.trim()).toList();

              ref
                  .read(eventChatControllerProvider(widget.eventId).notifier)
                  .createPoll(question: question, options: optionTexts);
              Navigator.pop(context);
            }
          },
          child: const Text('Anketi gönder'),
        ),
      ],
    );
  }
}

// ignore: unused_element
void _showReportDialog(
  BuildContext context,
  WidgetRef ref,
  String eventId,
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
                  .read(eventChatControllerProvider(eventId).notifier)
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
  String eventId,
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
                  .read(eventChatControllerProvider(eventId).notifier)
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
