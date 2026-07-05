class BusinessPlusAnalytics {
  final int totalEvents;
  final int upcomingEvents;
  final int pastEvents;
  final int totalParticipants;
  final int totalCheckedIn;
  final double attendanceRate;
  final int pendingJoinRequests;
  final int approvedJoinRequests;
  final int rejectedJoinRequests;
  final int monthlyBoostsUsed;
  final int monthlyBoostsRemaining;
  final int activeBoosts;
  final int expiredBoosts;
  final List<BusinessPlusTopEvent> topEvents;
  final List<BusinessPlusRecentEvent> recentEvents;

  const BusinessPlusAnalytics({
    required this.totalEvents,
    required this.upcomingEvents,
    required this.pastEvents,
    required this.totalParticipants,
    required this.totalCheckedIn,
    required this.attendanceRate,
    required this.pendingJoinRequests,
    required this.approvedJoinRequests,
    required this.rejectedJoinRequests,
    required this.monthlyBoostsUsed,
    required this.monthlyBoostsRemaining,
    required this.activeBoosts,
    required this.expiredBoosts,
    required this.topEvents,
    required this.recentEvents,
  });

  factory BusinessPlusAnalytics.fromJson(Map<String, dynamic> json) {
    final topList = json['top_events'] as List? ?? [];
    final recentList = json['recent_events'] as List? ?? [];

    return BusinessPlusAnalytics(
      totalEvents: (json['total_events'] as num?)?.toInt() ?? 0,
      upcomingEvents: (json['upcoming_events'] as num?)?.toInt() ?? 0,
      pastEvents: (json['past_events'] as num?)?.toInt() ?? 0,
      totalParticipants: (json['total_participants'] as num?)?.toInt() ?? 0,
      totalCheckedIn: (json['total_checked_in'] as num?)?.toInt() ?? 0,
      attendanceRate: (json['attendance_rate'] as num?)?.toDouble() ?? 0.0,
      pendingJoinRequests:
          (json['pending_join_requests'] as num?)?.toInt() ?? 0,
      approvedJoinRequests:
          (json['approved_join_requests'] as num?)?.toInt() ?? 0,
      rejectedJoinRequests:
          (json['rejected_join_requests'] as num?)?.toInt() ?? 0,
      monthlyBoostsUsed: (json['monthly_boosts_used'] as num?)?.toInt() ?? 0,
      monthlyBoostsRemaining:
          (json['monthly_boosts_remaining'] as num?)?.toInt() ?? 5,
      activeBoosts: (json['active_boosts'] as num?)?.toInt() ?? 0,
      expiredBoosts: (json['expired_boosts'] as num?)?.toInt() ?? 0,
      topEvents: topList
          .map(
            (e) => BusinessPlusTopEvent.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      recentEvents: recentList
          .map(
            (e) => BusinessPlusRecentEvent.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );
  }

  bool get isEmpty => totalEvents == 0;
}

class BusinessPlusTopEvent {
  final String id;
  final String title;
  final DateTime eventDate;
  final int participantCount;
  final int checkInCount;

  const BusinessPlusTopEvent({
    required this.id,
    required this.title,
    required this.eventDate,
    required this.participantCount,
    required this.checkInCount,
  });

  factory BusinessPlusTopEvent.fromJson(Map<String, dynamic> json) {
    return BusinessPlusTopEvent(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      eventDate: DateTime.parse(json['event_date'].toString()),
      participantCount: (json['participant_count'] as num?)?.toInt() ?? 0,
      checkInCount: (json['check_in_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class BusinessPlusRecentEvent {
  final String id;
  final String title;
  final DateTime eventDate;
  final int participantCount;
  final int checkInCount;
  final int noShowCount;
  final int joinRequestsCount;

  const BusinessPlusRecentEvent({
    required this.id,
    required this.title,
    required this.eventDate,
    required this.participantCount,
    required this.checkInCount,
    required this.noShowCount,
    required this.joinRequestsCount,
  });

  factory BusinessPlusRecentEvent.fromJson(Map<String, dynamic> json) {
    return BusinessPlusRecentEvent(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      eventDate: DateTime.parse(json['event_date'].toString()),
      participantCount: (json['participant_count'] as num?)?.toInt() ?? 0,
      checkInCount: (json['check_in_count'] as num?)?.toInt() ?? 0,
      noShowCount: (json['no_show_count'] as num?)?.toInt() ?? 0,
      joinRequestsCount: (json['join_requests_count'] as num?)?.toInt() ?? 0,
    );
  }
}
