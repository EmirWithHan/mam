import '../../core/utils/error_messages.dart';
import '../../services/supabase_service.dart';
import 'notifications_models.dart';

class NotificationsService {
  const NotificationsService();

  Future<List<AppNotification>> fetchNotifications() async {
    try {
      final userId = _currentUserId();
      final rows = await SupabaseService.client
          .from('notifications')
          .select(
            'id,recipient_id,actor_id,type,title,body,entity_type,entity_id,metadata,is_read,created_at',
          )
          .eq('recipient_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      return rows
          .map(
            (row) => AppNotification.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
    } catch (error) {
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
          .eq('is_read', false);
      return rows.length;
    } catch (error) {
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
      throw Exception(_notificationError(error, 'Bildirim güncellenemedi.'));
    }
  }

  Future<void> markAllNotificationsRead() async {
    try {
      await SupabaseService.client.rpc('mark_all_notifications_read');
    } catch (error) {
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
      throw Exception(_notificationError(error, 'İstek işlenemedi.'));
    }
  }

  String _currentUserId() {
    final userId = SupabaseService.client.auth.currentUser?.id;
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
