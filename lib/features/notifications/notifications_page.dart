import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      ref.read(notificationsControllerProvider.notifier).loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsControllerProvider);

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
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _NotificationsHeader(
                unreadCount: state.unreadCount,
                isUpdating: state.isUpdating,
                onMarkAllRead: state.hasUnread && !state.isUpdating
                    ? _markAllRead
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
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
              else
                ...state.notifications.map(
                  (notification) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: NotificationTile(
                      notification: notification,
                      timeLabel: _timeLabel(notification.createdAt),
                      isBusy: state.isUpdating,
                      onTap: () => _handleNotificationTap(notification),
                      onApprove: () => _approveFollowRequest(notification),
                      onReject: () => _rejectFollowRequest(notification),
                    ),
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

  String _timeLabel(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    if (difference.inMinutes < 1) return 'Şimdi';
    if (difference.inMinutes < 60) return '${difference.inMinutes} dk önce';
    if (difference.inHours < 24) return '${difference.inHours} sa önce';
    if (difference.inDays == 1) return 'Dün';
    if (difference.inDays < 7) return '${difference.inDays} gün önce';
    return DateFormatter.shortDate(createdAt);
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
          AppButton(
            label: 'Tümünü okundu yap',
            fullWidth: false,
            isLoading: isUpdating,
            onPressed: onMarkAllRead,
          ),
      ],
    );
  }
}
