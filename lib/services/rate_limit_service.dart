import '../core/utils/rate_limits.dart';
import 'supabase_service.dart';

class RateLimitService {
  const RateLimitService();

  Future<void> checkAndRecord({
    required String action,
    String? targetId,
  }) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to perform this action.');
    }
    await SupabaseService.client.rpc(
      'check_and_record_rate_limit',
      params: {'user_id': userId, 'action': action, 'target_id': targetId},
    );
  }

  Future<void> createPost({String? targetId}) {
    return checkAndRecord(
      action: RateLimitActions.createPost,
      targetId: targetId,
    );
  }

  Future<void> createEvent({required bool isBusinessEvent, String? targetId}) {
    return checkAndRecord(
      action: RateLimitActions.createEvent,
      targetId: targetId,
    );
  }

  Future<void> submitBusinessApplication() {
    return checkAndRecord(action: RateLimitActions.businessApplicationSubmit);
  }

  Future<void> createComment({required String postId}) {
    return checkAndRecord(
      action: RateLimitActions.commentCreate,
      targetId: postId,
    );
  }

  Future<void> followRequest({required String targetUserId}) {
    return checkAndRecord(
      action: RateLimitActions.followRequest,
      targetId: targetUserId,
    );
  }

  Future<void> eventJoinRequest({required String eventId}) {
    return checkAndRecord(
      action: RateLimitActions.eventJoinRequest,
      targetId: eventId,
    );
  }

  Future<void> eventJoinReview({required String requestId}) {
    return checkAndRecord(
      action: RateLimitActions.eventJoinReview,
      targetId: requestId,
    );
  }

  Future<void> submitReport({required String targetId}) {
    return checkAndRecord(
      action: RateLimitActions.reportCreate,
      targetId: targetId,
    );
  }

  Future<void> submitBusinessReview({
    required String eventId,
    required String businessId,
  }) {
    return checkAndRecord(
      action: RateLimitActions.businessReviewSubmit,
      targetId: eventId,
    );
  }

  Future<void> markBusinessAttendance({required String participantUserId}) {
    return checkAndRecord(
      action: RateLimitActions.businessAttendanceMark,
      targetId: participantUserId,
    );
  }

  Future<void> submitFeedback() {
    return checkAndRecord(action: RateLimitActions.feedbackSubmit);
  }
}
