import 'package:flutter/foundation.dart';

import '../../services/supabase_service.dart';
import 'join_requests_models.dart';

class JoinRequestsService {
  const JoinRequestsService();

  Future<EventJoinRequest?> getMyJoinRequestForEvent(String eventId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return null;

    final data = await SupabaseService.client
        .from('event_join_requests')
        .select()
        .eq('event_id', eventId)
        .eq('user_id', userId)
        .maybeSingle();

    if (data == null) return null;
    return EventJoinRequest.fromJson(data);
  }

  Future<EventJoinRequest> requestToJoinEvent(String eventId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to request to join an event.');
    }

    final data = await SupabaseService.client
        .from('event_join_requests')
        .insert({'event_id': eventId, 'user_id': userId, 'status': 'pending'})
        .select()
        .single();

    return EventJoinRequest.fromJson(data);
  }

  Future<void> cancelMyJoinRequest(String requestId) async {
    await SupabaseService.client.rpc(
      'cancel_my_event_join_request',
      params: {'request_id': requestId},
    );
  }

  Future<List<EventJoinRequest>> fetchJoinRequestsForEvent(
    String eventId,
  ) async {
    final data = await SupabaseService.client
        .from('event_join_requests')
        .select()
        .eq('event_id', eventId)
        .order('created_at');

    return data.map(EventJoinRequest.fromJson).toList();
  }

  Future<void> approveJoinRequest(String requestId) async {
    await SupabaseService.client.rpc(
      'approve_event_join_request',
      params: {'request_id': requestId},
    );
    await _applyJoinApprovalTrustEvent(requestId);
  }

  Future<void> rejectJoinRequest(String requestId) async {
    await SupabaseService.client.rpc(
      'reject_event_join_request',
      params: {'request_id': requestId},
    );
  }
}

Future<void> _applyJoinApprovalTrustEvent(String requestId) async {
  try {
    await SupabaseService.client.rpc(
      'apply_join_approval_trust_event',
      params: {'p_request_id': requestId},
    );
  } catch (error) {
    debugPrint('[JoinRequests] trust score event failed: ${error.runtimeType}');
  }
}
