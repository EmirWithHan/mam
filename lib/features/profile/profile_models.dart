class Profile {
  const Profile({
    required this.id,
    required this.userId,
    this.username,
    this.tag,
    this.firstName,
    this.birthDate,
    this.gender,
    this.city,
    this.district,
    this.phone,
    this.bio,
    this.avatarUrl,
    this.trustScore,
    this.isPrivate = false,
    this.isProfileCompleted = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String? username;
  final String? tag;
  final String? firstName;
  final DateTime? birthDate;
  final String? gender;
  final String? city;
  final String? district;
  final String? phone;
  final String? bio;
  final String? avatarUrl;
  final int? trustScore;
  final bool isPrivate;
  final bool isProfileCompleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get trustScoreValue => trustScore ?? 50;

  bool get hasCoreIdentity {
    return username?.trim().isNotEmpty == true &&
        firstName?.trim().isNotEmpty == true;
  }

  bool get hasEventRequiredFields {
    return hasCoreIdentity &&
        city?.trim().isNotEmpty == true &&
        district?.trim().isNotEmpty == true &&
        birthDate != null;
  }

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
    final userId = json['user_id']?.toString();
    if (userId == null || userId.isEmpty) {
      throw const ProfileSaveException('Profil kaydedilemedi. Tekrar dene.');
    }

    return Profile(
      id: (json['id'] ?? userId).toString(),
      userId: userId,
      username: json['username'] as String?,
      tag: json['tag'] as String?,
      firstName: json['first_name'] as String?,
      birthDate: _dateTimeFromJson(json['birth_date']),
      gender: json['gender'] as String?,
      city: json['city'] as String?,
      district: json['district'] as String?,
      phone: json['phone'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      trustScore: (json['trust_score'] as num?)?.toInt(),
      isPrivate: json['is_private'] as bool? ?? false,
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
    DateTime? birthDate,
    String? gender,
    String? city,
    String? district,
    String? phone,
    String? bio,
    String? avatarUrl,
    int? trustScore,
    bool? isPrivate,
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
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      city: city ?? this.city,
      district: district ?? this.district,
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      trustScore: trustScore ?? this.trustScore,
      isPrivate: isPrivate ?? this.isPrivate,
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
    this.birthDate,
    this.gender,
    this.city,
    this.district,
    this.phone,
    this.bio,
    this.avatarUrl,
  });

  final String username;
  final String tag;
  final DateTime? birthDate;
  final String firstName;
  final String? gender;
  final String? city;
  final String? district;
  final String? phone;
  final String? bio;
  final String? avatarUrl;

  bool get isComplete {
    return normalizedUsername.isNotEmpty &&
        tag.trim().isNotEmpty &&
        firstName.trim().isNotEmpty;
  }

  String get normalizedUsername => ProfileUsername.normalize(username);

  Map<String, dynamic> toUpdateJson() {
    return {
      'username': normalizedUsername,
      'tag': tag.trim(),
      'first_name': firstName.trim(),
      'birth_date': birthDate == null ? null : _dateToJson(birthDate!),
      'gender': _nullableTrim(gender),
      'city': _nullableTrim(city),
      'district': _nullableTrim(district),
      'phone': _nullableTrim(phone),
      'bio': _nullableTrim(bio),
      'avatar_url': _nullableTrim(avatarUrl),
      'is_profile_completed': isComplete,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}

class ProfileUsername {
  const ProfileUsername._();

  static const minLength = 2;
  static const maxLength = 20;
  static final _validPattern = RegExp(r'^[a-z0-9_]+$');

  static String normalize(String value) {
    return value
        .trim()
        .replaceAll('İ', 'i')
        .replaceAll('I', 'i')
        .replaceAll('ı', 'i')
        .toLowerCase();
  }

  static String? validate(String? value) {
    final normalized = normalize(value ?? '');
    if (normalized.length < minLength) {
      return 'Kullanıcı adı en az 2 karakter olmalı.';
    }
    if (normalized.length > maxLength) {
      return 'Kullanıcı adı en fazla 20 karakter olmalı.';
    }
    if (!_validPattern.hasMatch(normalized)) {
      return 'Kullanıcı adı sadece harf, rakam ve _ içerebilir.';
    }
    return null;
  }

  static String slug(String value) {
    final normalized = normalize(value);
    final underscored = normalized.replaceAll(RegExp(r'[\s.\-]+'), '_');
    final cleaned = underscored.replaceAll(RegExp(r'[^a-z0-9_]+'), '');
    final collapsed = cleaned.replaceAll(RegExp(r'_+'), '_');
    return collapsed.replaceAll(RegExp(r'^_+|_+$'), '');
  }

  static String socialSeed({
    String? preferredUsername,
    String? email,
    String? fullName,
    required String fallbackId,
  }) {
    final emailLocalPart = email?.split('@').first.trim();
    final rawSeed = [
      emailLocalPart,
      fullName,
      preferredUsername,
      'user_${_shortFallbackId(fallbackId)}',
    ].firstWhere((value) => value != null && value.trim().isNotEmpty)!;

    final value = slug(rawSeed);
    if (value.length >= minLength) return value;
    return 'user_${_shortFallbackId(fallbackId)}';
  }

  static String withSuffix(String base, String suffix) {
    final cleanBase = slug(base);
    final cleanSuffix = slug(suffix);
    if (cleanSuffix.isEmpty) return fit(cleanBase);

    final prefixMaxLength = maxLength - cleanSuffix.length - 1;
    final prefix = fit(cleanBase, limit: prefixMaxLength);
    return '${prefix}_$cleanSuffix';
  }

  static String fit(String value, {int limit = maxLength}) {
    final fallback = value.length >= minLength ? value : 'user';
    if (fallback.length <= limit) return fallback;
    return fallback.substring(0, limit);
  }

  static String _shortFallbackId(String id) {
    final compact = id.replaceAll('-', '');
    if (compact.length >= 6) return compact.substring(0, 6);
    if (compact.isNotEmpty) return compact;
    return '000000';
  }
}

class ProfileSaveException implements Exception {
  const ProfileSaveException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PublicProfileDetail {
  const PublicProfileDetail({
    required this.userId,
    this.username,
    this.tag,
    this.firstName,
    this.city,
    this.district,
    this.avatarUrl,
    this.bio,
    this.trustScore,
    this.isPrivate = false,
    this.followersCount = 0,
    this.followingCount = 0,
    this.isFollowing = false,
    this.isFollowedBy = false,
    this.pendingFollowRequestByMe = false,
    this.canViewExtendedProfile = false,
  });

  final String userId;
  final String? username;
  final String? tag;
  final String? firstName;
  final String? city;
  final String? district;
  final String? avatarUrl;
  final String? bio;
  final int? trustScore;
  final bool isPrivate;
  final int followersCount;
  final int followingCount;
  final bool isFollowing;
  final bool isFollowedBy;
  final bool pendingFollowRequestByMe;
  final bool canViewExtendedProfile;

  String get displayName {
    final first = firstName?.trim();
    final user = username?.trim();
    if (first != null && first.isNotEmpty) {
      return first;
    }
    if (user != null && user.isNotEmpty) return user;
    return 'Kullanıcı';
  }

  String? get handleLabel {
    final user = username?.trim();
    final userTag = tag?.trim();
    if (user == null || user.isEmpty) return null;
    if (userTag != null && userTag.isNotEmpty) return '$user#$userTag';
    return '@$user';
  }

  bool get hasBio => bio?.trim().isNotEmpty == true;

  String? get locationLabel {
    final cityValue = city?.trim();
    final districtValue = district?.trim();
    if (cityValue == null || cityValue.isEmpty) return null;
    if (districtValue == null || districtValue.isEmpty) return cityValue;
    return '$cityValue / $districtValue';
  }

  factory PublicProfileDetail.fromJson(Map<String, dynamic> json) {
    return PublicProfileDetail(
      userId: json['user_id'].toString(),
      username: json['username'] as String?,
      tag: json['tag'] as String?,
      firstName: json['first_name'] as String?,
      city: json['city'] as String?,
      district: json['district'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      trustScore: (json['trust_score'] as num?)?.toInt(),
      isPrivate: json['is_private'] as bool? ?? false,
      followersCount: (json['followers_count'] as num?)?.toInt() ?? 0,
      followingCount: (json['following_count'] as num?)?.toInt() ?? 0,
      isFollowing: json['is_following'] as bool? ?? false,
      isFollowedBy: json['is_followed_by'] as bool? ?? false,
      pendingFollowRequestByMe:
          json['pending_follow_request_by_me'] as bool? ?? false,
      canViewExtendedProfile:
          json['can_view_extended_profile'] as bool? ?? false,
    );
  }
}

class PublicProfileFollowListItem {
  const PublicProfileFollowListItem({
    required this.userId,
    this.username,
    this.fullName,
    this.avatarUrl,
    this.city,
    this.district,
    this.bio,
    this.trustScore,
    this.followerCount = 0,
    this.followingCount = 0,
    this.isFollowingByMe = false,
    this.followsMe = false,
    this.isPrivate = false,
    this.pendingFollowRequestByMe = false,
    this.createdAt,
  });

  final String userId;
  final String? username;
  final String? fullName;
  final String? avatarUrl;
  final String? city;
  final String? district;
  final String? bio;
  final int? trustScore;
  final int followerCount;
  final int followingCount;
  final bool isFollowingByMe;
  final bool followsMe;
  final bool isPrivate;
  final bool pendingFollowRequestByMe;
  final DateTime? createdAt;

  String get displayName {
    final name = fullName?.trim();
    final user = username?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (user != null && user.isNotEmpty) return user;
    return 'MaM User';
  }

  PublicProfileFollowListItem copyWith({
    bool? isFollowingByMe,
    bool? pendingFollowRequestByMe,
    int? followerCount,
  }) {
    return PublicProfileFollowListItem(
      userId: userId,
      username: username,
      fullName: fullName,
      avatarUrl: avatarUrl,
      city: city,
      district: district,
      bio: bio,
      trustScore: trustScore,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount,
      isFollowingByMe: isFollowingByMe ?? this.isFollowingByMe,
      followsMe: followsMe,
      isPrivate: isPrivate,
      pendingFollowRequestByMe:
          pendingFollowRequestByMe ?? this.pendingFollowRequestByMe,
      createdAt: createdAt,
    );
  }

  factory PublicProfileFollowListItem.fromJson(Map<String, dynamic> json) {
    return PublicProfileFollowListItem(
      userId: json['user_id'].toString(),
      username: json['username'] as String?,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      city: json['city'] as String?,
      district: json['district'] as String?,
      bio: json['bio'] as String?,
      trustScore: (json['trust_score'] as num?)?.toInt(),
      followerCount: (json['follower_count'] as num?)?.toInt() ?? 0,
      followingCount: (json['following_count'] as num?)?.toInt() ?? 0,
      isFollowingByMe: json['is_following_by_me'] as bool? ?? false,
      followsMe: json['follows_me'] as bool? ?? false,
      isPrivate: json['is_private'] as bool? ?? false,
      pendingFollowRequestByMe:
          json['pending_follow_request_by_me'] as bool? ?? false,
      createdAt: _dateTimeFromJson(json['created_at']),
    );
  }
}

class PublicProfileGalleryItem {
  const PublicProfileGalleryItem({
    required this.postId,
    required this.imageUrl,
    this.caption,
    this.eventId,
    this.commentsHidden = false,
    this.isArchived = false,
    required this.createdAt,
  });

  final String postId;
  final String imageUrl;
  final String? caption;
  final String? eventId;
  final bool commentsHidden;
  final bool isArchived;
  final DateTime createdAt;

  factory PublicProfileGalleryItem.fromJson(Map<String, dynamic> json) {
    return PublicProfileGalleryItem(
      postId: (json['post_id'] ?? json['id']).toString(),
      imageUrl: json['image_url'] as String? ?? '',
      caption: json['caption'] as String?,
      eventId: json['event_id'] as String?,
      commentsHidden: json['comments_hidden'] as bool? ?? false,
      isArchived: json['is_archived'] as bool? ?? false,
      createdAt: _dateTimeFromJson(json['created_at']) ?? DateTime.now(),
    );
  }
}

class PublicProfileEventHistoryItem {
  const PublicProfileEventHistoryItem({
    required this.eventId,
    required this.title,
    required this.sportType,
    required this.city,
    this.district,
    this.locationText,
    required this.status,
    required this.approvedCount,
    required this.capacityTotal,
    required this.eventDate,
    required this.createdAt,
    required this.role,
  });

  final String eventId;
  final String title;
  final String sportType;
  final String city;
  final String? district;
  final String? locationText;
  final String status;
  final int approvedCount;
  final int capacityTotal;
  final DateTime eventDate;
  final DateTime createdAt;
  final String role;

  String get locationLabel {
    final districtValue = district?.trim();
    if (districtValue == null || districtValue.isEmpty) return city;
    return '$city / $districtValue';
  }

  String get roleLabel => role == 'host' ? 'Host' : 'Katılımcı';

  bool get isPast => eventDate.isBefore(DateTime.now());

  factory PublicProfileEventHistoryItem.fromJson(Map<String, dynamic> json) {
    return PublicProfileEventHistoryItem(
      eventId: (json['event_id'] ?? json['id']).toString(),
      title: json['title'] as String? ?? '',
      sportType: json['sport_type'] as String? ?? '',
      city: json['city'] as String? ?? '',
      district: json['district'] as String?,
      locationText: json['location_text'] as String?,
      status: json['status'] as String? ?? '',
      approvedCount: (json['approved_count'] as num?)?.toInt() ?? 0,
      capacityTotal: (json['capacity_total'] as num?)?.toInt() ?? 0,
      eventDate:
          _dateTimeFromJson(json['event_date']) ??
          _dateTimeFromJson(json['created_at']) ??
          DateTime.now(),
      createdAt: _dateTimeFromJson(json['created_at']) ?? DateTime.now(),
      role: json['role'] as String? ?? 'participant',
    );
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
