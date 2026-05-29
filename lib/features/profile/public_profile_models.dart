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

  bool get isBusinessAccount => accountType == 'business';

  String get displayName {
    if (isBusinessAccount) {
      final business = businessName?.trim();
      if (business != null && business.isNotEmpty) return business;
    }
    final first = firstName?.trim();
    final usernameValue = username?.trim();

    if (first != null && first.isNotEmpty) {
      return first;
    }

    if (usernameValue != null && usernameValue.isNotEmpty) {
      return usernameValue;
    }

    return 'MaM User';
  }

  String? get usernameTag {
    if (isBusinessAccount) {
      return formatUserHandle(businessUsername, businessTag);
    }
    return formatUserHandle(username, tag);
  }

  String get initials {
    if (isBusinessAccount) {
      final business = businessName?.trim();
      if (business != null && business.isNotEmpty) {
        return business[0].toUpperCase();
      }
    }
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
    return PublicProfilePreview(
      userId: json['user_id'].toString(),
      username: json['username'] as String?,
      tag: json['tag'] as String?,
      firstName: json['first_name'] as String?,
      city: json['city'] as String?,
      avatarUrl:
          json['business_logo_url'] as String? ?? json['avatar_url'] as String?,
      trustScore: (json['trust_score'] as num?)?.toInt(),
      isProfileCompleted: json['is_profile_completed'] as bool? ?? false,
      accountType: json['account_type']?.toString() ?? 'user',
      businessName: json['business_name']?.toString(),
      businessUsername: json['business_username']?.toString(),
      businessTag: json['business_tag']?.toString(),
      businessLogoUrl: json['business_logo_url']?.toString(),
      businessIsVerified: json['business_is_verified'] as bool? ?? false,
    );
  }
}
