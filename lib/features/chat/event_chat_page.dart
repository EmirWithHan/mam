import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_text_field.dart';
import '../auth/auth_provider.dart';
import '../events/events_models.dart';
import '../events/events_provider.dart';
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
      ref
          .read(eventChatControllerProvider(widget.eventId).notifier)
          .loadMessages();
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
    final attendanceStatusAsync = ref.watch(
      eventAttendanceStatusProvider(widget.eventId),
    );
    final hasLeftEvent = EventParticipationStatus.hasLeftEvent(
      attendanceStatusAsync.valueOrNull,
    );

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => _goBack(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Event Chat'),
        actions: [
          IconButton(
            onPressed: chatState.loading
                ? null
                : () => ref
                      .read(
                        eventChatControllerProvider(widget.eventId).notifier,
                      )
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
                hasLeftEvent: hasLeftEvent,
                onRetry: () => ref
                    .read(eventChatControllerProvider(widget.eventId).notifier)
                    .refreshMessages(),
              ),
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
            if (!hasLeftEvent && chatState.access.canWrite)
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
    required this.onRetry,
  });

  final EventChatState state;
  final String? currentUserId;
  final bool hasLeftEvent;
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
        title: 'Sohbet yeni başladı',
        message:
            'Etkinlik öncesi detayları konuşmak için ilk mesajı gönderebilirsin.',
        icon: Icons.forum_outlined,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: state.messages.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
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
              width: 92,
              child: AppButton(
                label: 'Send',
                isLoading: isSending,
                onPressed: onSend,
              ),
            ),
          ],
        ),
      ),
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
