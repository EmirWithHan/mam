class RateLimitActions {
  const RateLimitActions._();

  static const createPost = 'create_post';
  static const createEvent = 'create_event';
  static const businessApplicationSubmit = 'business_application_submit';
  static const businessApplicationReview = 'business_application_review';
  static const commentCreate = 'comment_create';
  static const followRequest = 'follow_request';
  static const eventJoinRequest = 'event_join_request';
  static const eventJoinReview = 'event_join_review';
  static const reportCreate = 'report_create';
  static const businessReviewSubmit = 'business_review_submit';
  static const businessAttendanceMark = 'business_attendance_mark';
  static const feedbackSubmit = 'feedback_submit';
}

class RateLimitRules {
  const RateLimitRules._();

  static const createPostPerHour = 10;
  static const normalCreateEventPerDay = 3;
  static const businessCreateEventPerDay = 3;
  static const businessApplicationActivePending = 1;
  static const commentsPerHour = 30;
  static const followRequestsPerHour = 30;
  static const reportsPerDay = 10;
  static const eventJoinRequestsPerDay = 20;
  static const eventJoinReviewsPerHour = 60;
  static const businessApplicationReviewsPerHour = 60;
  static const businessAttendanceMarksPerHour = 120;
  static const businessReviewPerTarget = 1;
  static const feedbackSubmitsPerDay = 5;

  static const hourWindowSeconds = 60 * 60;
  static const dayWindowSeconds = 24 * 60 * 60;

  static int createEventLimit({required bool isBusinessEvent}) {
    return isBusinessEvent
        ? businessCreateEventPerDay
        : normalCreateEventPerDay;
  }
}

const friendlyRateLimitMessage =
    'Çok fazla işlem yaptın. Biraz sonra tekrar dene.';

bool isRateLimitError(Object error) {
  final normalized = error.toString().toLowerCase();
  return normalized.contains('rate_limit_exceeded') ||
      normalized.contains('rate limit exceeded') ||
      normalized.contains('çok fazla işlem');
}

String friendlyRateLimitErrorMessage(Object error) {
  if (isRateLimitError(error)) return friendlyRateLimitMessage;
  return '';
}
