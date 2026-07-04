import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';
import '../profile/public_profile_service.dart';
import 'direct_messages_models.dart';

class DirectMessagingUnavailableException implements Exception {
  const DirectMessagingUnavailableException(this.message);
  final String message;

  @override
  String toString() => message;
}

class DirectMessagingService {
  const DirectMessagingService();

  String? get currentUserId => SupabaseService.client.auth.currentUser?.id;

  Future<List<DirectConversation>> fetchConversations() async {
    final userId = currentUserId;
    if (userId == null) throw StateError('Giriş yapılmalıdır.');

    try {
      // Step 1: Fetch all conversation IDs where current user is a participant
      final myParts = await SupabaseService.client
          .from('direct_conversation_participants')
          .select('conversation_id')
          .eq('user_id', userId);

      final conversationIds = (myParts as List)
          .map((row) => row['conversation_id'])
          .toList();

      if (conversationIds.isEmpty) return const [];

      // Step 2: Fetch all conversation details along with participant rows (NO profiles join)
      final data = await SupabaseService.client
          .from('direct_conversations')
          .select('''
            id,
            pair_key,
            created_by,
            created_at,
            updated_at,
            last_message_at,
            last_message_preview,
            direct_messages(
              sender_user_id,
              created_at
            ),
            direct_conversation_participants(
              user_id,
              last_read_at,
              last_read_message_id
            )
          ''')
          .inFilter('id', conversationIds)
          .order('last_message_at', ascending: false);

      final conversations = (data as List)
          .map(
            (row) =>
                DirectConversation.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList();

      // Step 3: Fetch all participant profiles from PublicProfileService
      final userIdsToFetch = conversations
          .expand((c) => c.participants.map((p) => p.userId))
          .toSet()
          .toList();

      final previewsMap = await const PublicProfileService()
          .fetchPublicProfilePreviews(userIdsToFetch);

      // Step 4: Map previews back to the parsed conversations
      return conversations.map((conv) {
        final updatedParticipants = conv.participants.map((part) {
          final preview = previewsMap[part.userId];
          if (preview != null) {
            return part.copyWith(
              username: preview.username,
              firstName: preview.firstName,
              avatarUrl: preview.avatarUrl,
            );
          }
          return part;
        }).toList();
        return conv.copyWith(participants: updatedParticipants);
      }).toList();
    } catch (e) {
      _handleDatabaseError(e, 'fetchConversations');
    }
  }

  Future<List<DirectMessage>> fetchMessages(String conversationId) async {
    try {
      final data = await SupabaseService.client
          .from('direct_messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true)
          .limit(50);

      return (data as List)
          .map((row) => DirectMessage.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      _handleDatabaseError(e, 'fetchMessages');
    }
  }

  Future<String> getOrCreateConversation(String targetUserId) async {
    try {
      final String conversationId = await SupabaseService.client.rpc(
        'get_or_create_direct_conversation',
        params: {'p_target_user_id': targetUserId},
      );
      return conversationId;
    } catch (e) {
      _handleDatabaseError(e, 'getOrCreateConversation');
    }
  }

  Future<DirectMessage> sendMessage({
    required String conversationId,
    required String body,
    String? replyToMessageId,
  }) async {
    try {
      final data = await SupabaseService.client.rpc(
        'send_direct_message',
        params: {
          'p_conversation_id': conversationId,
          'p_body': body,
          'p_reply_to_message_id': replyToMessageId,
        },
      );
      return DirectMessage.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      _handleDatabaseError(e, 'sendMessage');
    }
  }

  Future<void> markRead({
    required String conversationId,
    required String messageId,
  }) async {
    try {
      await SupabaseService.client.rpc(
        'mark_direct_conversation_read',
        params: {
          'p_conversation_id': conversationId,
          'p_last_message_id': messageId,
        },
      );
    } catch (e) {
      _handleDatabaseError(e, 'markRead');
    }
  }

  Future<void> reactToMessage({
    required String messageId,
    required String emoji,
  }) async {
    final userId = currentUserId;
    if (userId == null) return;

    await SupabaseService.client.from('message_reactions').upsert({
      'message_id': messageId,
      'user_id': userId,
      'emoji': emoji,
    });
  }

  Future<void> removeReactionFromMessage({required String messageId}) async {
    final userId = currentUserId;
    if (userId == null) return;

    await SupabaseService.client
        .from('message_reactions')
        .delete()
        .eq('message_id', messageId)
        .eq('user_id', userId);
  }

  Future<List<Map<String, dynamic>>> fetchReactionsForConversation(
    String conversationId,
  ) async {
    debugPrint(
      '[DirectMessaging] Direct message reactions are not schema-enabled yet: '
      'conversationId=$conversationId',
    );
    return const [];
  }

  Future<void> reportMessage({
    required String conversationId,
    required String messageId,
    required String reason,
  }) async {
    final userId = currentUserId;
    if (userId == null) return;

    await SupabaseService.client.from('message_reports').insert({
      'message_id': messageId,
      'reporter_id': userId,
      'reason': reason,
      'message_type': 'direct_dm',
      'conversation_id': conversationId,
    });
  }

  Never _handleDatabaseError(Object error, String actionName) {
    debugPrint('[DirectMessaging] Database error during $actionName: $error');
    final errStr = error.toString();
    if (_isRpcOverloadError(error, errStr)) {
      debugPrint(
        '[DirectMessaging WARNING] DirectMessaging RPC overload/contract mismatch.',
      );
      throw const DirectMessagingUnavailableException(
        'Mesaj g\u00F6nderilemedi. L\u00FCtfen tekrar dene.',
      );
    }
    if (errStr.contains('42P01') ||
        errStr.contains('relation') ||
        errStr.contains('does not exist')) {
      debugPrint(
        '[DirectMessaging WARNING] DM tables are missing. The migration must be applied to live database.',
      );
      throw const DirectMessagingUnavailableException(
        'Mesajlaşma özelliği şu anda kullanılamıyor.',
      );
    }
    if (errStr.contains('42883') ||
        errStr.contains('function') ||
        errStr.contains('does not exist')) {
      debugPrint(
        '[DirectMessaging WARNING] DM functions (RPCs) are missing. The migration must be applied to live database.',
      );
      throw const DirectMessagingUnavailableException(
        'Mesajlaşma özelliği şu anda kullanılamıyor.',
      );
    }
    if (error is PostgrestException) {
      throw const DirectMessagingUnavailableException(
        'Mesaj g\u00F6nderilemedi. L\u00FCtfen tekrar dene.',
      );
    }
    throw DirectMessagingUnavailableException(error.toString());
  }

  bool _isRpcOverloadError(Object error, String errorText) {
    final normalized = errorText.toLowerCase();
    if (error is PostgrestException && error.code == 'PGRST203') return true;
    return normalized.contains('pgrst203') ||
        normalized.contains('multiple choices') ||
        normalized.contains('could not choose the best candidate function');
  }
}
