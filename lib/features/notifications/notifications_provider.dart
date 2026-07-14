import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/error_messages.dart';
import '../../core/utils/pagination.dart';
import '../../services/supabase_service.dart';
import '../home/home_feed_provider.dart';
import '../profile/profile_follow_list_provider.dart';
import '../profile/profile_provider.dart';
import '../profile/public_profile_provider.dart';
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
      messaging: FirebasePushMessagingClient(),
    );
    ref.onDispose(controller.dispose);
    return controller;
  },
);

typedef PushNotificationRouteCallback =
    bool Function(Map<String, dynamic> data);

PushNotificationRouteCallback? _pushNotificationRouteCallback;

void configurePushNotificationRouteCallback(
  PushNotificationRouteCallback callback,
) {
  _pushNotificationRouteCallback = callback;
}

enum PushClientPlatform { android, ios, unsupported }

PushClientPlatform resolvePushClientPlatform({
  required bool isWeb,
  required TargetPlatform platform,
}) {
  if (isWeb) return PushClientPlatform.unsupported;
  return switch (platform) {
    TargetPlatform.android => PushClientPlatform.android,
    TargetPlatform.iOS => PushClientPlatform.ios,
    _ => PushClientPlatform.unsupported,
  };
}

extension on PushClientPlatform {
  String? get backendValue => switch (this) {
    PushClientPlatform.android => 'android',
    PushClientPlatform.ios => 'ios',
    PushClientPlatform.unsupported => null,
  };
}

abstract class PushMessagingClient {
  Future<bool> requestPermission();
  Future<String?> getAPNSToken();
  Future<String?> getToken();
  Future<RemoteMessage?> getInitialMessage();
  Stream<String> get onTokenRefresh;
  Stream<RemoteMessage> get onMessage;
  Stream<RemoteMessage> get onMessageOpenedApp;
}

class FirebasePushMessagingClient implements PushMessagingClient {
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus != AuthorizationStatus.denied;
  }

  @override
  Future<String?> getAPNSToken() => _messaging.getAPNSToken();

  @override
  Future<String?> getToken() => _messaging.getToken();

  @override
  Future<RemoteMessage?> getInitialMessage() => _messaging.getInitialMessage();

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;

  @override
  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;
}

class PushRegistrationController {
  PushRegistrationController({
    required NotificationsService service,
    required PushMessagingClient messaging,
    PushClientPlatform? platform,
    bool Function()? hasAuthenticatedUser,
    PushNotificationRouteCallback? routeNotification,
    Future<void> Function(Duration)? delay,
  }) : _service = service,
       _messaging = messaging,
       _platform =
           platform ??
           resolvePushClientPlatform(
             isWeb: kIsWeb,
             platform: defaultTargetPlatform,
           ),
       _hasAuthenticatedUser =
           hasAuthenticatedUser ??
           (() => SupabaseService.client.auth.currentUser != null),
       _routeNotification =
           routeNotification ??
           ((data) => _pushNotificationRouteCallback?.call(data) ?? false),
       _delay = delay ?? Future<void>.delayed;

  final NotificationsService _service;
  final PushMessagingClient _messaging;
  final PushClientPlatform _platform;
  final bool Function() _hasAuthenticatedUser;
  final PushNotificationRouteCallback _routeNotification;
  final Future<void> Function(Duration) _delay;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  String? _currentToken;
  bool _initialized = false;
  bool _routingInitialized = false;
  bool _routingReady = false;
  bool _loggedAlreadyInitialized = false;
  String? _lastReadinessSignature;
  final Map<String, RemoteMessage> _pendingTappedMessages = {};
  final Set<String> _routedMessageKeys = {};

  void debugAuthReadiness({
    required bool isAuthenticated,
    required bool hasUserId,
    required bool isProfileCompleted,
    required bool hasAcceptedTerms,
  }) {
    final signature =
        'auth=$isAuthenticated user=$hasUserId '
        'profile=$isProfileCompleted terms=$hasAcceptedTerms';
    _routingReady =
        isAuthenticated && hasUserId && isProfileCompleted && hasAcceptedTerms;
    unawaited(_initializeNotificationRouting());
    if (_routingReady) {
      _flushPendingNotificationTaps();
    }
    if (_lastReadinessSignature != signature) {
      _lastReadinessSignature = signature;
      debugPrint('[Notifications] push readiness $signature');
    }
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

    final backendPlatform = _platform.backendValue;
    if (backendPlatform == null) {
      debugPrint(
        '[Notifications] FCM registration skipped: unsupported platform',
      );
      return;
    }

    try {
      final hasUser = _hasAuthenticatedUser();
      debugPrint('[Notifications] FCM registration started hasUser=$hasUser');
      if (!hasUser) {
        debugPrint(
          '[Notifications] FCM registration skipped: no authenticated user',
        );
        _initialized = false;
        return;
      }

      final permissionGranted = await _messaging.requestPermission();
      if (!permissionGranted) {
        debugPrint(
          '[Notifications] FCM registration skipped: permission denied',
        );
        return;
      }

      _installMessageSubscriptions(backendPlatform);

      if (_platform == PushClientPlatform.ios) {
        final apnsReady = await _waitForAPNSToken();
        if (!apnsReady) {
          debugPrint(
            '[Notifications] FCM registration deferred: APNs token unavailable',
          );
          _initialized = false;
          return;
        }
      }

      final token = await _messaging.getToken();
      debugPrint('[Notifications] FCM token present=${token != null}');
      if (token != null && token.trim().isNotEmpty) {
        _currentToken = token;
        await registerToken(token: token, platform: backendPlatform);
      } else {
        debugPrint('[Notifications] FCM registration skipped: token empty');
      }
    } catch (error) {
      debugPrint('[Notifications] FCM init failed: ${error.runtimeType}');
      _initialized = false;
      _loggedAlreadyInitialized = false;
    }
  }

