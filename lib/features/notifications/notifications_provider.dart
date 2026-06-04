import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/error_messages.dart';
import '../../core/utils/pagination.dart';
import 'notifications_models.dart';
import 'notifications_service.dart';

enum NotificationsStatus { initial, loading, success, error }

class NotificationsState {
  const NotificationsState({
    required this.status,
    this.notifications = const [],
    this.message,
    this.isUpdating = false,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  const NotificationsState.initial()
    : status = NotificationsStatus.initial,
      notifications = const [],
      message = null,
      isUpdating = false,
      hasMore = true,
      isLoadingMore = false;

  final NotificationsStatus status;
  final List<AppNotification> notifications;
  final String? message;
  final bool isUpdating;
  final bool hasMore;
  final bool isLoadingMore;

  bool get isLoading => status == NotificationsStatus.loading;
  int get unreadCount =>
      notifications.where((notification) => notification.isUnread).length;
  bool get hasUnread => unreadCount > 0;

  NotificationsState copyWith({
    NotificationsStatus? status,
    List<AppNotification>? notifications,
    String? message,
    bool? isUpdating,
    bool? hasMore,
    bool? isLoadingMore,
    bool clearMessage = false,
  }) {
    return NotificationsState(
      status: status ?? this.status,
      notifications: notifications ?? this.notifications,
      message: clearMessage ? null : message ?? this.message,
      isUpdating: isUpdating ?? this.isUpdating,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

final notificationsServiceProvider = Provider<NotificationsService>((ref) {
  return const NotificationsService();
});

final notificationsUnreadCountProvider = FutureProvider<int>((ref) {
  return ref.watch(notificationsServiceProvider).fetchUnreadCount();
});

final notificationsControllerProvider =
    StateNotifierProvider<NotificationsController, NotificationsState>((ref) {
      return NotificationsController(
        service: ref.watch(notificationsServiceProvider),
        ref: ref,
      );
    });

class NotificationsController extends StateNotifier<NotificationsState> {
  NotificationsController({
    required NotificationsService service,
    required Ref ref,
  }) : _service = service,
       _ref = ref,
       super(const NotificationsState.initial());

  final NotificationsService _service;
  final Ref _ref;

  Future<void> loadNotifications({bool force = false}) async {
    if (!force && state.status == NotificationsStatus.success) return;
    state = state.copyWith(
      status: NotificationsStatus.loading,
      clearMessage: true,
    );

    try {
      final notifications = await _service.fetchNotifications();
      state = NotificationsState(
        status: NotificationsStatus.success,
        notifications: notifications,
        hasMore: pageHasMore(
          notifications.length,
          SupabasePageSizes.notifications,
        ),
      );
      _ref.invalidate(notificationsUnreadCountProvider);
    } catch (error) {
      state = state.copyWith(
        status: NotificationsStatus.error,
        message: _readableMessage(error),
      );
    }
  }

  Future<void> refreshNotifications() => loadNotifications(force: true);

  Future<void> loadMoreNotifications() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true, clearMessage: true);

    try {
      final nextNotifications = await _service.fetchNotifications(
        offset: state.notifications.length,
      );
      state = state.copyWith(
        status: NotificationsStatus.success,
        notifications: appendUniqueByKey(
          state.notifications,
          nextNotifications,
          (notification) => notification.id,
        ),
        hasMore: pageHasMore(
          nextNotifications.length,
          SupabasePageSizes.notifications,
        ),
        isLoadingMore: false,
      );
    } catch (error) {
      state = state.copyWith(
        isLoadingMore: false,
        message: _readableMessage(error),
      );
    }
  }

  Future<bool> markNotificationRead(String notificationId) async {
    if (state.isUpdating) return false;
    state = state.copyWith(isUpdating: true, clearMessage: true);

    try {
      await _service.markNotificationRead(notificationId);
      final notifications = state.notifications
          .map((notification) {
            if (notification.id != notificationId) return notification;
            return notification.copyWith(isRead: true);
          })
          .toList(growable: false);
      state = state.copyWith(
        status: NotificationsStatus.success,
        notifications: notifications,
        isUpdating: false,
      );
      _ref.invalidate(notificationsUnreadCountProvider);
      return true;
    } catch (error) {
      state = state.copyWith(
        isUpdating: false,
        message: _readableMessage(error),
      );
      return false;
    }
  }

  Future<bool> markAllNotificationsRead() async {
    if (state.isUpdating || !state.hasUnread) return false;
    state = state.copyWith(isUpdating: true, clearMessage: true);

    try {
      await _service.markAllNotificationsRead();
      final notifications = state.notifications
          .map((notification) => notification.copyWith(isRead: true))
          .toList(growable: false);
      state = state.copyWith(
        status: NotificationsStatus.success,
        notifications: notifications,
        isUpdating: false,
      );
      _ref.invalidate(notificationsUnreadCountProvider);
      return true;
    } catch (error) {
      state = state.copyWith(
        isUpdating: false,
        message: _readableMessage(error),
      );
      return false;
    }
  }

  Future<bool> approveFollowRequest(AppNotification notification) {
    return _handleFollowRequestAction(
      notification: notification,
      action: () => _service.approveFollowRequest(notification.entityId ?? ''),
      status: 'approved',
    );
  }

  Future<bool> rejectFollowRequest(AppNotification notification) {
    return _handleFollowRequestAction(
      notification: notification,
      action: () => _service.rejectFollowRequest(notification.entityId ?? ''),
      status: 'rejected',
    );
  }

  Future<bool> _handleFollowRequestAction({
    required AppNotification notification,
    required Future<void> Function() action,
    required String status,
  }) async {
    if (state.isUpdating) return false;
    final requestId = notification.entityId?.trim();
    if (requestId == null || requestId.isEmpty) {
      state = state.copyWith(message: 'İstek işlenemedi.');
      return false;
    }

    state = state.copyWith(isUpdating: true, clearMessage: true);

    try {
      await action();
      final notifications = state.notifications
          .map((item) {
            if (item.id != notification.id) return item;
            return item.copyWith(
              isRead: true,
              metadata: {...item.metadata, 'request_status': status},
            );
          })
          .toList(growable: false);
      state = state.copyWith(
        status: NotificationsStatus.success,
        notifications: notifications,
        isUpdating: false,
      );
      _ref.invalidate(notificationsUnreadCountProvider);
      return true;
    } catch (error) {
      state = state.copyWith(
        isUpdating: false,
        message: _readableMessage(error),
      );
      return false;
    }
  }

  String _readableMessage(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    final normalized = message.toLowerCase();
    final looksTechnical =
        normalized.contains('postgrest') ||
        normalized.contains('exception') ||
        normalized.contains('pgrst') ||
        normalized.contains('duplicate key') ||
        normalized.contains('constraint') ||
        normalized.contains('stack trace');
    if (message.isNotEmpty && message.length <= 90 && !looksTechnical) {
      return message;
    }
    return friendlyErrorMessage(error);
  }
}
