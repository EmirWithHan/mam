import '../../core/utils/user_handle.dart';

class Event {
  const Event({
    required this.id,
    required this.hostId,
    required this.title,
    this.description,
    this.sportType,
    required this.city,
    this.district,
    this.locationText,
    this.locationLat,
    this.locationLng,
    required this.eventDate,
    required this.capacityTotal,
    this.capacityMale,
    this.capacityFemale,
    this.capacityAny,
    this.approvedCount = 0,
    required this.status,
    this.isSponsored = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String hostId;
  final String title;
  final String? description;
  final String? sportType;
  final String city;
  final String? district;
  final String? locationText;
  final double? locationLat;
  final double? locationLng;
  final DateTime eventDate;
  final int capacityTotal;
  final int? capacityMale;
  final int? capacityFemale;
  final int? capacityAny;
  final int approvedCount;
  final String status;
  final bool isSponsored;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool isHost(String? userId) => userId != null && hostId == userId;

  bool get isPast => eventDate.isBefore(DateTime.now());

  int get safeCapacityTotal => capacityTotal < 0 ? 0 : capacityTotal;

  int get safeApprovedCount => approvedCount < 0 ? 0 : approvedCount;

  String get titleLabel {
    final text = title.trim();
    if (text.isEmpty) return 'Etkinlik';
    return text;
  }

  bool get isFull =>
      safeCapacityTotal > 0 && safeApprovedCount >= safeCapacityTotal;

  bool get hasDescription => description?.trim().isNotEmpty == true;

  String get descriptionLabel {
    final text = description?.trim();
    if (text == null || text.isEmpty) return 'Açıklama eklenmemiş.';
    return text;
  }

  bool get hasCoordinates => locationLat != null && locationLng != null;

  bool get hasLocation {
    final text = locationText?.trim();
    return hasCoordinates || (text != null && text.isNotEmpty);
  }

  String get locationDisplayLabel {
    final text = locationText?.trim();
    if (text != null && text.isNotEmpty && !_looksLikeRawCoordinates(text)) {
      return text;
    }
    if (hasCoordinates) return 'Haritada görüntüle';
    return 'Konum bilgisi eklenmemiş.';
  }

  String get locationLabel {
    final cityValue = city.trim();
    final districtValue = district?.trim();
    if (cityValue.isEmpty && (districtValue == null || districtValue.isEmpty)) {
      return 'Konum belirtilmedi';
    }
    if (districtValue == null || districtValue.isEmpty) return cityValue;
    if (cityValue.isEmpty) return districtValue;
    return '$cityValue / $districtValue';
  }

  String get capacityLabel => formattedCapacityLabel;

  String get formattedCapacityLabel {
    return '$approvedCount / $capacityTotal kişi onaylandı';
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id']?.toString() ?? '',
      hostId: json['host_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description'] as String?,
      sportType: json['sport_type']?.toString(),
      city: json['city']?.toString() ?? '',
      district: json['district']?.toString(),
      locationText: json['location_text']?.toString(),
      locationLat: (json['location_lat'] as num?)?.toDouble(),
      locationLng: (json['location_lng'] as num?)?.toDouble(),
      eventDate: _dateTimeFromJson(json['event_date']) ?? DateTime.now(),
      capacityTotal: _intFromJson(json['capacity_total']),
      capacityMale: (json['capacity_male'] as num?)?.toInt(),
      capacityFemale: (json['capacity_female'] as num?)?.toInt(),
      capacityAny: (json['capacity_any'] as num?)?.toInt(),
      approvedCount: _intFromJson(json['approved_count']),
      status: json['status']?.toString() ?? 'active',
      isSponsored: json['is_sponsored'] as bool? ?? false,
      createdAt: _dateTimeFromJson(json['created_at']),
      updatedAt: _dateTimeFromJson(json['updated_at']),
    );
  }

  Event copyWith({
    String? id,
    String? hostId,
    String? title,
    String? description,
    String? sportType,
    String? city,
    String? district,
    String? locationText,
    double? locationLat,
    double? locationLng,
    DateTime? eventDate,
    int? capacityTotal,
    int? capacityMale,
    int? capacityFemale,
    int? capacityAny,
    int? approvedCount,
    String? status,
    bool? isSponsored,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Event(
      id: id ?? this.id,
      hostId: hostId ?? this.hostId,
      title: title ?? this.title,
      description: description ?? this.description,
      sportType: sportType ?? this.sportType,
      city: city ?? this.city,
      district: district ?? this.district,
      locationText: locationText ?? this.locationText,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
      eventDate: eventDate ?? this.eventDate,
      capacityTotal: capacityTotal ?? this.capacityTotal,
      capacityMale: capacityMale ?? this.capacityMale,
      capacityFemale: capacityFemale ?? this.capacityFemale,
      capacityAny: capacityAny ?? this.capacityAny,
      approvedCount: approvedCount ?? this.approvedCount,
      status: status ?? this.status,
      isSponsored: isSponsored ?? this.isSponsored,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum EventDateFilter { all, today, thisWeek, upcoming }

class EventFilters {
  const EventFilters({
    this.selectedSportType,
    this.selectedCity,
    this.dateFilter = EventDateFilter.all,
    this.onlyAvailableSpots = false,
  });

  final String? selectedSportType;
  final String? selectedCity;
  final EventDateFilter dateFilter;
  final bool onlyAvailableSpots;

  bool get isActive {
    return selectedSportType?.trim().isNotEmpty == true ||
        selectedCity?.trim().isNotEmpty == true ||
        dateFilter != EventDateFilter.all ||
        onlyAvailableSpots;
  }

  EventFilters copyWith({
    String? selectedSportType,
    String? selectedCity,
    EventDateFilter? dateFilter,
    bool? onlyAvailableSpots,
    bool clearSportType = false,
    bool clearCity = false,
  }) {
    return EventFilters(
      selectedSportType: clearSportType
          ? null
          : selectedSportType ?? this.selectedSportType,
      selectedCity: clearCity ? null : selectedCity ?? this.selectedCity,
      dateFilter: dateFilter ?? this.dateFilter,
      onlyAvailableSpots: onlyAvailableSpots ?? this.onlyAvailableSpots,
    );
  }
}

class EventParticipationStatus {
  const EventParticipationStatus._();

  static const planned = 'planned';
  static const approved = 'approved';
  static const attended = 'attended';
  static const pending = 'pending';
  static const cancelled = 'cancelled';
  static const rejected = 'rejected';
  static const left = 'left';

  static bool isActiveApprovedParticipant(String? status) {
    return status == planned || status == attended;
  }

  static bool isApprovedParticipant(String? status) {
    return isActiveApprovedParticipant(status);
  }

  static bool hasLeftEvent(String? status) => status == left;

  static bool canLeaveApprovedEvent(String? status) {
    return isActiveApprovedParticipant(status);
  }
}

class EventParticipation {
  const EventParticipation({
    required this.role,
    required this.attendanceStatus,
  });

  final String role;
  final String attendanceStatus;

  bool get isParticipant => role == 'participant';

  bool get hasLeftEvent {
    return EventParticipationStatus.hasLeftEvent(attendanceStatus);
  }

  bool get isActiveApprovedParticipant {
    return isParticipant &&
        EventParticipationStatus.isActiveApprovedParticipant(attendanceStatus);
  }

  bool get canLeaveApprovedEvent => isActiveApprovedParticipant;

  factory EventParticipation.fromJson(Map<String, dynamic> json) {
    return EventParticipation(
      role: json['role'] as String? ?? '',
      attendanceStatus: json['attendance_status'] as String? ?? '',
    );
  }
}

class EventPublicParticipant {
  const EventPublicParticipant({
    required this.userId,
    this.username,
    this.tag,
    this.firstName,
    this.city,
    this.avatarUrl,
    required this.role,
    required this.attendanceStatus,
  });

  final String userId;
  final String? username;
  final String? tag;
  final String? firstName;
  final String? city;
  final String? avatarUrl;
  final String role;
  final String attendanceStatus;

  bool get isHost => role == 'host';

  bool get isActiveParticipant {
    return EventPublicParticipantVisibility.isActiveParticipant(
      role: role,
      attendanceStatus: attendanceStatus,
    );
  }

  String get displayName {
    final first = firstName?.trim();
    final user = username?.trim();
    if (first != null && first.isNotEmpty) {
      return first;
    }
    if (user != null && user.isNotEmpty) return user;
    return 'Katılımcı';
  }

  String? get handleLabel {
    return formatUserHandle(username, tag);
  }

  factory EventPublicParticipant.fromJson(Map<String, dynamic> json) {
    return EventPublicParticipant(
      userId: json['user_id'] as String,
      username: json['username'] as String?,
      tag: json['tag'] as String?,
      firstName: json['first_name'] as String?,
      city: json['city'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: json['role'] as String? ?? 'participant',
      attendanceStatus: json['attendance_status'] as String? ?? '',
    );
  }
}

class EventPublicParticipantVisibility {
  const EventPublicParticipantVisibility._();

  static bool canShow({
    required String role,
    required String attendanceStatus,
  }) {
    return role == 'host' ||
        isActiveParticipant(role: role, attendanceStatus: attendanceStatus);
  }

  static bool isActiveParticipant({
    required String role,
    required String attendanceStatus,
  }) {
    return role == 'participant' &&
        EventParticipationStatus.isActiveApprovedParticipant(attendanceStatus);
  }
}

class CreateEventInput {
  const CreateEventInput({
    required this.title,
    this.description,
    required this.sportType,
    required this.city,
    this.district,
    this.locationText,
    this.locationLat,
    this.locationLng,
    required this.eventDate,
    required this.capacityTotal,
    required this.capacityMale,
    required this.capacityFemale,
    required this.capacityAny,
  });

  final String title;
  final String? description;
  final String sportType;
  final String city;
  final String? district;
  final String? locationText;
  final double? locationLat;
  final double? locationLng;
  final DateTime eventDate;
  final int capacityTotal;
  final int capacityMale;
  final int capacityFemale;
  final int capacityAny;

  Map<String, dynamic> toCreateJson({required String hostId}) {
    return {
      'host_id': hostId,
      'title': title.trim(),
      'description': _nullableTrim(description),
      'sport_type': sportType.trim(),
      'city': city.trim(),
      'district': _nullableTrim(district),
      'location_text': _nullableTrim(locationText),
      if (locationLat != null) 'location_lat': locationLat,
      if (locationLng != null) 'location_lng': locationLng,
      'event_date': eventDate.toIso8601String(),
      'capacity_total': capacityTotal,
      'capacity_male': capacityMale,
      'capacity_female': capacityFemale,
      'capacity_any': capacityAny,
      'status': 'active',
    };
  }
}

DateTime? _dateTimeFromJson(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

int _intFromJson(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String? _nullableTrim(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

bool _looksLikeRawCoordinates(String value) {
  final trimmed = value.trim();
  if (trimmed == 'Mevcut konum seçildi') return true;
  if (trimmed.startsWith('Konum seçildi:')) return true;
  return RegExp(r'^-?\d+(\.\d+)?,\s*-?\d+(\.\d+)?$').hasMatch(trimmed);
}
