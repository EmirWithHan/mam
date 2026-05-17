class Event {
  const Event({
    required this.id,
    required this.hostId,
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
  final String sportType;
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

  bool get isFull => approvedCount >= capacityTotal;

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
    final districtValue = district;
    if (districtValue == null || districtValue.trim().isEmpty) return city;
    return '$city / $districtValue';
  }

  String get capacityLabel => '$approvedCount / $capacityTotal approved';

  String get formattedCapacityLabel {
    return '$approvedCount / $capacityTotal kişi onaylandı';
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      hostId: json['host_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      sportType: json['sport_type'] as String,
      city: json['city'] as String,
      district: json['district'] as String?,
      locationText: json['location_text'] as String?,
      locationLat: (json['location_lat'] as num?)?.toDouble(),
      locationLng: (json['location_lng'] as num?)?.toDouble(),
      eventDate: DateTime.parse(json['event_date'].toString()),
      capacityTotal: (json['capacity_total'] as num).toInt(),
      capacityMale: (json['capacity_male'] as num?)?.toInt(),
      capacityFemale: (json['capacity_female'] as num?)?.toInt(),
      capacityAny: (json['capacity_any'] as num?)?.toInt(),
      approvedCount: (json['approved_count'] as num?)?.toInt() ?? 0,
      status: json['status'] as String,
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
