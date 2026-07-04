import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/responsive_layout.dart';
import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../auth/auth_provider.dart';
import '../profile/widgets/public_profile_avatar.dart';
import 'notifications_models.dart';
import 'notifications_provider.dart';
import 'widgets/notification_tile.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(notificationsControllerProvider.notifier).loadNotifications();
      ref
          .read(notificationsControllerProvider.notifier)
          .startRealtime(ref.read(authControllerProvider).userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsControllerProvider);

    final pendingFollowRequests = state.notifications
        .where((n) => n.isFollowRequest && n.canRespondToFollowRequest)
        .toList();

    final remainingNotifications = state.notifications
        .where((n) => !(n.isFollowRequest && n.canRespondToFollowRequest))
        .toList();

    // Grouping by time
    final now = DateTime.now();
    final todayNotifications = <AppNotification>[];
    final thisWeekNotifications = <AppNotification>[];
    final earlierNotifications = <AppNotification>[];

    for (final notification in remainingNotifications) {
      final diff = now.difference(notification.createdAt);
      if (notification.createdAt.year == now.year &&
          notification.createdAt.month == now.month &&
          notification.createdAt.day == now.day) {
        todayNotifications.add(notification);
      } else if (diff.inDays < 7) {
        thisWeekNotifications.add(notification);
      } else {
        earlierNotifications.add(notification);
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Geri',
          onPressed: () => _goBack(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const AppLogo(size: 32, showText: true),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref
              .read(notificationsControllerProvider.notifier)
              .refreshNotifications(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppResponsive.pagePadding(context),
            children: [
              _NotificationsHeader(
                unreadCount: state.unreadCount,
                isUpdating: state.isUpdating,
                onMarkAllRead: state.hasUnread && !state.isUpdating
                    ? _markAllRead
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Follow Requests Stack at Top
              if (pendingFollowRequests.isNotEmpty) ...[
                _FollowRequestsStack(
                  pendingRequests: pendingFollowRequests,
                  onTap: () => context.pushNamed(RouteNames.followRequests),
                ),
                const SizedBox(height: AppSpacing.md),
                const Divider(color: AppColors.border),
                const SizedBox(height: AppSpacing.sm),
              ],

              if (state.isLoading && state.notifications.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: AppLoader(),
                )
              else if (state.status == NotificationsStatus.error)
                ErrorView(
                  message: 'Bildirimler yüklenemedi.',
                  onRetry: () => ref
                      .read(notificationsControllerProvider.notifier)
                      .refreshNotifications(),
                )
              else if (state.notifications.isEmpty)
                const EmptyState(
                  title: 'Henüz bildirimin yok.',
                  message:
                      'Etkinlik istekleri ve güncellemeler burada görünecek.',
                  icon: Icons.notifications_none_rounded,
                )
              else ...[
                if (todayNotifications.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                      horizontal: AppSpacing.md,
                    ),
                    child: Text(
                      'Bugün',
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  ...todayNotifications.map(
                    (notification) => NotificationTile(
                      notification: notification,
                      timeLabel: DateFormatter.relativeTime(
                        notification.createdAt,
                      ),
                      isBusy: state.isUpdating,
                      onTap: () => _handleNotificationTap(notification),
                      onApprove: () => _approveFollowRequest(notification),
                      onReject: () => _rejectFollowRequest(notification),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (thisWeekNotifications.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                      horizontal: AppSpacing.md,
                    ),
                    child: Text(
                      'Bu Hafta',
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  ...thisWeekNotifications.map(
                    (notification) => NotificationTile(
                      notification: notification,
                      timeLabel: DateFormatter.relativeTime(
                        notification.createdAt,
                      ),
                      isBusy: state.isUpdating,
                      onTap: () => _handleNotificationTap(notification),
                      onApprove: () => _approveFollowRequest(notification),
                      onReject: () => _rejectFollowRequest(notification),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (earlierNotifications.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                      horizontal: AppSpacing.md,
                    ),
                    child: Text(
                      'Daha Önce',
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  ...earlierNotifications.map(
                    (notification) => NotificationTile(
                      notification: notification,
                      timeLabel: DateFormatter.relativeTime(
                        notification.createdAt,
                      ),
                      isBusy: state.isUpdating,
                      onTap: () => _handleNotificationTap(notification),
                      onApprove: () => _approveFollowRequest(notification),
                      onReject: () => _rejectFollowRequest(notification),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
              if (state.notifications.isNotEmpty)
                if (state.hasMore)
                  AppButton(
                    label: 'Daha fazla yükle',
                    isLoading: state.isLoadingMore,
                    onPressed: state.isLoadingMore
                        ? null
                        : () => ref
                              .read(notificationsControllerProvider.notifier)
                              .loadMoreNotifications(),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    child: Text(
                      'Daha fazla içerik yok.',
                      style: AppTextStyles.caption,
                      textAlign: TextAlign.center,
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _markAllRead() async {
    final success = await ref
        .read(notificationsControllerProvider.notifier)
        .markAllNotificationsRead();
    if (!mounted || success) return;

    _showMessage(
      ref.read(notificationsControllerProvider).message ??
          'Bildirim güncellenemedi.',
    );
  }

  Future<void> _handleNotificationTap(AppNotification notification) async {
    if (notification.isUnread) {
      final success = await ref
          .read(notificationsControllerProvider.notifier)
          .markNotificationRead(notification.id);
      if (!mounted) return;
      if (!success) {
        _showMessage(
          ref.read(notificationsControllerProvider).message ??
              'Bildirim güncellenemedi.',
        );
        return;
      }
    }

    if (!mounted || !notification.canOpenEntity) return;

    final entityId = notification.entityId?.trim();
    if (entityId == null || entityId.isEmpty) {
      _showMessage('İlgili içerik bulunamadı.');
      return;
    }

    try {
      if (notification.opensEventChat) {
        context.pushNamed(
          RouteNames.eventChat,
          pathParameters: {'eventId': entityId},
        );
        return;
      }

      if (notification.opensDirectMessage) {
        context.pushNamed(
          RouteNames.directChat,
          pathParameters: {'conversationId': entityId},
        );
        return;
      }

      if (notification.opensEvent) {
        context.pushNamed(
          RouteNames.eventDetail,
          pathParameters: {'eventId': entityId},
        );
        return;
      }

      if (notification.opensProfile) {
        context.pushNamed(
          RouteNames.publicProfile,
          pathParameters: {'userId': entityId},
        );
        return;
      }

      _showMessage('İlgili içerik bulunamadı.');
    } catch (_) {
      if (!mounted) return;
      _showMessage('Bildirim açılırken bir sorun oluştu.');
    }
  }

  Future<void> _approveFollowRequest(AppNotification notification) async {
    final success = await ref
        .read(notificationsControllerProvider.notifier)
        .approveFollowRequest(notification);
    if (!mounted) return;
    _showMessage(success ? 'Takip isteği onaylandı.' : 'İstek işlenemedi.');
  }

  Future<void> _rejectFollowRequest(AppNotification notification) async {
    final success = await ref
        .read(notificationsControllerProvider.notifier)
        .rejectFollowRequest(notification);
    if (!mounted) return;
    _showMessage(success ? 'Takip isteği reddedildi.' : 'İstek işlenemedi.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.goNamed(RouteNames.home);
  }
}

class _NotificationsHeader extends StatelessWidget {
  const _NotificationsHeader({
    required this.unreadCount,
    required this.isUpdating,
    required this.onMarkAllRead,
  });

  final int unreadCount;
  final bool isUpdating;
  final VoidCallback? onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bildirimler', style: AppTextStyles.headline),
              const SizedBox(height: AppSpacing.sm),
              Text(
                unreadCount > 0
                    ? '$unreadCount okunmamış bildirimin var.'
                    : 'Tüm bildirimler güncel.',
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
        if (unreadCount > 0)
          Flexible(
            child: AppButton(
              label: 'Tümünü okundu yap',
              fullWidth: false,
              isLoading: isUpdating,
              onPressed: onMarkAllRead,
            ),
          ),
      ],
    );
  }
}

class _FollowRequestsStack extends StatelessWidget {
  const _FollowRequestsStack({
    required this.pendingRequests,
    required this.onTap,
  });

  final List<AppNotification> pendingRequests;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            // Overlapping stacked avatars
            SizedBox(
              width: 54,
              height: 44,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  if (pendingRequests.length > 2)
                    Positioned(
                      left: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: PublicProfileAvatar(
                          userId: pendingRequests[2].actorId,
                          radius: 14,
                          enableNavigation: false,
                        ),
                      ),
                    ),
                  if (pendingRequests.length > 1)
                    Positioned(
                      left: 12,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: PublicProfileAvatar(
                          userId: pendingRequests[1].actorId,
                          radius: 14,
                          enableNavigation: false,
                        ),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: PublicProfileAvatar(
                        userId: pendingRequests[0].actorId,
                        radius: 14,
                        enableNavigation: false,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Takip İstekleri',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Hesabını takip etmek isteyenleri gör',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                pendingRequests.length.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
