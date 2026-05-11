enum ReportTargetType {
  user,
  event,
  post,
  comment,
}

enum ReportReason {
  spam,
  harassment,
  fakeEvent,
  inappropriateContent,
  safetyConcern,
  other,
}

class ReportInput {
  const ReportInput({
    required this.targetType,
    required this.targetId,
    required this.reason,
    this.description,
  });

  final ReportTargetType targetType;
  final String targetId;
  final ReportReason reason;
  final String? description;

  Map<String, dynamic> toCreateJson({required String reporterId}) {
    return {
      'reporter_id': reporterId,
      'target_type': targetType.value,
      'target_id': targetId,
      'reason': reason.value,
      'description': _nullableTrim(description),
    };
  }
}

class Report {
  const Report({
    required this.id,
    required this.reporterId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    this.description,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String reporterId;
  final ReportTargetType targetType;
  final String targetId;
  final ReportReason reason;
  final String? description;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] as String,
      reporterId: json['reporter_id'] as String,
      targetType: _targetTypeFromValue(json['target_type'].toString()),
      targetId: json['target_id'] as String,
      reason: _reasonFromValue(json['reason'].toString()),
      description: json['description'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'].toString()),
      updatedAt: _dateTimeFromJson(json['updated_at']),
    );
  }
}

extension ReportTargetTypeValue on ReportTargetType {
  String get value {
    switch (this) {
      case ReportTargetType.user:
        return 'user';
      case ReportTargetType.event:
        return 'event';
      case ReportTargetType.post:
        return 'post';
      case ReportTargetType.comment:
        return 'comment';
    }
  }
}

extension ReportReasonValue on ReportReason {
  String get value {
    switch (this) {
      case ReportReason.spam:
        return 'spam';
      case ReportReason.harassment:
        return 'harassment';
      case ReportReason.fakeEvent:
        return 'fake_event';
      case ReportReason.inappropriateContent:
        return 'inappropriate_content';
      case ReportReason.safetyConcern:
        return 'safety_concern';
      case ReportReason.other:
        return 'other';
    }
  }

  String get label {
    switch (this) {
      case ReportReason.spam:
        return 'Spam';
      case ReportReason.harassment:
        return 'Harassment';
      case ReportReason.fakeEvent:
        return 'Fake event';
      case ReportReason.inappropriateContent:
        return 'Inappropriate content';
      case ReportReason.safetyConcern:
        return 'Safety concern';
      case ReportReason.other:
        return 'Other';
    }
  }
}

ReportTargetType _targetTypeFromValue(String value) {
  return ReportTargetType.values.firstWhere(
    (type) => type.value == value,
    orElse: () => ReportTargetType.user,
  );
}

ReportReason _reasonFromValue(String value) {
  return ReportReason.values.firstWhere(
    (reason) => reason.value == value,
    orElse: () => ReportReason.other,
  );
}

DateTime? _dateTimeFromJson(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

String? _nullableTrim(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
