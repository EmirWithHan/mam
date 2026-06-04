import '../../core/utils/user_handle.dart';

class UserSearchRules {
  const UserSearchRules._();

  static const minQueryLength = 2;
  static const maxResults = 20;
  static const debounceMilliseconds = 400;

  static bool canSearch(String value) {
    return normalizeQuery(value).length >= minQueryLength;
  }

  static String normalizeQuery(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static ParsedUserSearchQuery parse(String value) {
    final normalized = normalizeQuery(value).toLowerCase();
    final hashIndex = normalized.indexOf('#');
    if (hashIndex <= 0 || hashIndex == normalized.length - 1) {
      return ParsedUserSearchQuery(username: normalized);
    }

    return ParsedUserSearchQuery(
      username: normalized.substring(0, hashIndex),
      tag: normalized.substring(hashIndex + 1),
    );
  }
}

class ParsedUserSearchQuery {
  const ParsedUserSearchQuery({required this.username, this.tag});

  final String username;
  final String? tag;
}

class UserSearchFollowState {
  const UserSearchFollowState._();

  static const none = 'none';
  static const following = 'following';
  static const pending = 'pending';
  static const self = 'self';
}

class UserSearchResult {
  const UserSearchResult({
    required this.userId,
    required this.displayName,
    this.username,
    this.tag,
    this.avatarUrl,
    this.accountType = 'user',
    this.isPrivate = false,
    this.businessCategory,
    this.businessIsVerified = false,
    this.followState = UserSearchFollowState.none,
  });

  final String userId;
  final String displayName;
  final String? username;
  final String? tag;
  final String? avatarUrl;
  final String accountType;
  final bool isPrivate;
  final String? businessCategory;
  final bool businessIsVerified;
  final String followState;

  static const safeFieldKeys = {
    'user_id',
    'display_name',
    'username',
    'tag',
    'avatar_url',
    'account_type',
    'is_private',
    'business_category',
    'business_is_verified',
    'follow_state',
  };

  bool get isSelf => followState == UserSearchFollowState.self;
  bool get isFollowing => followState == UserSearchFollowState.following;
  bool get hasPendingRequest => followState == UserSearchFollowState.pending;
  bool get isBusinessAccount => accountType == 'business';
  bool get canFollow => !isSelf && !isFollowing && !hasPendingRequest;

  String? get handleLabel => formatUserHandle(username, tag);

  String get actionLabel {
    if (isSelf) return 'Sen';
    if (isFollowing) return 'Takip ediliyor';
    if (hasPendingRequest) return 'İstek gönderildi';
    if (isPrivate) return 'İstek gönder';
    return 'Arkadaş ekle';
  }

  String get initials {
    final name = displayName.trim();
    if (name.isNotEmpty) return name[0].toUpperCase();
    final user = username?.trim();
    if (user != null && user.isNotEmpty) return user[0].toUpperCase();
    return 'M';
  }

  UserSearchResult copyWith({String? followState}) {
    return UserSearchResult(
      userId: userId,
      displayName: displayName,
      username: username,
      tag: tag,
      avatarUrl: avatarUrl,
      accountType: accountType,
      isPrivate: isPrivate,
      businessCategory: businessCategory,
      businessIsVerified: businessIsVerified,
      followState: followState ?? this.followState,
    );
  }

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    final username = json['username']?.toString();
    final displayName = json['display_name']?.toString().trim();

    return UserSearchResult(
      userId: json['user_id'].toString(),
      displayName: displayName == null || displayName.isEmpty
          ? username ?? 'MaM User'
          : displayName,
      username: username,
      tag: json['tag']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      accountType: json['account_type']?.toString() ?? 'user',
      isPrivate: json['is_private'] as bool? ?? false,
      businessCategory: json['business_category']?.toString(),
      businessIsVerified: json['business_is_verified'] as bool? ?? false,
      followState:
          json['follow_state']?.toString() ?? UserSearchFollowState.none,
    );
  }
}
