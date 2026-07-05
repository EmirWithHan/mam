class AdminDashboardData {
  final int totalUsers;
  final int totalEvents;
  final int pendingBusinessAppsCount;
  final List<AdminRecentEvent> recentEvents;
  final List<AdminPendingBusinessApp> pendingBusinessApps;
  final List<AdminModerationAction> recentModerationActions;

  const AdminDashboardData({
    required this.totalUsers,
    required this.totalEvents,
    required this.pendingBusinessAppsCount,
    required this.recentEvents,
    required this.pendingBusinessApps,
    required this.recentModerationActions,
  });

  factory AdminDashboardData.fromJson(Map<String, dynamic> json) {
    final eventsList = json['recent_events'] as List? ?? [];
    final appsList = json['pending_business_apps_list'] as List? ?? [];
    final modsList = json['recent_moderation_actions'] as List? ?? [];

    return AdminDashboardData(
      totalUsers: (json['total_users'] as num?)?.toInt() ?? 0,
      totalEvents: (json['total_events'] as num?)?.toInt() ?? 0,
      pendingBusinessAppsCount:
          (json['pending_business_apps'] as num?)?.toInt() ?? 0,
      recentEvents: eventsList
          .map(
            (e) =>
                AdminRecentEvent.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      pendingBusinessApps: appsList
          .map(
            (e) => AdminPendingBusinessApp.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      recentModerationActions: modsList
          .map(
            (e) => AdminModerationAction.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );
  }
}

class AdminRecentEvent {
  final String id;
  final String title;
  final String hostId;
  final String? businessAccountId;
  final DateTime eventDate;
  final String moderationStatus;
  final DateTime createdAt;
  final int participantCount;

  const AdminRecentEvent({
    required this.id,
    required this.title,
    required this.hostId,
    this.businessAccountId,
    required this.eventDate,
    required this.moderationStatus,
    required this.createdAt,
    required this.participantCount,
  });

  factory AdminRecentEvent.fromJson(Map<String, dynamic> json) {
    return AdminRecentEvent(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      hostId: json['host_id']?.toString() ?? '',
      businessAccountId: json['organizer_business_id']?.toString(),
      eventDate: DateTime.parse(json['event_date'].toString()),
      moderationStatus: json['moderation_status']?.toString() ?? 'approved',
      createdAt: DateTime.parse(json['created_at'].toString()),
      participantCount: (json['participant_count'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isRemoved => moderationStatus == 'removed_by_admin';
}

class AdminPendingBusinessApp {
  final String id;
  final String userId;
  final String businessName;
  final String category;
  final String fullAddress;
  final String businessPhone;
  final String? website;
  final String? description;
  final String status;
  final DateTime createdAt;

  const AdminPendingBusinessApp({
    required this.id,
    required this.userId,
    required this.businessName,
    required this.category,
    required this.fullAddress,
    required this.businessPhone,
    this.website,
    this.description,
    required this.status,
    required this.createdAt,
  });

  factory AdminPendingBusinessApp.fromJson(Map<String, dynamic> json) {
    return AdminPendingBusinessApp(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      businessName: json['business_name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Diğer',
      fullAddress: json['full_address']?.toString() ?? '',
      businessPhone: json['business_phone']?.toString() ?? '',
      website: json['website']?.toString(),
      description: json['description']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      createdAt: DateTime.parse(json['created_at'].toString()),
    );
  }
}

class AdminModerationAction {
  final String id;
  final String? adminUserId;
  final String action;
  final String targetType;
  final String targetId;
  final String? reason;
  final DateTime createdAt;

  const AdminModerationAction({
    required this.id,
    this.adminUserId,
    required this.action,
    required this.targetType,
    required this.targetId,
    this.reason,
    required this.createdAt,
  });

  factory AdminModerationAction.fromJson(Map<String, dynamic> json) {
    return AdminModerationAction(
      id: json['id']?.toString() ?? '',
      adminUserId: json['admin_user_id']?.toString(),
      action: json['action']?.toString() ?? '',
      targetType: json['target_type']?.toString() ?? '',
      targetId: json['target_id']?.toString() ?? '',
      reason: json['reason']?.toString(),
      createdAt: DateTime.parse(json['created_at'].toString()),
    );
  }

  String get displayAction {
    switch (action) {
      case 'admin_removed':
        return 'Etkinlik kaldırıldı';
      case 'admin_restored':
        return 'Etkinlik geri yüklendi';
      case 'business_application_approved':
        return 'İşletme başvurusu onaylandı';
      case 'business_application_rejected':
        return 'İşletme başvurusu reddedildi';
      default:
        return action;
    }
  }
}
