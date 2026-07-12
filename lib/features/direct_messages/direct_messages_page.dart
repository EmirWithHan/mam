import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/responsive_layout.dart';
import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../auth/auth_provider.dart';
import 'direct_messages_provider.dart';

class DirectConversationsPage extends ConsumerStatefulWidget {
  const DirectConversationsPage({super.key});

  @override
  ConsumerState<DirectConversationsPage> createState() =>
      _DirectConversationsPageState();
}

class _DirectConversationsPageState
    extends ConsumerState<DirectConversationsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(directInboxProvider.notifier).loadInbox();
    });
  }

  void _confirmDeleteConversation(String conversationId) {
    final pageContext = context;
    showDialog(
      context: pageContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sohbet geçmişinden silinsin mi?'),
        content: const Text(
          'Bu işlem sohbeti yalnızca senin geçmişinden kaldırır. Mesajlar karşı taraftan silinmez. Yeni mesaj gelirse sohbet tekrar görünür.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await ref
                  .read(directInboxProvider.notifier)
                  .deleteConversationFromHistory(conversationId);
              if (pageContext.mounted) {
                if (success) {
                  ScaffoldMessenger.of(pageContext).showSnackBar(
                    const SnackBar(
                      content: Text('Sohbet geçmişinden kaldırıldı.'),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(pageContext).showSnackBar(
                    const SnackBar(
                      content: Text('Hata: Sohbet geçmişinden kaldırılamadı.'),
                    ),
                  );
                }
              }
            },
            child: const Text('Sil', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inboxState = ref.watch(directInboxProvider);
    final myUserId = ref.watch(authControllerProvider).userId;

    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('Mesajlar')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(directInboxProvider.notifier).refresh(),
          child: _buildBody(inboxState, myUserId),
        ),
      ),
    );
  }

  Widget _buildBody(DirectInboxState state, String? myUserId) {
    if (state.loading && state.conversations.isEmpty) {
      return const Center(child: AppLoader());
    }

    if (state.isUnavailable) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ErrorView(
          message:
              state.message ?? 'Mesajlaşma özelliği şu anda kullanılamıyor.',
          onRetry: () => ref.read(directInboxProvider.notifier).refresh(),
        ),
      );
    }

    if (state.message != null && state.conversations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ErrorView(
          message: state.message!,
          onRetry: () => ref.read(directInboxProvider.notifier).refresh(),
        ),
      );
    }

    if (state.conversations.isEmpty) {
      return const EmptyState(
        title: 'Henüz mesajın yok.',
        message: 'Bir profile giderek mesaj göndermeye başlayabilirsin.',
        icon: Icons.forum_outlined,
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppResponsive.pagePadding(context),
      itemCount: state.conversations.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, color: AppColors.border),
      itemBuilder: (context, index) {
        final conversation = state.conversations[index];
        final other = conversation.getOtherParticipant(myUserId);
        if (other == null) return const SizedBox.shrink();

        final hasUnread = conversation.hasUnread(myUserId);

        return ListTile(
          onLongPress: () => _confirmDeleteConversation(conversation.id),
          contentPadding: const EdgeInsets.symmetric(
            vertical: AppSpacing.xs,
            horizontal: AppSpacing.sm,
          ),
          leading: other.avatarUrl != null && other.avatarUrl!.trim().isNotEmpty
              ? CircleAvatar(
                  radius: 24,
                  backgroundImage: NetworkImage(other.avatarUrl!),
                )
              : CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primarySoft,
                  child: Text(
                    other.displayName.isNotEmpty
                        ? other.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  other.displayName,
                  style: AppTextStyles.bodyStrong.copyWith(
                    fontWeight: hasUnread ? FontWeight.bold : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                DateFormatter.relativeTime(conversation.lastMessageAt),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    conversation.lastMessagePreview ?? 'Mesaj yok',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: hasUnread
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: hasUnread ? FontWeight.bold : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasUnread) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
          onTap: () {
            context.pushNamed(
              RouteNames.directChat,
              pathParameters: {'conversationId': conversation.id},
            );
          },
        );
      },
    );
  }
}
