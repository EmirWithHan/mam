import 'package:flutter/foundation.dart';

import '../../core/utils/error_messages.dart';
import '../../core/utils/pagination.dart';
import '../../services/supabase_service.dart';
import 'notifications_models.dart';

class NotificationsService {
  const NotificationsService();

  Future<List<AppNotification>> fetchNotifications({
    int limit = SupabasePageSizes.notifications,
    int offset = 0,
  }) async {
    try {
      final userId = _currentUserId();
      final rows = await SupabaseService.client
          .from('notifications')
          .select(
            'id,recipient_id,actor_id,type,title,body,entity_type,entity_id,metadata,is_read,created_at',
          )
          .eq('recipient_id', userId)
          .neq('type', 'message')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return rows
          .map(
            (row) => AppNotification.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
    } catch (error) {
      logSupabaseDebug('Notifications', 'fetchNotifications', error);
      throw Exception(_notificationError(error, 'Bildirimler yüklenemedi.'));
    }
  }

  Future<int> fetchUnreadCount() async {
    try {
      final userId = _currentUserId();
      final rows = await SupabaseService.client
          .from('notifications')
          .select('id')
          .eq('recipient_id', userId)
          .eq('is_read', false)
          .neq('type', 'message')
          .limit(100);
      return rows.length;
    } catch (error) {
      logSupabaseDebug('Notifications', 'fetchUnreadCount', error);
      throw Exception(_notificationError(error, 'Bildirimler yüklenemedi.'));
    }
  }

  Future<void> markNotificationRead(String notificationId) async {
    try {
      await SupabaseService.client.rpc(
        'mark_notification_read',
        params: {'p_notification_id': notificationId},
      );
    } catch (error) {
      logSupabaseDebug('Notifications', 'markNotificationRead', error);
      throw Exception(_notificationError(error, 'Bildirim güncellenemedi.'));
    }
  }

  Future<void> markAllNotificationsRead() async {
    try {
      await SupabaseService.client.rpc('mark_all_notifications_read');
    } catch (error) {
      logSupabaseDebug('Notifications', 'markAllNotificationsRead', error);
      throw Exception(_notificationError(error, 'Bildirim güncellenemedi.'));
    }
  }

  Future<void> approveFollowRequest(String requestId) async {
    try {
      await SupabaseService.client.rpc(
        'approve_follow_request',
        params: {'p_request_id': requestId},
      );
    } catch (error) {
      logSupabaseDebug('Notifications', 'approveFollowRequest', error);
      throw Exception(_notificationError(error, 'İstek işlenemedi.'));
    }
  }

  Future<void> rejectFollowRequest(String requestId) async {
    try {
      await SupabaseService.client.rpc(
        'reject_follow_request',
        params: {'p_request_id': requestId},
      );
    } catch (error) {
      logSupabaseDebug('Notifications', 'rejectFollowRequest', error);
      throw Exception(_notificationError(error, 'İstek işlenemedi.'));
    }
  }

  Future<void> registerPushToken(PushTokenRegistration registration) async {
    if (!registration.isValid) {
      throw StateError('Push token geÃ§ersiz.');
    }

    try {
      final userId = _currentUserId();
      debugPrint(
        '[Notifications] user_push_tokens upsert started '
        'hasUser=${userId.isNotEmpty} tokenLength=${registration.token.length}',
      );
      await SupabaseService.client
          .from('user_push_tokens')
          .upsert(
            registration.toUpsertJson(userId: userId),
            onConflict: 'user_id,token',
          );
      debugPrint('[Notifications] user_push_tokens upsert succeeded');
    } catch (error) {
      debugPrint(
        '[Notifications] user_push_tokens upsert failed: ${error.runtimeType}',
      );
      logSupabaseDebug('Notifications', 'registerPushToken', error);
      rethrow;
    }
  }

  Future<void> deletePushToken(String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return;

    try {
      final userId = _currentUserId();
      await SupabaseService.client
          .from('user_push_tokens')
          .delete()
          .eq('user_id', userId)
          .eq('token', trimmed);
    } catch (error) {
      logSupabaseDebug('Notifications', 'deletePushToken', error);
      rethrow;
    }
  }

  String _currentUserId() {
    final userId = SupabaseService.client.auth.currentUser?.id;
    debugPrint(
      '[Notifications] current authenticated user present=${userId != null}',
    );
    if (userId == null) {
      throw StateError('Bu işlem için giriş yapmalısın.');
    }
    return userId;
  }

  String _notificationError(Object error, String fallback) {
    final friendly = friendlyErrorMessage(error);
    if (friendly.toLowerCase().contains('ters gitti')) return fallback;
    return friendly;
  }
}
