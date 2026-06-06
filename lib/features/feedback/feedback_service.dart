import '../../core/utils/error_messages.dart';
import '../../services/rate_limit_service.dart';
import '../../services/supabase_service.dart';
import 'feedback_models.dart';

class FeedbackService {
  const FeedbackService({
    RateLimitService rateLimitService = const RateLimitService(),
  }) : _rateLimitService = rateLimitService;

  final RateLimitService _rateLimitService;

  Future<void> submitFeedback(UserFeedbackInput input) async {
    final validationError = input.validationError;
    if (validationError != null) {
      throw FeedbackException(validationError);
    }

    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw const FeedbackException('Geri bildirim için giriş yapmalısın.');
    }

    try {
      await _rateLimitService.submitFeedback();
      await SupabaseService.client
          .from('user_feedback')
          .insert(input.toInsertJson(userId: userId));
    } catch (error) {
      logSupabaseDebug('Feedback', 'submitFeedback', error);
      throw FeedbackException(friendlyFeedbackErrorMessage(error));
    }
  }

  Future<List<UserFeedback>> fetchLatestFeedback({int limit = 50}) async {
    final rows = await SupabaseService.client
        .from('user_feedback')
        .select('id,user_id,rating,category,message,source,created_at')
        .order('created_at', ascending: false)
        .limit(limit.clamp(1, 50).toInt())
        .catchError((Object error) {
          logSupabaseDebug('Feedback', 'fetchLatestFeedback', error);
          throw error;
        });

    return rows
        .map((row) => UserFeedback.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }
}

class FeedbackException implements Exception {
  const FeedbackException(this.message);

  final String message;

  @override
  String toString() => message;
}
