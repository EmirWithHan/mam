import '../core/utils/rate_limits.dart';
import 'supabase_service.dart';

class RateLimitService {
  const RateLimitService();

  Future<void> checkAndRecord({
    required String action,
    required int limitCount,
    required int windowSeconds,
    String? targetId,
  }) async {
    await SupabaseService.client.rpc(
      'check_and_record_rate_limit',
      params: {
        'p_action': action,
        'p_limit_count': limitCount,
        'p_window_seconds': windowSeconds,
        'p_target_id': targetId,
      },
    );
  }

  Future<void> createPost({String? targetId}) {
    return checkAndRecord(
      action: RateLimitActions.createPost,
      limitCount: RateLimitRules.createPostPerHour,
      windowSeconds: RateLimitRules.hourWindowSeconds,
      targetId: targetId,
    );
  }

  Future<void> createEvent({required bool isBusinessEvent, String? targetId}) {
    return checkAndRecord(
      action: RateLimitActions.createEvent,
      limitCount: RateLimitRules.createEventLimit(
        isBusinessEvent: isBusinessEvent,
      ),
      windowSeconds: RateLimitRules.dayWindowSeconds,
      targetId: targetId,
    );
  }

  Future<void> submitBusinessApplication() {
    return checkAndRecord(
      action: RateLimitActions.businessApplicationSubmit,
      limitCount: RateLimitRules.businessApplicationActivePending,
      windowSeconds: RateLimitRules.dayWindowSeconds,
    );
  }

  Future<void> createComment({required String postId}) {
    return checkAndRecord(
      action: RateLimitActions.commentCreate,
      limitCount: RateLimitRules.commentsPerHour,
      windowSeconds: RateLimitRules.hourWindowSeconds,
      targetId: postId,
    );
  }

  Future<void> followRequest({required String targetUserId}) {
    return checkAndRecord(
      action: RateLimitActions.followRequest,
      limitCount: RateLimitRules.followRequestsPerHour,
      windowSeconds: RateLimitRules.hourWindowSeconds,
      targetId: targetUserId,
    );
  }

  Future<void> eventJoinRequest({required String eventId}) {
    return checkAndRecord(
      action: RateLimitActions.eventJoinRequest,
      limitCount: RateLimitRules.eventJoinRequestsPerDay,
      windowSeconds: RateLimitRules.dayWindowSeconds,
      targetId: eventId,
    );
  }

  Future<void> eventJoinReview({required String requestId}) {
    return checkAndRecord(
      action: RateLimitActions.eventJoinReview,
      limitCount: RateLimitRules.eventJoinReviewsPerHour,
      windowSeconds: RateLimitRules.hourWindowSeconds,
      targetId: requestId,
    );
  }

  Future<void> submitReport({required String targetId}) {
    return checkAndRecord(
      action: RateLimitActions.reportCreate,
      limitCount: RateLimitRules.reportsPerDay,
      windowSeconds: RateLimitRules.dayWindowSeconds,
      targetId: targetId,
    );
  }

  Future<void> submitBusinessReview({
    required String eventId,
    required String businessId,
  }) {
    return checkAndRecord(
      action: RateLimitActions.businessReviewSubmit,
      limitCount: RateLimitRules.businessReviewPerTarget,
      windowSeconds: RateLimitRules.dayWindowSeconds,
      targetId: eventId,
    );
  }

  Future<void> markBusinessAttendance({required String participantUserId}) {
    return checkAndRecord(
      action: RateLimitActions.businessAttendanceMark,
      limitCount: RateLimitRules.businessAttendanceMarksPerHour,
      windowSeconds: RateLimitRules.hourWindowSeconds,
      targetId: participantUserId,
    );
  }
}
