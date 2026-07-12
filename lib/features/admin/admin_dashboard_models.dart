class AdminDashboardData {
  final int totalUsers;
  final int totalEvents;
  final int pendingBusinessAppsCount;
  final int pendingReportsCount;
  final int pendingMessageReportsCount;
  final List<AdminRecentEvent> recentEvents;
  final List<AdminPendingBusinessApp> pendingBusinessApps;
  final List<AdminModerationAction> recentModerationActions;
  final List<AdminUserReport> recentReports;
  final List<AdminMessageReport> recentMessageReports;

  const AdminDashboardData({
    required this.totalUsers,
    required this.totalEvents,
    required this.pendingBusinessAppsCount,
    required this.pendingReportsCount,
    required this.pendingMessageReportsCount,
    required this.recentEvents,
    required this.pendingBusinessApps,
    required this.recentModerationActions,
    required this.recentReports,
    required this.recentMessageReports,
  });

  factory AdminDashboardData.fromJson(Map<String, dynamic> json) {
    final eventsList = json['recent_events'] as List? ?? [];
    final appsList = json['pending_business_apps_list'] as List? ?? [];
    final modsList = json['recent_moderation_actions'] as List? ?? [];
    final reportsList = json['recent_reports'] as List? ?? [];
    final msgReportsList = json['recent_message_reports'] as List? ?? [];

    return AdminDashboardData(
      totalUsers: (json['total_users'] as num?)?.toInt() ?? 0,
      totalEvents: (json['total_events'] as num?)?.toInt() ?? 0,
      pendingBusinessAppsCount:
          (json['pending_business_apps'] as num?)?.toInt() ?? 0,
      pendingReportsCount:
          (json['pending_reports_count'] as num?)?.toInt() ?? 0,
      pendingMessageReportsCount:
          (json['pending_message_reports_count'] as num?)?.toInt() ?? 0,
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
      recentReports: reportsList
          .map(
            (e) =>
                AdminUserReport.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      recentMessageReports: msgReportsList
          .map(
            (e) => AdminMessageReport.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );
  }
}

class AdminUserReport {
  final String id;
  final String reporterId;
  final String targetType;
  final String targetId;
  final String reason;
  final String? description;
  final String status;
  final DateTime createdAt;
  final String? reporterName;
  final String? targetName;
  final String? targetContent;
  final String? targetTitle;
  final String? targetDescription;
  final String? targetDate;
  final String? targetStartTime;
  final String? targetLocation;
  final String? targetHostName;
  final String? targetImageUrl;
  final String? targetAuthorName;
  final String? parentPostPreview;

  const AdminUserReport({
    required this.id,
    required this.reporterId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    this.description,
    required this.status,
    required this.createdAt,
    this.reporterName,
    this.targetName,
    this.targetContent,
    this.targetTitle,
    this.targetDescription,
    this.targetDate,
    this.targetStartTime,
    this.targetLocation,
    this.targetHostName,
    this.targetImageUrl,
    this.targetAuthorName,
    this.parentPostPreview,
  });

  factory AdminUserReport.fromJson(Map<String, dynamic> json) {
    return AdminUserReport(
      id: json['id']?.toString() ?? '',
      reporterId: json['reporter_id']?.toString() ?? '',
      targetType: json['target_type']?.toString() ?? '',
      targetId: json['target_id']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      description: json['description']?.toString(),
      status: json['status']?.toString() ?? 'open',
      createdAt: DateTime.parse(json['created_at'].toString()),
      reporterName: json['reporter_name']?.toString(),
      targetName: json['target_name']?.toString(),
      targetContent: json['target_content']?.toString(),
      targetTitle: json['target_title']?.toString(),
      targetDescription: json['target_description']?.toString(),
      targetDate: json['target_date']?.toString(),
      targetStartTime: json['target_start_time']?.toString(),
      targetLocation: json['target_location']?.toString(),
      targetHostName: json['target_host_name']?.toString(),
      targetImageUrl: json['target_image_url']?.toString(),
      targetAuthorName: json['target_author_name']?.toString(),
      parentPostPreview: json['parent_post_preview']?.toString(),
    );
  }
}

class AdminMessageReport {
  final String id;
  final String messageId;
  final String reporterId;
  final String reason;
  final DateTime createdAt;
  final String reportedUserId;
  final String messageType;
  final String? eventId;
  final String? conversationId;
  final String status;
  final String? reporterName;
  final String? reportedUserName;
  final String? messageContent;
  final String? eventTitle;

  const AdminMessageReport({
    required this.id,
    required this.messageId,
    required this.reporterId,
    required this.reason,
    required this.createdAt,
    required this.reportedUserId,
    required this.messageType,
    required this.eventId,
    required this.conversationId,
    required this.status,
    this.reporterName,
    this.reportedUserName,
    this.messageContent,
    this.eventTitle,
  });

  factory AdminMessageReport.fromJson(Map<String, dynamic> json) {
    return AdminMessageReport(
      id: json['id']?.toString() ?? '',
      messageId:
          json['message_id']?.toString() ??
          json['direct_message_id']?.toString() ??
          '',
      reporterId: json['reporter_id']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      createdAt: DateTime.parse(json['created_at'].toString()),
      reportedUserId: json['reported_user_id']?.toString() ?? '',
      messageType: json['message_type']?.toString() ?? '',
      eventId: json['event_id']?.toString(),
      conversationId: json['conversation_id']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      reporterName: json['reporter_name']?.toString(),
      reportedUserName: json['reported_user_name']?.toString(),
      messageContent:
          json['message_content']?.toString() ??
          json['reported_message_snapshot']?.toString(),
      eventTitle: json['event_title']?.toString(),
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
