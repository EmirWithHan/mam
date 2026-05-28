class BusinessReviewInput {
  const BusinessReviewInput({
    required this.eventId,
    required this.businessId,
    required this.rating,
    this.comment,
  });

  final String eventId;
  final String businessId;
  final int rating;
  final String? comment;

  String? get validationError {
    if (!BusinessReviewRules.isValidRating(rating)) {
      return 'Puan 1 ile 5 arasında olmalı.';
    }
    if (BusinessReviewRules.normalizeComment(comment).length >
        BusinessReviewRules.maxCommentLength) {
      return 'Yorum en fazla 300 karakter olabilir.';
    }
    return null;
  }
}

class BusinessReviewStatus {
  const BusinessReviewStatus({required this.hasReviewed});

  final bool hasReviewed;
}

class BusinessRatingSummary {
  const BusinessRatingSummary({
    required this.averageRating,
    required this.ratingCount,
  });

  final double averageRating;
  final int ratingCount;

  bool get hasRatings => ratingCount > 0;

  String get averageLabel {
    if (!hasRatings) return '';
    return '${averageRating.toStringAsFixed(1)} ★';
  }

  String get countLabel {
    if (!hasRatings) return 'Henüz değerlendirme yok.';
    return '$ratingCount değerlendirme';
  }

  factory BusinessRatingSummary.empty() {
    return const BusinessRatingSummary(averageRating: 0, ratingCount: 0);
  }

  factory BusinessRatingSummary.fromJson(Map<String, dynamic> json) {
    return BusinessRatingSummary(
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class BusinessReviewRules {
  const BusinessReviewRules._();

  static const minRating = 1;
  static const maxRating = 5;
  static const maxCommentLength = 300;

  static bool isValidRating(int value) {
    return value >= minRating && value <= maxRating;
  }

  static int clampRating(int value) {
    return value.clamp(minRating, maxRating).toInt();
  }

  static String normalizeComment(String? value) {
    return (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool canReviewBusinessEvent({
    required bool isBusinessEvent,
    required bool isOwner,
    required String? attendanceStatus,
  }) {
    if (!isBusinessEvent || isOwner) return false;
    return attendanceStatus == 'checked_in' || attendanceStatus == 'confirmed';
  }
}
