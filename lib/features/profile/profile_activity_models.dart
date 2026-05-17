import '../../core/utils/date_formatter.dart';

class ProfileGalleryPost {
  const ProfileGalleryPost({
    required this.id,
    required this.imageUrl,
    this.caption,
    this.eventId,
    required this.createdAt,
  });

  final String id;
  final String imageUrl;
  final String? caption;
  final String? eventId;
  final DateTime createdAt;

  factory ProfileGalleryPost.fromJson(Map<String, dynamic> json) {
    return ProfileGalleryPost(
      id: json['id'] as String,
      imageUrl: json['image_url'] as String,
      caption: json['caption'] as String?,
      eventId: json['event_id'] as String?,
      createdAt: DateTime.parse(json['created_at'].toString()),
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

  String get locationLabel {
    final districtValue = district?.trim();
    if (districtValue == null || districtValue.isEmpty) return city;
    return '$city / $districtValue';
  }

  String get displayDate => DateFormatter.turkishEventDateTime(eventDate);

  String get roleLabel => isHost ? 'Host' : 'Katılımcı';

  factory ProfileActivityEvent.fromJson(
    Map<String, dynamic> json, {
    String? role,
    String? attendanceStatus,
  }) {
    return ProfileActivityEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      sportType: json['sport_type'] as String,
      city: json['city'] as String,
      district: json['district'] as String?,
      eventDate: DateTime.parse(json['event_date'].toString()),
      role: role,
      attendanceStatus: attendanceStatus,
      capacityTotal: (json['capacity_total'] as num?)?.toInt(),
      approvedCount: (json['approved_count'] as num?)?.toInt(),
    );
  }
}
