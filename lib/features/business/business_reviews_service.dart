import '../../services/supabase_service.dart';
import 'business_reviews_models.dart';

class BusinessReviewsService {
  const BusinessReviewsService();

  Future<BusinessRatingSummary> fetchRatingSummary(String businessId) async {
    final rows = await SupabaseService.client.rpc(
      'get_business_rating_summary',
      params: {'p_business_id': businessId},
    );

    if (rows is List && rows.isNotEmpty) {
      return BusinessRatingSummary.fromJson(
        Map<String, dynamic>.from(rows.first as Map),
      );
    }
    if (rows is Map) {
      return BusinessRatingSummary.fromJson(Map<String, dynamic>.from(rows));
    }
    return BusinessRatingSummary.empty();
  }

  Future<BusinessReviewStatus> fetchMyReviewStatus({
    required String eventId,
    required String businessId,
  }) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return const BusinessReviewStatus(hasReviewed: false);

    final data = await SupabaseService.client
        .from('business_reviews')
        .select('id')
        .eq('event_id', eventId)
        .eq('business_id', businessId)
        .eq('user_id', userId)
        .maybeSingle();

    return BusinessReviewStatus(hasReviewed: data != null);
  }

  Future<void> submitReview(BusinessReviewInput input) async {
    final validationError = input.validationError;
    if (validationError != null) {
      throw BusinessReviewException(validationError);
    }

    try {
      await SupabaseService.client.rpc(
        'submit_business_review',
        params: {
          'p_event_id': input.eventId,
          'p_business_id': input.businessId,
          'p_rating': input.rating,
          'p_comment': BusinessReviewRules.normalizeComment(input.comment),
        },
      );
    } catch (error) {
      throw BusinessReviewException(friendlyBusinessReviewErrorMessage(error));
    }
  }
}

class BusinessReviewException implements Exception {
  const BusinessReviewException(this.message);

  final String message;

  @override
  String toString() => message;
}

String friendlyBusinessReviewErrorMessage(Object error) {
  final normalized = error.toString().toLowerCase();
  if (normalized.contains('invalid_rating') ||
      normalized.contains('business_reviews_rating_check')) {
    return 'Puan 1 ile 5 arasında olmalı.';
  }
  if (normalized.contains('not_attended') ||
      normalized.contains('event_not_attended') ||
      normalized.contains('not_business_event') ||
      normalized.contains('cannot_rate_own_business')) {
    return 'Bu işletmeyi değerlendirmek için etkinliğe katılmış olmalısın.';
  }
  if (normalized.contains('business_reviews_one_per_event_user') ||
      normalized.contains('duplicate') ||
      normalized.contains('23505')) {
    return 'Değerlendirmen alındı.';
  }
  return 'Değerlendirme gönderilemedi. Tekrar dene.';
}