  Future<bool> _waitForAPNSToken() async {
    for (var attempt = 0; attempt < 20; attempt += 1) {
      final token = await _messaging.getAPNSToken();
      if (token?.trim().isNotEmpty == true) return true;
      await _delay(const Duration(milliseconds: 250));
    }
    return false;
  }

  void _installMessageSubscriptions(String backendPlatform) {
    _tokenRefreshSubscription ??= _messaging.onTokenRefresh.listen((token) {
      _currentToken = token;
      debugPrint('[Notifications] FCM token refresh received');
      unawaited(registerToken(token: token, platform: backendPlatform));
    });

    _foregroundMessageSubscription ??= _messaging.onMessage.listen((message) {
      debugPrint(
        '[Notifications] foreground FCM message type='
        '${message.data['type'] ?? 'unknown'}',
      );
    });
  }

  Future<void> _initializeNotificationRouting() async {
    if (_routingInitialized || _platform == PushClientPlatform.unsupported) {
      return;
    }
    _routingInitialized = true;
    try {
      _messageOpenedSubscription ??= _messaging.onMessageOpenedApp.listen(
        handleNotificationTap,
      );
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        handleNotificationTap(initialMessage);
      }
    } catch (error) {
      _routingInitialized = false;
      debugPrint(
        '[Notifications] notification routing init failed: '
        '${error.runtimeType}',
      );
    }
  }

  @visibleForTesting
  void handleNotificationTap(RemoteMessage message) {
    final key = _messageKey(message);
    if (_routedMessageKeys.contains(key) ||
        _pendingTappedMessages.containsKey(key)) {
      return;
    }
    if (!_routingReady || !_hasAuthenticatedUser()) {
      _pendingTappedMessages[key] = message;
      return;
    }
    if (_routeNotification(message.data)) {
      _rememberRoutedMessage(key);
      return;
    }
    _pendingTappedMessages[key] = message;
  }

  void _flushPendingNotificationTaps() {
    if (!_routingReady || !_hasAuthenticatedUser()) return;
    final pending = Map<String, RemoteMessage>.from(_pendingTappedMessages);
    for (final entry in pending.entries) {
      if (_routeNotification(entry.value.data)) {
        _pendingTappedMessages.remove(entry.key);
        _rememberRoutedMessage(entry.key);
      }
    }
  }

  String _messageKey(RemoteMessage message) {
    final messageId = message.messageId?.trim();
    if (messageId != null && messageId.isNotEmpty) return messageId;
    final notificationId = message.data['notification_id']?.toString().trim();
    if (notificationId != null && notificationId.isNotEmpty) {
      return notificationId;
    }
    return '${message.data['entity_type'] ?? ''}:'
        '${message.data['entity_id'] ?? ''}:'
        '${message.sentTime?.millisecondsSinceEpoch ?? 0}';
  }

  void _rememberRoutedMessage(String key) {
    _routedMessageKeys.add(key);
    if (_routedMessageKeys.length > 50) {
      _routedMessageKeys.remove(_routedMessageKeys.first);
    }
  }

  Future<void> registerToken({
    required String token,
    required String platform,
  }) async {
    if (!_hasAuthenticatedUser()) {
      debugPrint(
        '[Notifications] Supabase push token save skipped: '
        'no authenticated user',
      );
      return;
    }
    try {
      debugPrint(
        '[Notifications] Supabase push token save started '
        'platform=$platform',
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
    _routingReady = false;
    _pendingTappedMessages.clear();
    _loggedAlreadyInitialized = false;
    if (token != null && token.trim().isNotEmpty) {
      debugPrint('[Notifications] Supabase push token delete started');
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
    _messageOpenedSubscription?.cancel();
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
      _refreshFollowSurfaces(notification);
      return true;
    } catch (error) {
      state = state.copyWith(
        isUpdating: false,
        message: _readableMessage(error),
      );
      return false;
    }
  }

  void _refreshFollowSurfaces(AppNotification notification) {
    final requesterId = notification.actorId?.trim();
    final currentUserId = SupabaseService.client.auth.currentUser?.id;

    if (requesterId != null && requesterId.isNotEmpty) {
      _ref.invalidate(publicProfileDetailProvider(requesterId));
      _ref.invalidate(publicProfileGalleryProvider(requesterId));
      _ref.invalidate(publicProfileEventHistoryProvider(requesterId));
      _ref.invalidate(publicProfilePreviewProvider(requesterId));
    }

    if (currentUserId != null && currentUserId.isNotEmpty) {
      _ref.invalidate(
        profileFollowListControllerProvider(
          ProfileFollowListArgs(
            userId: currentUserId,
            type: ProfileFollowListType.followers,
          ),
        ),
      );
    }

    if (requesterId != null && requesterId.isNotEmpty) {
      _ref.invalidate(
        profileFollowListControllerProvider(
          ProfileFollowListArgs(
            userId: requesterId,
            type: ProfileFollowListType.following,
          ),
        ),
      );
    }

    _ref.invalidate(homeFeedProvider);
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
