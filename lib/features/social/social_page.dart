import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../chat/event_chat_list_models.dart';
import '../chat/event_chat_list_provider.dart';
import '../notifications/notifications_provider.dart';
import 'widgets/social_chat_group_card.dart';
import 'widgets/social_future_messages_card.dart';

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
      ref.read(eventChatListControllerProvider.notifier).loadChatGroups();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eventChatListControllerProvider);
    if (state.status == EventChatListStatus.initial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(eventChatListControllerProvider.notifier).loadChatGroups();
      });
    }
    final groups = _filteredGroups(state.groups);

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
          onRefresh: () => ref
              .read(eventChatListControllerProvider.notifier)
              .refreshChatGroups(),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text('Chats', style: AppTextStyles.headline),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your event conversations and community activity.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Search',
                hintText: 'Find event chats...',
                controller: _searchController,
                prefixIcon: const Icon(Icons.search),
              ),
              const SizedBox(height: AppSpacing.lg),
              const SocialFutureMessagesCard(),
              const SizedBox(height: AppSpacing.xl),
              Text('Event Chats', style: AppTextStyles.title),
              const SizedBox(height: AppSpacing.md),
              if (state.isLoading && state.groups.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: AppLoader(),
                )
              else if (state.message != null)
                ErrorView(
                  message: state.message!,
                  onRetry: () => ref
                      .read(eventChatListControllerProvider.notifier)
                      .refreshChatGroups(),
                )
              else if (groups.isEmpty)
                EmptyState(
                  title: 'Henüz etkinlik sohbetin yok',
                  message:
                      'Bir etkinliğe katıldığında veya etkinlik oluşturduğunda sohbet grupların burada görünür.',
                  icon: Icons.forum_outlined,
                  actionLabel: 'Etkinlikleri keşfet',
                  onAction: () => context.goNamed(RouteNames.events),
                  secondaryActionLabel: 'Etkinlik oluştur',
                  onSecondaryAction: () => context.pushNamed(RouteNames.createEvent),
                )
              else
                ...groups.map(
                  (group) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: SocialChatGroupCard(
                      group: group,
                      onTap: () => context.pushNamed(
                        RouteNames.eventChat,
                        pathParameters: {'eventId': group.eventId},
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

  List<EventChatGroup> _filteredGroups(List<EventChatGroup> groups) {
    if (_query.isEmpty) return groups;
    return groups.where((group) {
      return group.title.toLowerCase().contains(_query) ||
          group.sportType.toLowerCase().contains(_query) ||
          group.locationLabel.toLowerCase().contains(_query) ||
          group.displaySubtitle.toLowerCase().contains(_query);
    }).toList();
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
