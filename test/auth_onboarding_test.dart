import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_a_man/core/router/route_names.dart';
import 'package:match_a_man/core/utils/error_messages.dart';
import 'package:match_a_man/core/utils/user_handle.dart';
import 'package:match_a_man/features/auth/auth_service.dart';
import 'package:match_a_man/features/events/events_models.dart';
import 'package:match_a_man/features/events/widgets/join_request_button.dart';
import 'package:match_a_man/features/profile/profile_models.dart';
import 'package:match_a_man/features/profile/profile_provider.dart';
import 'package:match_a_man/features/profile/widgets/safe_avatar.dart';

void main() {
  group('OAuth redirects', () {
    test('web callback uses app callback path', () {
      expect(
        AuthService.webOAuthCallbackForOrigin('http://localhost:3000'),
        'http://localhost:3000/auth/callback',
      );
      expect(
        AuthService.oauthRedirectTo(
          isWeb: true,
          baseUri: Uri.parse('http://localhost:3000/events'),
        ),
        'http://localhost:3000/auth/callback',
      );
      expect(RoutePaths.authCallback, '/auth/callback');
      expect(RoutePaths.authCallback.startsWith('/'), isTrue);
      expect(RoutePaths.events.startsWith('/'), isTrue);
      expect(RoutePaths.login.startsWith('/'), isTrue);
      expect(RoutePaths.authCallback.startsWith('http'), isFalse);
      expect(RoutePaths.events.startsWith('http'), isFalse);
      expect(RoutePaths.login.startsWith('http'), isFalse);
      expect(
        RoutePaths.profileCompleteModeEventRequirements,
        'eventRequirements',
      );
    });

    test('mobile callback keeps custom scheme', () {
      expect(
        AuthService.oauthRedirectTo(isWeb: false),
        'matchaman://login-callback/',
      );
    });

    test('returnTo accepts only internal app paths', () {
      expect(RoutePaths.isSafeReturnPath('/events/create'), isTrue);
      expect(RoutePaths.isSafeReturnPath('/events/abc?tab=requests'), isTrue);
      expect(RoutePaths.isSafeReturnPath('events/create'), isFalse);
      expect(
        RoutePaths.isSafeReturnPath('http://localhost:3000/events'),
        isFalse,
      );
      expect(
        RoutePaths.isSafeReturnPath('matchaman://login-callback/'),
        isFalse,
      );
      expect(RoutePaths.isSafeReturnPath('//evil.example/events'), isFalse);
    });
  });

  group('username onboarding', () {
    test('normalizes uppercase usernames before save', () {
      expect(ProfileUsername.normalize(' EmirHan '), 'emirhan');
      expect(ProfileUsername.normalize('EMIR_HAN'), 'emir_han');
      expect(ProfileUsername.normalize('Emir123'), 'emir123');
      expect(ProfileUsername.normalize('I_TEST'), 'i_test');
    });

    test('validates username rules after normalization', () {
      expect(
        ProfileUsername.validate('E'),
        'Kullanıcı adı en az 2 karakter olmalı.',
      );
      expect(
        ProfileUsername.validate('emir han'),
        'Kullanıcı adı sadece harf, rakam ve _ içerebilir.',
      );
      expect(
        ProfileUsername.validate('emir#1932'),
        'Kullanıcı adına # ekleme; etiket otomatik oluşturulur.',
      );
      expect(ProfileUsername.validate('EmirHan'), isNull);
    });

    test('formats profile display handles with tags', () {
      expect(formatUserHandle('emirwithhan', '6385'), 'emirwithhan#6385');
      expect(formatUserHandle('emirwithhan', '0047'), 'emirwithhan#0047');
      expect(formatUserHandle('emirwithhan', null), 'emirwithhan');
      expect(formatUserHandle(null, '6385'), isNull);
      expect(formatUserHandle('selin#1932', '1932'), 'selin#1932');
    });

    test('builds social username seed from email or name', () {
      expect(
        ProfileUsername.socialSeed(
          preferredUsername: 'ProviderUser',
          email: 'EmirHan@gmail.com',
          fullName: 'Ignored Name',
          fallbackId: 'a1b2c3d4',
        ),
        'emirhan',
      );
      expect(
        ProfileUsername.socialSeed(
          fullName: 'Emir Han',
          fallbackId: 'a1b2c3d4',
        ),
        'emir_han',
      );
      expect(
        ProfileUsername.socialSeed(fallbackId: 'a1b2c3d4-0000'),
        'user_a1b2c3',
      );
    });

    test('adds duplicate suffix within username limit', () {
      final value = ProfileUsername.withSuffix('averyverylongusername', '7k3d');

      expect(value, endsWith('_7k3d'));
      expect(value.length, lessThanOrEqualTo(ProfileUsername.maxLength));
    });

    test('profile form only requires username and name for core identity', () {
      const formData = ProfileFormData(
        username: 'EmirHan',
        tag: '1234',
        firstName: 'Emir',
      );

      expect(formData.isComplete, isTrue);
      expect(formData.toUpdateJson()['username'], 'emirhan');
      expect(formData.toUpdateJson().containsKey('last_name'), isFalse);
      expect(formData.toUpdateJson()['tag'], '1234');
      expect(formData.toUpdateJson()['city'], isNull);
      expect(formData.toUpdateJson()['district'], isNull);
      expect(formData.toUpdateJson()['birth_date'], isNull);
    });

    test('profile row can bootstrap without separate id column', () {
      final profile = Profile.fromJson({
        'user_id': 'user-1',
        'username': 'emirhan',
        'first_name': 'Emir',
      });

      expect(profile.id, 'user-1');
      expect(profile.userId, 'user-1');
      expect(profile.hasCoreIdentity, isTrue);
    });

    test('profile form does not require a typed tag', () {
      const formData = ProfileFormData(
        username: 'EmirHan',
        tag: null,
        firstName: 'Emir',
      );

      expect(formData.isComplete, isTrue);
      expect(formData.toUpdateJson().containsKey('tag'), isFalse);
    });

    test('duplicate username errors are friendly', () {
      expect(
        friendlyErrorMessage(
          'PostgrestException duplicate key violates profiles_username_key 23505',
        ),
        'Bu kullanıcı adı alınmış.',
      );
    });
  });

  group('profile access rules', () {
    test(
      'username and name allow general app access but not event actions',
      () {
        const profile = Profile(
          id: 'profile-1',
          userId: 'user-1',
          username: 'emirhan',
          firstName: 'Emir',
        );

        expect(profile.hasCoreIdentity, isTrue);
        expect(profile.hasEventRequiredFields, isFalse);
        final state = ProfileState(
          status: ProfileStatus.success,
          profile: profile,
        );
        expect(state.isProfileCompleted, isTrue);
        expect(state.canCreateEvent, isFalse);
        expect(state.canRequestToJoinEvent, isFalse);
      },
    );

    test('city, district, and birth date allow event actions', () {
      final profile = Profile(
        id: 'profile-1',
        userId: 'user-1',
        username: 'emirhan',
        firstName: 'Emir',
        city: 'İstanbul',
        district: 'Kadıköy',
        birthDate: DateTime(1998),
      );

      expect(profile.hasEventRequiredFields, isTrue);
    });

    test('event readiness reports each missing required field', () {
      final base = Profile(
        id: 'profile-1',
        userId: 'user-1',
        username: 'emirhan',
        firstName: 'Emir',
        city: 'İstanbul',
        district: 'Kadıköy',
        birthDate: DateTime(1998),
        phone: null,
        bio: null,
        avatarUrl: null,
      );

      expect(EventProfileRequirements.hasRequiredFields(base), isTrue);
      expect(
        EventProfileRequirements.missingFields(base.copyWith(city: '')),
        contains('city'),
      );
      expect(
        EventProfileRequirements.missingFields(base.copyWith(district: '')),
        contains('district'),
      );
      expect(
        EventProfileRequirements.missingFields(
          Profile(
            id: base.id,
            userId: base.userId,
            username: base.username,
            firstName: base.firstName,
            city: base.city,
            district: base.district,
          ),
        ),
        contains('birthDate'),
      );
    });

    test('event requirement route is profile completion, not events', () {
      expect(RouteNames.profileComplete, isNot(RouteNames.events));
      expect(RoutePaths.profileComplete, isNot(RoutePaths.events));
      expect(RoutePaths.profileComplete, startsWith('/profile'));
    });
  });

  group('event action precedence', () {
    testWidgets('past event block appears before profile requirement', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JoinRequestButton(
              event: _event(
                eventDate: DateTime.now().subtract(const Duration(days: 1)),
              ),
              profileState: const ProfileState(
                status: ProfileStatus.success,
                profile: Profile(
                  id: 'profile-1',
                  userId: 'user-1',
                  username: 'emirhan',
                  firstName: 'Emir',
                ),
              ),
              request: null,
              isLoading: false,
              onRequest: () {},
              onCancel: () {},
            ),
          ),
        ),
      );

      expect(find.text('Bu etkinlik geçmişte kaldı.'), findsOneWidget);
      expect(
        find.text('Etkinliklere katılmak için profilini tamamlamalısın.'),
        findsNothing,
      );
    });

    testWidgets('full event block appears before profile requirement', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JoinRequestButton(
              event: _event(approvedCount: 12, capacityTotal: 12),
              profileState: const ProfileState(
                status: ProfileStatus.success,
                profile: Profile(
                  id: 'profile-1',
                  userId: 'user-1',
                  username: 'emirhan',
                  firstName: 'Emir',
                ),
              ),
              request: null,
              isLoading: false,
              onRequest: () {},
              onCancel: () {},
            ),
          ),
        ),
      );

      expect(find.text('Bu etkinlik şu anda dolu.'), findsOneWidget);
      expect(
        find.text('Etkinliklere katılmak için profilini tamamlamalısın.'),
        findsNothing,
      );
    });
  });

  group('avatar fallback', () {
    testWidgets('safe avatar shows fallback without a usable URL', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SafeAvatar(radius: 20, fallbackText: 'E')),
        ),
      );

      expect(find.text('E'), findsOneWidget);
    });
  });
}

Event _event({
  DateTime? eventDate,
  int approvedCount = 0,
  int capacityTotal = 12,
}) {
  return Event(
    id: 'event-1',
    hostId: 'host-1',
    title: 'Basketbol',
    sportType: 'Basketbol',
    city: 'İstanbul',
    eventDate: eventDate ?? DateTime.now().add(const Duration(days: 1)),
    capacityTotal: capacityTotal,
    approvedCount: approvedCount,
    status: 'active',
  );
}
