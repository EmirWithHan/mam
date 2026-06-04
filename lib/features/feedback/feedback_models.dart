class FeedbackCategory {
  const FeedbackCategory._();

  static const bug = 'Hata';
  static const suggestion = 'Öneri';
  static const eventExperience = 'Etkinlik deneyimi';
  static const businessExperience = 'İşletme deneyimi';
  static const other = 'Diğer';

  static const values = [
    bug,
    suggestion,
    eventExperience,
    businessExperience,
    other,
  ];
}

class UserFeedbackRules {
  const UserFeedbackRules._();

  static const minRating = 1;
  static const maxRating = 5;
  static const maxMessageLength = 1000;

  static bool isValidRating(int? rating) {
    return rating == null || (rating >= minRating && rating <= maxRating);
  }

  static String normalizeMessage(String? value) {
    return (value ?? '').trim();
  }

  static String? validationError(UserFeedbackInput input) {
    if (!isValidRating(input.rating)) {
      return 'Puan 1 ile 5 arasında olmalı.';
    }
    if (normalizeMessage(input.message).length > maxMessageLength) {
      return 'Mesaj en fazla 1000 karakter olabilir.';
    }
    if (input.rating == null &&
        (input.category == null || input.category!.trim().isEmpty) &&
        normalizeMessage(input.message).isEmpty) {
      return 'Puan, kategori veya mesaj ekle.';
    }
    return null;
  }
}

class UserFeedbackInput {
  const UserFeedbackInput({
    this.rating,
    this.category,
    this.message,
    this.source = 'settings',
  });

  final int? rating;
  final String? category;
  final String? message;
  final String? source;

  String? get validationError => UserFeedbackRules.validationError(this);

  Map<String, dynamic> toInsertJson({required String userId}) {
    final normalizedCategory = category?.trim();
    final normalizedMessage = UserFeedbackRules.normalizeMessage(message);
    final normalizedSource = source?.trim();

    return {
      'user_id': userId,
      'rating': rating,
      'category': normalizedCategory == null || normalizedCategory.isEmpty
          ? null
          : normalizedCategory,
      'message': normalizedMessage.isEmpty ? null : normalizedMessage,
      'source': normalizedSource == null || normalizedSource.isEmpty
          ? null
          : normalizedSource,
    };
  }
}

class UserFeedback {
  const UserFeedback({
    required this.id,
    required this.userId,
    this.rating,
    this.category,
    this.message,
    this.source,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final int? rating;
  final String? category;
  final String? message;
  final String? source;
  final DateTime createdAt;

  factory UserFeedback.fromJson(Map<String, dynamic> json) {
    return UserFeedback(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      rating: (json['rating'] as num?)?.toInt(),
      category: json['category']?.toString(),
      message: json['message']?.toString(),
      source: json['source']?.toString(),
      createdAt: DateTime.parse(json['created_at'].toString()),
    );
  }
}

class ReviewPromptSignal {
  const ReviewPromptSignal({
    this.completedOrJoinedEvent = false,
    this.highTrustScore = false,
    this.positiveBusinessReview = false,
    this.usedAppForSomeTime = false,
    this.hadRecentError = false,
    this.hadNoShow = false,
    this.submittedReport = false,
  });

  final bool completedOrJoinedEvent;
  final bool highTrustScore;
  final bool positiveBusinessReview;
  final bool usedAppForSomeTime;
  final bool hadRecentError;
  final bool hadNoShow;
  final bool submittedReport;
}

class ReviewPromptRules {
  const ReviewPromptRules._();

  static const minDaysBetweenPrompts = 30;

  static bool canShow({
    required ReviewPromptSignal signal,
    required bool isFirstLaunch,
    required DateTime now,
    DateTime? lastPromptAt,
  }) {
    if (isFirstLaunch) return false;
    if (signal.hadRecentError || signal.hadNoShow || signal.submittedReport) {
      return false;
    }
    if (lastPromptAt != null &&
        now.difference(lastPromptAt).inDays < minDaysBetweenPrompts) {
      return false;
    }

    return signal.completedOrJoinedEvent ||
        signal.highTrustScore ||
        signal.positiveBusinessReview ||
        signal.usedAppForSomeTime;
  }
}

String friendlyFeedbackErrorMessage(Object error) {
  return 'Geri bildirim gönderilemedi. Tekrar dene.';
}
