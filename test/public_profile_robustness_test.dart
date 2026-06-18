import 'package:flutter_test/flutter_test.dart';
import 'package:match_a_man/features/profile/public_profile_models.dart';
import 'package:match_a_man/features/profile/profile_models.dart';

void main() {
  group('PublicProfilePreview Robustness Tests', () {
    test('handles missing optional fields by using defaults or nulls', () {
      final json = <String, dynamic>{'user_id': 'user-123'};

      final preview = PublicProfilePreview.fromJson(json);

      expect(preview.userId, equals('user-123'));
      expect(preview.username, isNull);
      expect(preview.tag, isNull);
      expect(preview.firstName, isNull);
      expect(preview.city, isNull);
      expect(preview.avatarUrl, isNull);
      expect(preview.trustScore, isNull);
      expect(preview.isProfileCompleted, isFalse);
      expect(preview.accountType, equals('user'));
      expect(preview.businessName, isNull);
      expect(preview.businessUsername, isNull);
      expect(preview.businessTag, isNull);
      expect(preview.businessLogoUrl, isNull);
      expect(preview.businessIsVerified, isFalse);
      expect(preview.businessCustomThemeColor, isNull);
      expect(preview.businessPinnedEventId, isNull);
      expect(preview.businessGalleryUrls, isNull);
      expect(preview.businessIsPlusActive, isFalse);
    });

    test('handles explicit nulls for optional fields', () {
      final json = <String, dynamic>{
        'user_id': 'user-123',
        'username': null,
        'tag': null,
        'first_name': null,
        'city': null,
        'avatar_url': null,
        'trust_score': null,
        'is_profile_completed': null,
        'account_type': null,
        'business_name': null,
        'business_username': null,
        'business_tag': null,
        'business_logo_url': null,
        'business_is_verified': null,
        'business_custom_theme_color': null,
        'business_pinned_event_id': null,
        'business_gallery_urls': null,
        'business_is_plus_active': null,
      };

      final preview = PublicProfilePreview.fromJson(json);

      expect(preview.userId, equals('user-123'));
      expect(preview.username, isNull);
      expect(preview.isProfileCompleted, isFalse);
      expect(preview.accountType, equals('user'));
      expect(preview.businessIsVerified, isFalse);
      expect(preview.businessIsPlusActive, isFalse);
    });

    test('vulnerability: missing or null user_id throws ArgumentError', () {
      final json = <String, dynamic>{};
      expect(
        () => PublicProfilePreview.fromJson(json),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'vulnerability: type mismatches are handled by converting to string',
      () {
        final json = <String, dynamic>{
          'user_id': 'user-123',
          'username': 123, // should be String
        };

        final preview = PublicProfilePreview.fromJson(json);
        expect(preview.username, equals('123'));
      },
    );
  });

  group('PublicProfileDetail Robustness Tests', () {
    test('handles missing optional fields by using defaults or nulls', () {
      final json = <String, dynamic>{'user_id': 'user-456'};

      final detail = PublicProfileDetail.fromJson(json);

      expect(detail.userId, equals('user-456'));
      expect(detail.username, isNull);
      expect(detail.tag, isNull);
      expect(detail.firstName, isNull);
      expect(detail.city, isNull);
      expect(detail.district, isNull);
      expect(detail.avatarUrl, isNull);
      expect(detail.bio, isNull);
      expect(detail.trustScore, isNull);
      expect(detail.isPrivate, isFalse);
      expect(detail.accountType, equals('user'));
      expect(detail.businessAccountId, isNull);
      expect(detail.businessName, isNull);
      expect(detail.businessLogoUrl, isNull);
      expect(detail.businessIsVerified, isFalse);
      expect(detail.followersCount, equals(0));
      expect(detail.followingCount, equals(0));
      expect(detail.isFollowing, isFalse);
      expect(detail.isFollowedBy, isFalse);
      expect(detail.pendingFollowRequestByMe, isFalse);
      expect(detail.canViewExtendedProfile, isFalse);
    });

    test('handles explicit nulls for optional fields', () {
      final json = <String, dynamic>{
        'user_id': 'user-456',
        'username': null,
        'tag': null,
        'first_name': null,
        'city': null,
        'district': null,
        'avatar_url': null,
        'bio': null,
        'trust_score': null,
        'is_private': null,
        'account_type': null,
        'business_account_id': null,
        'business_name': null,
        'business_username': null,
        'business_tag': null,
        'business_category': null,
        'business_custom_category': null,
        'business_city': null,
        'business_district': null,
        'business_description': null,
        'business_logo_url': null,
        'business_cover_url': null,
        'business_is_verified': null,
        'business_custom_theme_color': null,
        'business_pinned_event_id': null,
        'business_gallery_urls': null,
        'business_is_plus_active': null,
        'followers_count': null,
        'following_count': null,
        'is_following': null,
        'is_followed_by': null,
        'pending_follow_request_by_me': null,
        'can_view_extended_profile': null,
      };

      final detail = PublicProfileDetail.fromJson(json);

      expect(detail.userId, equals('user-456'));
      expect(detail.username, isNull);
      expect(detail.isPrivate, isFalse);
      expect(detail.accountType, equals('user'));
      expect(detail.businessIsVerified, isFalse);
      expect(detail.followersCount, equals(0));
      expect(detail.followingCount, equals(0));
      expect(detail.isFollowing, isFalse);
      expect(detail.isFollowedBy, isFalse);
      expect(detail.pendingFollowRequestByMe, isFalse);
      expect(detail.canViewExtendedProfile, isFalse);
    });

    test('vulnerability: missing or null user_id throws ArgumentError', () {
      final json = <String, dynamic>{};
      expect(
        () => PublicProfileDetail.fromJson(json),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'vulnerability: type mismatches are handled by converting to string',
      () {
        final json = <String, dynamic>{
          'user_id': 'user-456',
          'username': 456, // should be String
        };

        final detail = PublicProfileDetail.fromJson(json);
        expect(detail.username, equals('456'));
      },
    );
  });
}
