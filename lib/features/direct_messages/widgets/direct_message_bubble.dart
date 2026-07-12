import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_formatter.dart';
import '../../profile/widgets/safe_avatar.dart';
import '../direct_messages_models.dart';

const _reactionEmojis = <String>[
  '\u{1F44D}',
  '\u2764\uFE0F',
  '\u{1F602}',
  '\u{1F62E}',
  '\u{1F44F}',
];

class DirectMessageBubble extends StatelessWidget {
  const DirectMessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.senderName,
    this.senderAvatarUrl,
    this.replyToMessage,
    this.replySenderName,
    this.hasReply = false,
    this.reactions = const {},
    this.showSeen = false,
    this.onReact,
    this.onReply,
    this.onCopy,
    this.onReport,
  });

  final DirectMessage message;
  final bool isMine;
  final String senderName;
  final String? senderAvatarUrl;
  final DirectMessage? replyToMessage;
  final String? replySenderName;
  final bool hasReply;
  final Map<String, List<String>> reactions;
  final bool showSeen;
  final Function(String emoji)? onReact;
  final VoidCallback? onReply;
  final VoidCallback? onCopy;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    const bubbleColor = AppColors.surface;
    final borderColor = isMine
        ? AppColors.primary.withValues(alpha: 0.45)
        : AppColors.border;
    final bubble = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: bubbleColor,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppRadius.lg),
                topRight: Radius.circular(AppRadius.lg),
                bottomLeft: Radius.circular(
                  isMine ? AppRadius.lg : AppRadius.sm,
                ),
                bottomRight: Radius.circular(
                  isMine ? AppRadius.sm : AppRadius.lg,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (replyToMessage != null || hasReply) ...[
                    _DirectReplyQuote(
                      message: replyToMessage,
                      senderName: replySenderName,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  Text(
                    message.body,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    DateFormatter.time(message.createdAt),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showSeen) ...[
            const SizedBox(height: 3),
            Text(
              'G\u00F6r\u00FCld\u00FC',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (reactions.isNotEmpty) ...[
            const SizedBox(height: 4),
            _ReactionsRow(reactions: reactions, onReact: onReact),
          ],
        ],
      ),
    );

    return Dismissible(
      key: Key('reply-${message.id}'),
      direction: DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.28,
        DismissDirection.endToStart: 0.28,
      },
      confirmDismiss: (_) async {
        HapticFeedback.selectionClick();
        onReply?.call();
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.reply_rounded, color: AppColors.primary),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.reply_rounded, color: AppColors.primary),
      ),
      child: GestureDetector(
        onLongPress: () => _showLongPressMenu(context),
        child: Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: isMine
              ? bubble
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SafeAvatar(
                      radius: 16,
                      avatarUrl: senderAvatarUrl,
                      fallbackText: senderName.isEmpty ? 'M' : senderName[0],
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(child: bubble),
                  ],
                ),
        ),
      ),
    );
  }

  void _showLongPressMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emoji reactions are disabled for the initial release candidate.
              ListTile(
                leading: const Icon(Icons.reply_outlined),
                title: const Text('Yan\u0131tla'),
                onTap: () {
                  Navigator.pop(context);
                  onReply?.call();
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Kopyala'),
                onTap: () {
                  Navigator.pop(context);
                  onCopy?.call();
                },
              ),
              if (!isMine && onReport != null)
                ListTile(
                  leading: const Icon(Icons.report_problem_outlined),
                  title: const Text('\u015Eikayet et'),
                  onTap: () {
                    Navigator.pop(context);
                    onReport?.call();
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DirectReplyQuote extends StatelessWidget {
  const _DirectReplyQuote({required this.message, required this.senderName});

  final DirectMessage? message;
  final String? senderName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: const Border(
          left: BorderSide(color: AppColors.primary, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            senderName ?? 'Yan\u0131tlanan mesaj',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            message?.body ??
                'Mesaj art\u0131k g\u00F6r\u00FCnt\u00FClenemiyor.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionsRow extends StatelessWidget {
  const _ReactionsRow({required this.reactions, this.onReact});

  final Map<String, List<String>> reactions;
  final Function(String emoji)? onReact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: reactions.entries.map((entry) {
        final emoji = entry.key;
        final count = entry.value.length;
        return GestureDetector(
          onTap: () => onReact?.call(emoji),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: AppRadius.pillBorder,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(
                    '$count',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
