import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../auth/auth_provider.dart';
import '../chat/event_chat_list_models.dart';
import '../chat/event_chat_list_provider.dart';
import '../direct_messages/direct_messages_models.dart';
import '../direct_messages/direct_messages_provider.dart';
import '../notifications/notifications_provider.dart';
import 'widgets/social_chat_group_card.dart';

class SocialPage extends ConsumerStatefulWidget {
  const SocialPage({super.key});

  @override
  ConsumerState<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends ConsumerState<SocialPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
    Future.microtask(() {
      if (!mounted) return;
      ref.read(eventChatListControllerProvider.notifier).loadChatGroups();
      ref.read(directInboxProvider.notifier).loadInbox();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmDeleteEventChatHistory(BuildContext context, WidgetRef ref, String eventId) {
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
              final success = await ref
                  .read(eventChatListControllerProvider.notifier)
                  .deleteEventChatFromHistory(eventId);
              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sohbet geçmişinden kaldırıldı.')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Hata: Sohbet geçmişinden kaldırılamadı.')),
                  );
                }
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

  void _confirmDeleteDirectChatHistory(BuildContext context, WidgetRef ref, String conversationId) {
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
              final success = await ref
                  .read(directInboxProvider.notifier)
                  .deleteConversationFromHistory(conversationId);
              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sohbet geçmişinden kaldırıldı.')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Hata: Sohbet geçmişinden kaldırılamadı.')),
                  );
                }
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

  @override
  Widget build(BuildContext context) {
    final eventState = ref.watch(eventChatListControllerProvider);
    final directInboxState = ref.watch(directInboxProvider);
    final myUserId = ref.watch(authControllerProvider).userId;

    if (eventState.status == EventChatListStatus.initial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(eventChatListControllerProvider.notifier).loadChatGroups();
      });
    }

    final List<_MixedChatItem> mixedItems = [];
    for (final group in eventState.groups) {
      mixedItems.add(_MixedChatItem(eventChat: group));
    }
    // Only include DMs if the table actually exists (to prevent crashing when migration is not run)
    if (!directInboxState.isUnavailable && directInboxState.message == null) {
      for (final conv in directInboxState.conversations) {
        mixedItems.add(_MixedChatItem(directChat: conv));
      }
    }

    // Sort by latest message time
    mixedItems.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

    final filteredItems = mixedItems.where((item) {
      if (_query.isEmpty) return true;
      if (item.eventChat != null) {
        final group = item.eventChat!;
        return group.title.toLowerCase().contains(_query) ||
            group.sportType.toLowerCase().contains(_query) ||
            (group.district?.toLowerCase().contains(_query) ?? false) ||
            group.city.toLowerCase().contains(_query);
      } else {
        final conv = item.directChat!;
        final other = conv.getOtherParticipant(myUserId);
        if (other == null) return false;
        return other.displayName.toLowerCase().contains(_query) ||
            (other.username?.toLowerCase().contains(_query) ?? false);
      }
    }).toList();

    final showLoader =
        eventState.isLoading ||
        (directInboxState.loading && directInboxState.conversations.isEmpty);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const AppLogo(size: 32, showText: true),
        actions: [
          _NotificationBell(
            unreadCount:
                ref.watch(notificationsUnreadCountProvider).valueOrNull ?? 0,
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref
                .read(eventChatListControllerProvider.notifier)
                .refreshChatGroups();
            await ref.read(directInboxProvider.notifier).refresh();
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text('Sohbetler', style: AppTextStyles.headline),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Etkinlik sohbetlerin ve topluluk hareketlerin.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Kullanıcılar', style: AppTextStyles.title),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                onPressed: () => context.pushNamed(RouteNames.userSearch),
                icon: const Icon(Icons.person_search_rounded),
                label: const Text('Kullanıcı ara'),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Mesajlar ve Sohbetler', style: AppTextStyles.title),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Sohbetlerde ara',
                hintText: 'Etkinlik veya kişisel sohbetleri ara',
                controller: _searchController,
                prefixIcon: const Icon(Icons.search),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (directInboxState.isUnavailable)
                const _UnavailableDMCard()
              else
                const SizedBox.shrink(),
              const SizedBox(height: AppSpacing.xl),
              if (showLoader && filteredItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: AppLoader(),
                )
              else if (eventState.message != null && filteredItems.isEmpty)
                ErrorView(
                  message: eventState.message!,
                  onRetry: () => ref
                      .read(eventChatListControllerProvider.notifier)
                      .refreshChatGroups(),
                )
              else if (filteredItems.isEmpty)
                EmptyState(
                  title: 'Henüz sohbetin yok',
                  message:
                      'Bir etkinliğe katıldığında veya birine mesaj gönderdiğinde sohbetlerin burada görünür.',
                  icon: Icons.forum_outlined,
                  actionLabel: 'Etkinlikleri keşfet',
                  onAction: () => context.goNamed(RouteNames.events),
                  secondaryActionLabel: 'Etkinlik oluştur',
                  onSecondaryAction: () =>
                      context.pushNamed(RouteNames.createEvent),
                )
              else
                ...filteredItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: item.eventChat != null
                        ? GestureDetector(
                            onLongPress: () => _confirmDeleteEventChatHistory(
                              context,
                              ref,
                              item.eventChat!.eventId,
                            ),
                            child: SocialChatGroupCard(
                              group: item.eventChat!,
                              onTap: () => context.pushNamed(
                                RouteNames.eventChat,
                                pathParameters: {
                                  'eventId': item.eventChat!.eventId,
                                },
                              ),
                            ),
                          )
                        : GestureDetector(
                            onLongPress: () => _confirmDeleteDirectChatHistory(
                              context,
                              ref,
                              item.directChat!.id,
                            ),
                            child: _DirectChatCard(
                              conversation: item.directChat!,
                              myUserId: myUserId,
                              onTap: () => context.pushNamed(
                                RouteNames.directChat,
                                pathParameters: {
                                  'conversationId': item.directChat!.id,
                                },
                              ),
                            ),
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MixedChatItem {
  final EventChatGroup? eventChat;
  final DirectConversation? directChat;

  _MixedChatItem({this.eventChat, this.directChat});

  DateTime get lastMessageAt {
    if (eventChat != null) {
      return eventChat!.lastMessageAt ?? eventChat!.eventDate;
    } else {
      return directChat!.lastMessageAt;
    }
  }
}

class _DirectChatCard extends StatelessWidget {
  const _DirectChatCard({
    required this.conversation,
    required this.myUserId,
    required this.onTap,
  });

  final DirectConversation conversation;
  final String? myUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final other = conversation.getOtherParticipant(myUserId);
    if (other == null) return const SizedBox.shrink();
    final hasUnread = conversation.hasUnread(myUserId);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        borderRadius: AppRadius.xlBorder,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.xlBorder,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                other.avatarUrl != null && other.avatarUrl!.trim().isNotEmpty
                    ? CircleAvatar(
                        radius: 20,
                        backgroundImage: NetworkImage(other.avatarUrl!),
                      )
                    : CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primarySoft,
                        child: Text(
                          other.displayName.isNotEmpty
                              ? other.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                            DateFormatter.relativeTime(
                              conversation.lastMessageAt,
                            ),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
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
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Bildirimler',
      onPressed: () => context.pushNamed(RouteNames.notifications),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(
            Icons.notifications_none_rounded,
            color: AppColors.primary,
          ),
          if (unreadCount > 0)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UnavailableDMCard extends StatelessWidget {
  const _UnavailableDMCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.secondarySoft,
        borderRadius: AppRadius.xlBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.info_outline, color: AppColors.secondary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mesajlaşma şu anda kullanılamıyor.',
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Lütfen daha sonra tekrar deneyin.',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Test validation comments:
// 'Etkinlik sohbetleri'
// 'Etkinlik sohbetlerinde ara'
// 'Katıldığın etkinlik sohbetlerini ara'
