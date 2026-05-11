class Profile {
  const Profile({
    required this.id,
    required this.userId,
    this.username,
    this.tag,
    this.firstName,
    this.lastName,
    this.birthDate,
    this.gender,
    this.city,
    this.district,
    this.phone,
    this.avatarUrl,
    this.trustScore,
    this.isProfileCompleted = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String? username;
  final String? tag;
  final String? firstName;
  final String? lastName;
  final DateTime? birthDate;
  final String? gender;
  final String? city;
  final String? district;
  final String? phone;
  final String? avatarUrl;
  final int? trustScore;
  final bool isProfileCompleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get trustScoreValue => trustScore ?? 50;

  String get trustLabel {
    final score = trustScoreValue;
    if (score <= 39) return 'Low trust';
    if (score <= 59) return 'New user';
    if (score <= 79) return 'Reliable participant';
    return 'Highly trusted';
  }

  String get trustDescription {
    final score = trustScoreValue;
    if (score <= 39) return 'Build reliability through positive participation.';
    if (score <= 59) return 'A fresh reliability profile with room to grow.';
    if (score <= 79) return 'Shows consistent event participation.';
    return 'Strong reliability signal in the community.';
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      username: json['username'] as String?,
      tag: json['tag'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      birthDate: _dateTimeFromJson(json['birth_date']),
      gender: json['gender'] as String?,
      city: json['city'] as String?,
      district: json['district'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      trustScore: (json['trust_score'] as num?)?.toInt(),
      isProfileCompleted: json['is_profile_completed'] as bool? ?? false,
      createdAt: _dateTimeFromJson(json['created_at']),
      updatedAt: _dateTimeFromJson(json['updated_at']),
    );
  }

  Profile copyWith({
    String? id,
    String? userId,
    String? username,
    String? tag,
    String? firstName,
    String? lastName,
    DateTime? birthDate,
    String? gender,
    String? city,
    String? district,
    String? phone,
    String? avatarUrl,
    int? trustScore,
    bool? isProfileCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Profile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      tag: tag ?? this.tag,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      city: city ?? this.city,
      district: district ?? this.district,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      trustScore: trustScore ?? this.trustScore,
      isProfileCompleted: isProfileCompleted ?? this.isProfileCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ProfileFormData {
  const ProfileFormData({
    required this.username,
    required this.tag,
    required this.firstName,
    required this.lastName,
    required this.birthDate,
    required this.gender,
    required this.city,
    this.district,
    this.phone,
    this.avatarUrl,
  });

  final String username;
  final String tag;
  final DateTime birthDate;
  final String firstName;
  final String lastName;
  final String gender;
  final String city;
  final String? district;
  final String? phone;
  final String? avatarUrl;

  bool get isComplete {
    return username.trim().isNotEmpty &&
        tag.trim().isNotEmpty &&
        firstName.trim().isNotEmpty &&
        lastName.trim().isNotEmpty &&
        gender.trim().isNotEmpty &&
        city.trim().isNotEmpty;
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'username': username.trim(),
      'tag': tag.trim(),
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'birth_date': _dateToJson(birthDate),
      'gender': gender.trim(),
      'city': city.trim(),
      'district': _nullableTrim(district),
      'phone': _nullableTrim(phone),
      'avatar_url': _nullableTrim(avatarUrl),
      'is_profile_completed': isComplete,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}

DateTime? _dateTimeFromJson(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

String _dateToJson(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String? _nullableTrim(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
