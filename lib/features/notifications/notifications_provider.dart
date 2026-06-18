import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/error_messages.dart';
import '../../core/utils/pagination.dart';
import '../../services/supabase_service.dart';
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

final pushRegistrationControllerProvider = Provider<PushRegistrationController>(
  (ref) {
    final controller = PushRegistrationController(
      service: ref.watch(notificationsServiceProvider),
    );
    ref.onDispose(controller.dispose);
    return controller;
  },
);

class PushRegistrationController {
  PushRegistrationController({required NotificationsService service})
    : _service = service;

  final NotificationsService _service;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  String? _currentToken;
  bool _initialized = false;
  bool _loggedAlreadyInitialized = false;
  String? _lastReadinessSignature;

  void debugAuthReadiness({
    required bool isAuthenticated,
    required bool hasUserId,
    required bool isProfileCompleted,
    required bool hasAcceptedTerms,
  }) {
    final signature =
        'auth=$isAuthenticated user=$hasUserId '
        'profile=$isProfileCompleted terms=$hasAcceptedTerms';
    if (_lastReadinessSignature == signature) return;
    _lastReadinessSignature = signature;
    debugPrint('[Notifications] push readiness $signature');
  }

  Future<void> initializeForAuthenticatedUser() async {
    if (_initialized) {
      if (!_loggedAlreadyInitialized) {
        _loggedAlreadyInitialized = true;
        debugPrint(
          '[Notifications] FCM registration skipped: already initialized',
        );
      }
      return;
    }
    _initialized = true;
    _loggedAlreadyInitialized = false;

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      debugPrint(
        '[Notifications] FCM registration skipped: unsupported platform',
      );
      return;
    }

    try {
      final hasUser = SupabaseService.client.auth.currentUser != null;
      debugPrint('[Notifications] FCM registration started hasUser=$hasUser');
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint(
        '[Notifications] FCM permission status='
        '${settings.authorizationStatus.name}',
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint(
          '[Notifications] FCM registration skipped: permission denied',
        );
        return;
      }

      final token = await messaging.getToken();
      debugPrint(
        '[Notifications] FCM token present=${token != null} '
        'length=${token?.length ?? 0}',
      );
      if (token != null && token.trim().isNotEmpty) {
        _currentToken = token;
        await registerToken(token: token, platform: 'android');
      } else {
        debugPrint('[Notifications] FCM registration skipped: token empty');
      }

      _tokenRefreshSubscription ??= FirebaseMessaging.instance.onTokenRefresh
          .listen((token) {
            _currentToken = token;
            debugPrint(
              '[Notifications] FCM token refresh received length=${token.length}',
            );
            unawaited(registerToken(token: token, platform: 'android'));
          });

      _foregroundMessageSubscription ??= FirebaseMessaging.onMessage.listen((
        message,
      ) {
        debugPrint(
          '[Notifications] foreground FCM message type='
          '${message.data['type'] ?? 'unknown'}',
        );
      });
    } catch (error) {
      debugPrint('[Notifications] FCM init failed: ${error.runtimeType}');
      _initialized = false;
      _loggedAlreadyInitialized = false;
    }
  }

  Future<void> registerToken({
    required String token,
    required String platform,
  }) async {
    try {
      final hasUser = SupabaseService.client.auth.currentUser != null;
      debugPrint(
        '[Notifications] Supabase push token save started '
        'hasUser=$hasUser platform=$platform tokenLength=${token.length}',
      );
      await _service.registerPushToken(
        PushTokenRegistration(token: token, platform: platform),
      );
      debugPrint('[Notifications] Supabase push token save succeeded');
    } catch (error) {
      debugPrint(
        '[Notifications] Supabase push token save failed: ${error.runtimeType}',
      );
      logSupabaseDebug('Notifications', 'push token registration', error);
    }
  }

  Future<void> deleteToken(String token) async {
    try {
      await _service.deletePushToken(token);
    } catch (error) {
      logSupabaseDebug('Notifications', 'push token delete', error);
    }
  }

  Future<void> deleteCurrentToken() async {
    final token = _currentToken;
    _currentToken = null;
    _initialized = false;
    _loggedAlreadyInitialized = false;
    if (token != null && token.trim().isNotEmpty) {
      debugPrint(
        '[Notifications] Supabase push token delete started '
        'tokenLength=${token.length}',
      );
      await deleteToken(token);
    } else {
      debugPrint(
        '[Notifications] Supabase push token delete skipped: no token',
      );
    }
  }

  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _foregroundMessageSubscription?.cancel();
  }
}

class NotificationsController extends StateNotifier<NotificationsState> {
  NotificationsController({
    required NotificationsService service,
    required Ref ref,
  }) : _service = service,
       _ref = ref,
       super(const NotificationsState.initial());

  final NotificationsService _service;
  final Ref _ref;
  RealtimeChannel? _realtimeChannel;
  Timer? _realtimeDebounce;
  String? _realtimeUserId;

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

  void startRealtime(String? userId) {
    final trimmedUserId = userId?.trim();
    if (trimmedUserId == null || trimmedUserId.isEmpty) {
      stopRealtime();
      return;
    }
    if (_realtimeUserId == trimmedUserId && _realtimeChannel != null) return;

    stopRealtime();
    try {
      _realtimeUserId = trimmedUserId;
      _realtimeChannel = SupabaseService.client
          .channel('notifications:$trimmedUserId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'recipient_id',
              value: trimmedUserId,
            ),
            callback: (_) => _scheduleRealtimeRefresh(),
          )
          .subscribe();
    } catch (error) {
      logSupabaseDebug('Notifications', 'realtime subscribe', error);
      stopRealtime();
    }
  }

  void stopRealtime() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = null;
    final channel = _realtimeChannel;
    _realtimeChannel = null;
    _realtimeUserId = null;
    if (channel != null) {
      unawaited(SupabaseService.client.removeChannel(channel));
    }
  }

  void _scheduleRealtimeRefresh() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 500), () {
      _ref.invalidate(notificationsUnreadCountProvider);
      unawaited(loadNotifications(force: true));
    });
  }

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

  @override
  void dispose() {
    stopRealtime();
    super.dispose();
  }
}
