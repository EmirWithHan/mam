import '../../core/utils/user_handle.dart';

class PublicProfilePreview {
  const PublicProfilePreview({
    required this.userId,
    this.username,
    this.tag,
    this.firstName,
    this.city,
    this.avatarUrl,
    this.trustScore,
    this.isProfileCompleted = false,
    this.accountType = 'user',
    this.businessName,
    this.businessUsername,
    this.businessTag,
    this.businessLogoUrl,
    this.businessIsVerified = false,
    this.businessCustomThemeColor,
    this.businessPinnedEventId,
    this.businessGalleryUrls,
    this.businessIsPlusActive = false,
  });

  final String userId;
  final String? username;
  final String? tag;
  final String? firstName;
  final String? city;
  final String? avatarUrl;
  final int? trustScore;
  final bool isProfileCompleted;
  final String accountType;
  final String? businessName;
  final String? businessUsername;
  final String? businessTag;
  final String? businessLogoUrl;
  final bool businessIsVerified;
  final String? businessCustomThemeColor;
  final String? businessPinnedEventId;
  final List<String>? businessGalleryUrls;
  final bool businessIsPlusActive;

  bool get isBusinessAccount => accountType == 'business';

  String get displayName {
    final first = firstName?.trim();
    final usernameValue = username?.trim();

    if (first != null && first.isNotEmpty) {
      return first;
    }

    if (usernameValue != null && usernameValue.isNotEmpty) {
      return usernameValue;
    }

    return 'Akanzi kullanıcısı';
  }

  String? get usernameTag {
    return formatUserHandle(username, tag);
  }

  String get initials {
    final parts = [
      firstName?.trim(),
    ].where((part) => part != null && part.isNotEmpty).cast<String>().toList();

    if (parts.isNotEmpty) {
      return parts.take(2).map((part) => part[0].toUpperCase()).join();
    }

    final usernameValue = username?.trim();
    if (usernameValue != null && usernameValue.isNotEmpty) {
      return usernameValue[0].toUpperCase();
    }

    return 'M';
  }

  String get trustLabel {
    final score = (trustScore ?? 50).clamp(0, 100).toInt();
    if (score <= 39) return 'Low trust';
    if (score <= 59) return 'New user';
    if (score <= 79) return 'Reliable participant';
    return 'Highly trusted';
  }

  factory PublicProfilePreview.fromJson(Map<String, dynamic> json) {
    final userIdVal = json['user_id'];
    if (userIdVal == null) {
      throw ArgumentError('user_id is required');
    }
    return PublicProfilePreview(
      userId: userIdVal.toString(),
      username: json['username']?.toString(),
      tag: json['tag']?.toString(),
      firstName: json['first_name']?.toString(),
      city: json['city']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      trustScore: (json['trust_score'] as num?)?.toInt(),
      isProfileCompleted: json['is_profile_completed'] as bool? ?? false,
      accountType: json['account_type']?.toString() ?? 'user',
      businessName: json['business_name']?.toString(),
      businessUsername: json['business_username']?.toString(),
      businessTag: json['business_tag']?.toString(),
      businessLogoUrl: json['business_logo_url']?.toString(),
      businessIsVerified: json['business_is_verified'] as bool? ?? false,
      businessCustomThemeColor: json['business_custom_theme_color']?.toString(),
      businessPinnedEventId: json['business_pinned_event_id']?.toString(),
      businessGalleryUrls: json['business_gallery_urls'] is List
          ? (json['business_gallery_urls'] as List)
                .map((e) => e.toString())
                .toList()
          : null,
      businessIsPlusActive: json['business_is_plus_active'] as bool? ?? false,
    );
  }
}
