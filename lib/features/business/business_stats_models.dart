class BusinessStats {
  const BusinessStats({
    required this.totalEvents,
    required this.upcomingEvents,
    required this.pastEvents,
    required this.totalJoinRequests,
    required this.confirmedParticipants,
    required this.checkedInCount,
    required this.noShowCount,
    required this.waitlistedCount,
    required this.averageRating,
    required this.ratingCount,
    required this.sponsoredEventsCount,
  });

  final int totalEvents;
  final int upcomingEvents;
  final int pastEvents;
  final int totalJoinRequests;
  final int confirmedParticipants;
  final int checkedInCount;
  final int noShowCount;
  final int waitlistedCount;
  final double averageRating;
  final int ratingCount;
  final int sponsoredEventsCount;

  bool get isEmpty {
    return totalEvents == 0 &&
        totalJoinRequests == 0 &&
        confirmedParticipants == 0 &&
        checkedInCount == 0 &&
        noShowCount == 0 &&
        waitlistedCount == 0 &&
        ratingCount == 0 &&
        sponsoredEventsCount == 0;
  }

  String get averageRatingLabel {
    if (ratingCount <= 0) return '-';
    return averageRating.toStringAsFixed(1);
  }

  factory BusinessStats.empty() {
    return const BusinessStats(
      totalEvents: 0,
      upcomingEvents: 0,
      pastEvents: 0,
      totalJoinRequests: 0,
      confirmedParticipants: 0,
      checkedInCount: 0,
      noShowCount: 0,
      waitlistedCount: 0,
      averageRating: 0,
      ratingCount: 0,
      sponsoredEventsCount: 0,
    );
  }

  factory BusinessStats.fromJson(Map<String, dynamic> json) {
    return BusinessStats(
      totalEvents: _intFromJson(json['total_events']),
      upcomingEvents: _intFromJson(json['upcoming_events']),
      pastEvents: _intFromJson(json['past_events']),
      totalJoinRequests: _intFromJson(json['total_join_requests']),
      confirmedParticipants: _intFromJson(json['confirmed_participants']),
      checkedInCount: _intFromJson(json['checked_in_count']),
      noShowCount: _intFromJson(json['no_show_count']),
      waitlistedCount: _intFromJson(json['waitlisted_count']),
      averageRating: _doubleFromJson(json['average_rating']),
      ratingCount: _intFromJson(json['rating_count']),
      sponsoredEventsCount: _intFromJson(json['sponsored_events_count']),
    );
  }
}

class BusinessStatsRules {
  const BusinessStatsRules._();

  static bool canViewStats({
    required String? ownerUserId,
    required String? currentUserId,
  }) {
    return ownerUserId != null &&
        ownerUserId.isNotEmpty &&
        ownerUserId == currentUserId;
  }
}

int _intFromJson(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _doubleFromJson(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
