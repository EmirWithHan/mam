import 'dart:typed_data';

import '../../core/utils/date_formatter.dart';

class Post {
  const Post({
    required this.id,
    required this.userId,
    this.eventId,
    required this.imageUrl,
    this.caption,
    this.commentsHidden = false,
    this.isArchived = false,
    this.eventSportType,
    this.authorUsername,
    this.authorTag,
    this.authorAvatarUrl,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String? eventId;
  final String imageUrl;
  final String? caption;
  final bool commentsHidden;
  final bool isArchived;
  final String? eventSportType;
  final String? authorUsername;
  final String? authorTag;
  final String? authorAvatarUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      eventId: json['event_id']?.toString(),
      imageUrl: json['image_url']?.toString() ?? '',
      caption: json['caption'] as String?,
      commentsHidden: json['comments_hidden'] as bool? ?? false,
      isArchived: json['is_archived'] as bool? ?? false,
      eventSportType: json['event_sport_type'] as String?,
      authorUsername: json['author_username'] as String?,
      authorTag: json['author_tag'] as String?,
      authorAvatarUrl: json['author_avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'].toString()),
      updatedAt: _dateTimeFromJson(json['updated_at']),
    );
  }

  Map<String, dynamic> toCreateJson() {
    final data = <String, dynamic>{
      'user_id': userId,
      'image_url': imageUrl,
      'caption': _nullableTrim(caption),
    };

    final linkedEventId = _nullableTrim(eventId);
    if (linkedEventId != null) {
      data['event_id'] = linkedEventId;
    }

    return data;
  }

  Post copyWith({
    String? id,
    String? userId,
    String? eventId,
    String? imageUrl,
    String? caption,
    bool? commentsHidden,
    bool? isArchived,
    String? eventSportType,
    String? authorUsername,
    String? authorTag,
    String? authorAvatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      eventId: eventId ?? this.eventId,
      imageUrl: imageUrl ?? this.imageUrl,
      caption: caption ?? this.caption,
      commentsHidden: commentsHidden ?? this.commentsHidden,
      isArchived: isArchived ?? this.isArchived,
      eventSportType: eventSportType ?? this.eventSportType,
      authorUsername: authorUsername ?? this.authorUsername,
      authorTag: authorTag ?? this.authorTag,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class CreatePostInput {
  const CreatePostInput({
    required this.imageBytes,
    required this.fileName,
    this.contentType,
    this.caption,
    this.eventId,
  });

  final Uint8List imageBytes;
  final String fileName;
  final String? contentType;
  final String? caption;
  final String? eventId;

  Map<String, dynamic> toInsertJson({
    required String userId,
    required String imageUrl,
  }) {
    final data = <String, dynamic>{
      'user_id': userId,
      'image_url': imageUrl,
      'caption': _nullableTrim(caption),
    };

    final linkedEventId = _nullableTrim(eventId);
    if (linkedEventId != null) {
      data['event_id'] = linkedEventId;
    }

    return data;
  }
}

class LinkableEvent {
  const LinkableEvent({
    required this.id,
    required this.title,
    required this.sportType,
    required this.city,
    this.district,
    required this.eventDate,
    this.role,
    this.status,
  });

  final String id;
  final String title;
  final String sportType;
  final String city;
  final String? district;
  final DateTime eventDate;
  final String? role;
  final String? status;

  String get locationLabel {
    final districtValue = district?.trim();
    if (districtValue == null || districtValue.isEmpty) return city;
    return '$city / $districtValue';
  }

  String get displayDate => DateFormatter.turkishEventDateTime(eventDate);

  String get searchText {
    return _normalizeSearchText(
      [title, sportType, city, district].whereType<String>().join(' '),
    );
  }

  factory LinkableEvent.fromJson(
    Map<String, dynamic> json, {
    String? role,
    String? status,
  }) {
    return LinkableEvent(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      sportType: json['sport_type']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      district: json['district'] as String?,
      eventDate: DateTime.parse(json['event_date'].toString()),
      role: role,
      status: status,
    );
  }
}

class PostComment {
  const PostComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.comment,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String postId;
  final String userId;
  final String comment;
  final DateTime createdAt;
  final DateTime? updatedAt;

  bool isMine(String? currentUserId) {
    return currentUserId != null && userId == currentUserId;
  }

  factory PostComment.fromJson(Map<String, dynamic> json) {
    return PostComment(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      userId: json['user_id'] as String,
      comment: json['comment'] as String,
      createdAt: DateTime.parse(json['created_at'].toString()),
      updatedAt: _dateTimeFromJson(json['updated_at']),
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {'post_id': postId, 'user_id': userId, 'comment': comment.trim()};
  }
}

class PostWithStats {
  const PostWithStats({
    required this.post,
    required this.likeCount,
    required this.commentCount,
    required this.isLikedByMe,
  });

  final Post post;
  final int likeCount;
  final int commentCount;
  final bool isLikedByMe;

  factory PostWithStats.fromFeedJson(Map<String, dynamic> json) {
    return PostWithStats(
      post: Post.fromJson(json),
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
      isLikedByMe: json['is_liked_by_me'] as bool? ?? false,
    );
  }

  PostWithStats copyWith({
    Post? post,
    int? likeCount,
    int? commentCount,
    bool? isLikedByMe,
  }) {
    return PostWithStats(
      post: post ?? this.post,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
    );
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

String _normalizeSearchText(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('ç', 'c')
      .replaceAll('ğ', 'g')
      .replaceAll('ı', 'i')
      .replaceAll('i̇', 'i')
      .replaceAll('ö', 'o')
      .replaceAll('ş', 's')
      .replaceAll('ü', 'u');
}
