import '../../core/utils/date_formatter.dart';

class ProfileGalleryPost {
  const ProfileGalleryPost({
    required this.id,
    required this.imageUrl,
    this.caption,
    this.eventId,
    this.commentsHidden = false,
    this.isArchived = false,
    required this.createdAt,
  });

  final String id;
  final String imageUrl;
  final String? caption;
  final String? eventId;
  final bool commentsHidden;
  final bool isArchived;
  final DateTime createdAt;

  factory ProfileGalleryPost.fromJson(Map<String, dynamic> json) {
    return ProfileGalleryPost(
      id: json['id'].toString(),
      imageUrl: json['image_url'] as String? ?? '',
      caption: json['caption'] as String?,
      eventId: json['event_id'] as String?,
      commentsHidden: json['comments_hidden'] as bool? ?? false,
      isArchived: json['is_archived'] as bool? ?? false,
      createdAt: _dateTimeFromJson(json['created_at']) ?? DateTime.now(),
    );
  }
}

class ProfileActivityEvent {
  const ProfileActivityEvent({
    required this.id,
    required this.title,
    required this.sportType,
    required this.city,
    this.district,
    required this.eventDate,
    this.role,
    this.attendanceStatus,
    this.capacityTotal,
    this.approvedCount,
  });

  final String id;
  final String title;
  final String sportType;
  final String city;
  final String? district;
  final DateTime eventDate;
  final String? role;
  final String? attendanceStatus;
  final int? capacityTotal;
  final int? approvedCount;

  bool get isHost => role == 'host';

  bool get isPast => eventDate.isBefore(DateTime.now());

  String get locationLabel {
    final districtValue = district?.trim();
    if (districtValue == null || districtValue.isEmpty) return city;
    return '$city / $districtValue';
  }

  String get displayDate => DateFormatter.turkishEventDateTime(eventDate);

  String get roleLabel => isHost ? 'Ev sahibi' : 'Katılımcı';

  factory ProfileActivityEvent.fromJson(
    Map<String, dynamic> json, {
    String? role,
    String? attendanceStatus,
  }) {
    return ProfileActivityEvent(
      id: json['id'].toString(),
      title: json['title'] as String? ?? '',
      sportType: json['sport_type'] as String? ?? '',
      city: json['city'] as String? ?? '',
      district: json['district'] as String?,
      eventDate: _dateTimeFromJson(json['event_date']) ?? DateTime.now(),
      role: role,
      attendanceStatus: attendanceStatus,
      capacityTotal: (json['capacity_total'] as num?)?.toInt(),
      approvedCount: (json['approved_count'] as num?)?.toInt(),
    );
  }
}

DateTime? _dateTimeFromJson(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
