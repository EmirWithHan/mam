import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_a_man/core/router/route_names.dart';
import 'package:match_a_man/core/utils/error_messages.dart';
import 'package:match_a_man/features/auth/auth_service.dart';
import 'package:match_a_man/features/profile/profile_models.dart';
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
      expect(ProfileUsername.validate('EmirHan'), isNull);
    });

    test('builds social username seed from email or name', () {
      expect(
        ProfileUsername.socialSeed(
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
