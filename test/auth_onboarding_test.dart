import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_a_man/core/constants/sport_types.dart';
import 'package:match_a_man/core/router/route_names.dart';
import 'package:match_a_man/core/widgets/event_cover_image.dart';
import 'package:match_a_man/core/widgets/app_logo.dart';
import 'package:match_a_man/core/widgets/main_navigation_shell.dart';
import 'package:match_a_man/core/utils/error_messages.dart';
import 'package:match_a_man/core/utils/pagination.dart';
import 'package:match_a_man/core/utils/phone_verification.dart';
import 'package:match_a_man/core/utils/trust_score_rules.dart';
import 'package:match_a_man/core/utils/user_handle.dart';
import 'package:match_a_man/core/utils/validators.dart';
import 'package:match_a_man/features/auth/auth_service.dart';
import 'package:match_a_man/features/business/business_models.dart';
import 'package:match_a_man/features/business/business_reviews_models.dart';
import 'package:match_a_man/features/business/business_reviews_service.dart';
import 'package:match_a_man/features/business/business_service.dart';
import 'package:match_a_man/features/business/business_stats_models.dart';
import 'package:match_a_man/features/events/events_models.dart';
import 'package:match_a_man/features/events/join_requests_models.dart';
import 'package:match_a_man/features/events/widgets/event_card.dart';
import 'package:match_a_man/features/events/widgets/join_request_button.dart';
import 'package:match_a_man/features/feed/feed_models.dart';
import 'package:match_a_man/features/feed/feed_provider.dart';
import 'package:match_a_man/features/feed/feed_service.dart';
import 'package:match_a_man/features/notifications/notifications_models.dart';
import 'package:match_a_man/features/profile/profile_badges.dart';
import 'package:match_a_man/features/profile/profile_models.dart';
import 'package:match_a_man/features/profile/profile_provider.dart';
import 'package:match_a_man/features/profile/profile_service.dart';
import 'package:match_a_man/features/profile/public_profile_models.dart';
import 'package:match_a_man/features/profile/widgets/safe_avatar.dart';
import 'package:match_a_man/services/maps_service.dart';
import 'package:match_a_man/services/storage_service.dart';

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

    test('event route constants remain available', () {
      expect(RouteNames.events, 'events');
      expect(RoutePaths.events, '/events');
      expect(RouteNames.usernameOnboarding, 'usernameOnboarding');
      expect(RoutePaths.usernameOnboarding, '/onboarding/username');
      expect(RouteNames.eventDetail, 'eventDetail');
      expect(RoutePaths.eventDetail, '/events/:eventId');
      expect(RouteNames.createEvent, 'createEvent');
      expect(RoutePaths.createEvent, '/events/create');
    });

    testWidgets('main navigation keeps Etkinlikler tab visible', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MainNavigationShell(currentIndex: 1, child: SizedBox.shrink()),
        ),
      );

      expect(find.text('Etkinlikler'), findsOneWidget);
      expect(find.byIcon(Icons.event), findsOneWidget);
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

    test('profile form only requires username for minimum profile', () {
      const formData = ProfileFormData(
        username: 'EmirHan',
        tag: '1234',
        firstName: '',
      );

      expect(formData.isComplete, isTrue);
      expect(formData.toUpdateJson()['username'], 'emirhan');
      expect(formData.toUpdateJson()['first_name'], 'emirhan');
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
      expect(profile.hasMinimumProfile, isTrue);
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

    test('phone normalization supports Turkey formats', () {
      expect(normalizeTurkishPhoneNumber('05551234567'), '+905551234567');
      expect(normalizeTurkishPhoneNumber('5551234567'), '+905551234567');
      expect(normalizeTurkishPhoneNumber('+905551234567'), '+905551234567');
      expect(
        normalizeTurkishPhoneNumber('0090 (555) 123-45-67'),
        '+905551234567',
      );
      expect(PhoneVerification.normalize('0532 123 45 67'), '+905321234567');
      expect(PhoneVerification.validateOptional('0555 123 45 67'), isNull);
      expect(PhoneVerification.validateOptional('+905551234567'), isNull);
      expect(normalizeTurkishPhoneNumber('123123'), isNull);
      expect(normalizeTurkishPhoneNumber('123123123'), isNull);
      expect(normalizeTurkishPhoneNumber('0000000000'), isNull);
      expect(normalizeTurkishPhoneNumber('1111111111'), isNull);
      expect(normalizeTurkishPhoneNumber('905551234567'), isNull);
      expect(
        PhoneVerification.validateOptional('123123123'),
        'Geçerli bir telefon numarası gir.',
      );
    });

    test('duplicate phone errors are friendly', () {
      expect(
        friendlyErrorMessage(
          'PostgrestException duplicate key profiles_phone_number_unique 23505',
        ),
        'Bu telefon numarası başka bir hesapta kullanılıyor.',
      );
      expect(
        PhoneVerification.friendlyDuplicateError(
          'duplicate key profiles_phone_number_unique',
        ),
        'Bu telefon numarası başka bir hesapta kullanılıyor.',
      );
    });

    test('phone verified helper requires a real phone number', () {
      const defaultProfile = Profile(id: 'profile-1', userId: 'user-1');
      const fakeVerified = Profile(
        id: 'profile-1',
        userId: 'user-1',
        phoneVerified: true,
      );
      const verified = Profile(
        id: 'profile-1',
        userId: 'user-1',
        phoneNumber: '+905321234567',
        phoneVerified: true,
      );

      expect(defaultProfile.phoneVerified, isFalse);
      expect(PhoneVerification.isPhoneVerified(defaultProfile), isFalse);
      expect(PhoneVerification.isPhoneVerified(fakeVerified), isFalse);
      expect(PhoneVerification.isPhoneVerified(verified), isTrue);
      expect(
        PhoneVerification.canRequirePhoneForBusinessFlow(verified),
        isTrue,
      );
      expect(PhoneVerification.canMarkVerifiedWithoutOtp(), isFalse);
      expect(
        PhoneVerification.verificationComingSoonMessage,
        'Telefon doğrulama yakında eklenecek.',
      );
    });

    test('duplicate username errors are friendly', () {
      final message = friendlyErrorMessage(
        'PostgrestException duplicate key violates profiles_username_key 23505',
      );

      expect(message, isNot(contains('PostgrestException')));
      expect(message, contains('kullan'));
      expect(
        friendlyErrorMessage(
          const ProfileSaveException('Bu kullanıcı adı zaten alınmış.'),
        ),
        'Bu kullanıcı adı zaten alınmış.',
      );
    });

    test('username save path is own-profile scoped and narrow', () {
      final service = File(
        'lib/features/profile/profile_service.dart',
      ).readAsStringSync();
      final start = service.indexOf('Future<Profile> updateMyUsername');
      final end = service.indexOf(
        'Future<Profile> updateMyProfilePrivacy',
        start,
      );
      final method = service.substring(start, end);

      expect(method, contains('_currentUserId()'));
      expect(method, contains('_usernameTakenByAnotherUser'));
      expect(method, contains('_upsertMyProfileRow(payload, userId)'));
      expect(method, contains("'first_name': normalizedUsername"));
      expect(method, contains("'is_profile_completed': true"));
      expect(method, isNot(contains('account_status')));
      expect(method, isNot(contains('account_type')));
      expect(method, isNot(contains('business_account_id')));
      expect(method, isNot(contains('is_admin')));
      expect(method, isNot(contains('service_role')));
    });

    test('business event approve RPC errors stay user-facing', () {
      final notOwned = friendlyErrorMessage(
        'PostgrestException business_event_not_owned',
      );

      expect(notOwned, isNot(contains('PostgrestException')));
      expect(notOwned, contains('yetkin'));
      final notPending = friendlyErrorMessage(
        'PostgrestException join_request_not_pending',
      );
      final notFound = friendlyErrorMessage(
        'PostgrestException join_request_not_found',
      );

      expect(notPending, isNot(contains('PostgrestException')));
      expect(notPending, contains('zaten'));
      expect(notFound, isNot(contains('PostgrestException')));
      expect(notFound, contains('bulunamad'));
    });
  });

  group('profile access rules', () {
    test('profile primary stats show follow follower and event labels', () {
      final source = File(
        'lib/features/profile/profile_page.dart',
      ).readAsStringSync();
      final statsStart = source.indexOf('class _OwnProfileStats');
      final statsEnd = source.indexOf('class _ProfileEmptyState', statsStart);
      final statsSource = source.substring(statsStart, statsEnd);

      expect(statsSource, contains('ProfileStatsBox('));
      expect(statsSource, contains("label: 'Takip'"));
      expect(statsSource, contains("label: 'Takipçi'"));
      expect(statsSource, contains("label: 'Etkinlik'"));
      expect(statsSource, contains('value: followingCount'));
      expect(statsSource, contains('value: followersCount'));
      expect(statsSource, contains('value: eventCount'));
      expect(statsSource, contains("RouteNames.profileFollowList"));
      expect(statsSource, contains("'type': 'following'"));
      expect(statsSource, contains("'type': 'followers'"));
    });

    test('username alone allows app access but not join requests', () {
      const profile = Profile(
        id: 'profile-1',
        userId: 'user-1',
        username: 'emirhan',
      );

      expect(profile.hasMinimumProfile, isTrue);
      expect(profile.hasCoreIdentity, isFalse);
      expect(profile.hasEventRequiredFields, isFalse);
      final state = ProfileState(
        status: ProfileStatus.success,
        profile: profile,
      );
      expect(state.isProfileCompleted, isTrue);
      expect(state.canCreateEvent, isFalse);
      expect(state.canRequestToJoinEvent, isFalse);
    });

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
      final state = ProfileState(
        status: ProfileStatus.success,
        profile: profile,
      );
      expect(state.canRequestToJoinEvent, isTrue);
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

    test('full profile edit remains optional and separate from onboarding', () {
      expect(RouteNames.usernameOnboarding, isNot(RouteNames.profileComplete));
      expect(RoutePaths.usernameOnboarding, isNot(RoutePaths.profileComplete));
      expect(RouteNames.profileComplete, isNot(RouteNames.events));
      expect(RoutePaths.profileComplete, isNot(RoutePaths.events));
      expect(RoutePaths.profileComplete, startsWith('/profile'));
    });
  });

  group('event action precedence', () {
    testWidgets('incomplete profile cannot trigger join request action', (
      tester,
    ) async {
      var requested = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JoinRequestButton(
              event: _event(),
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
              onRequest: () => requested = true,
              onCancel: () {},
            ),
          ),
        ),
      );

      expect(find.text('Profilini tamamla'), findsOneWidget);
      expect(
        find.text(
          'Etkinliklere katılım isteği göndermeden önce profil bilgilerini tamamlamalısın.',
        ),
        findsOneWidget,
      );
      expect(find.text('Profili tamamla'), findsOneWidget);
      expect(find.text('Katılım isteği gönder'), findsNothing);
      expect(requested, isFalse);
    });

    testWidgets('event-ready profile can still trigger join request action', (
      tester,
    ) async {
      var requested = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JoinRequestButton(
              event: _event(),
              profileState: ProfileState(
                status: ProfileStatus.success,
                profile: Profile(
                  id: 'profile-1',
                  userId: 'user-1',
                  username: 'emirhan',
                  firstName: 'Emir',
                  city: 'İstanbul',
                  district: 'Kadıköy',
                  birthDate: DateTime(1998),
                ),
              ),
              request: null,
              isLoading: false,
              onRequest: () => requested = true,
              onCancel: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Katılım isteği gönder'));

      expect(requested, isTrue);
    });

    test(
      'public participant visibility excludes pending/rejected/left users',
      () {
        expect(
          EventPublicParticipantVisibility.canShow(
            role: 'host',
            attendanceStatus: 'planned',
          ),
          isTrue,
        );
        expect(
          EventPublicParticipantVisibility.canShow(
            role: 'participant',
            attendanceStatus: 'planned',
          ),
          isTrue,
        );
        expect(
          EventPublicParticipantVisibility.canShow(
            role: 'participant',
            attendanceStatus: 'attended',
          ),
          isTrue,
        );
        expect(
          EventPublicParticipantVisibility.canShow(
            role: 'participant',
            attendanceStatus: 'pending',
          ),
          isFalse,
        );
        expect(
          EventPublicParticipantVisibility.canShow(
            role: 'participant',
            attendanceStatus: 'rejected',
          ),
          isFalse,
        );
        expect(
          EventPublicParticipantVisibility.canShow(
            role: 'participant',
            attendanceStatus: 'left',
          ),
          isFalse,
        );
      },
    );

    test('business confirmation lifecycle helpers map final states', () {
      expect(
        EventParticipationStatus.countsAsFinalParticipant(
          isBusinessEvent: true,
          status: EventParticipationStatus.pendingConfirmation,
        ),
        isFalse,
      );
      expect(
        EventParticipationStatus.countsAsFinalParticipant(
          isBusinessEvent: true,
          status: EventParticipationStatus.confirmed,
        ),
        isTrue,
      );
      expect(
        EventParticipationStatus.countsAsFinalParticipant(
          isBusinessEvent: true,
          status: EventParticipationStatus.checkedIn,
        ),
        isTrue,
      );
      expect(
        EventParticipationStatus.countsAsFinalParticipant(
          isBusinessEvent: true,
          status: EventParticipationStatus.noShow,
        ),
        isFalse,
      );
      expect(
        EventParticipationStatus.countsAsFinalParticipant(
          isBusinessEvent: true,
          status: EventParticipationStatus.waitlisted,
        ),
        isFalse,
      );
      expect(
        EventParticipationStatus.countsAsFinalParticipant(
          isBusinessEvent: false,
          status: EventParticipationStatus.planned,
        ),
        isTrue,
      );
    });

    test(
      'join request final participant helper keeps normal flow unchanged',
      () {
        final normalApproved = EventJoinRequest(
          id: 'request-1',
          eventId: 'event-1',
          userId: 'user-1',
          status: EventParticipationStatus.approved,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
        final businessPendingConfirmation = EventJoinRequest(
          id: 'request-2',
          eventId: 'event-1',
          userId: 'user-1',
          status: EventParticipationStatus.pendingConfirmation,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
        final businessConfirmed = EventJoinRequest(
          id: 'request-3',
          eventId: 'event-1',
          userId: 'user-1',
          status: EventParticipationStatus.confirmed,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );

        expect(
          normalApproved.isFinalParticipant(isBusinessEvent: false),
          isTrue,
        );
        expect(
          businessPendingConfirmation.isFinalParticipant(isBusinessEvent: true),
          isFalse,
        );
        expect(
          businessConfirmed.isFinalParticipant(isBusinessEvent: true),
          isTrue,
        );
      },
    );

    test('waitlisted participant does not count as confirmed', () {
      const participation = EventParticipation(
        role: 'participant',
        attendanceStatus: EventParticipationStatus.waitlisted,
      );

      expect(
        participation.countsAsFinalParticipant(isBusinessEvent: true),
        isFalse,
      );
    });

    test('business check-in only accepts confirmed business participants', () {
      final businessEvent = _event(organizerType: EventOrganizerType.business);
      final normalEvent = _event();

      expect(businessEvent.canOpenBusinessCheckIn('host-1'), isTrue);
      expect(businessEvent.canOpenBusinessCheckIn('user-1'), isFalse);
      expect(normalEvent.canOpenBusinessCheckIn('host-1'), isFalse);
      expect(
        EventParticipationStatus.canMarkBusinessAttendance(
          isBusinessEvent: true,
          status: EventParticipationStatus.confirmed,
        ),
        isTrue,
      );
      expect(
        EventParticipationStatus.canMarkBusinessAttendance(
          isBusinessEvent: false,
          status: EventParticipationStatus.confirmed,
        ),
        isFalse,
      );
      expect(
        EventParticipationStatus.canMarkBusinessAttendance(
          isBusinessEvent: true,
          status: EventParticipationStatus.waitlisted,
        ),
        isFalse,
      );
      expect(
        EventParticipationStatus.canMarkBusinessAttendance(
          isBusinessEvent: true,
          status: EventParticipationStatus.pendingConfirmation,
        ),
        isFalse,
      );
    });

    test('business attendance labels are calm and explicit', () {
      expect(
        EventParticipationStatus.businessAttendanceLabel(
          EventParticipationStatus.confirmed,
        ),
        'Bekliyor',
      );
      expect(
        EventParticipationStatus.businessAttendanceLabel(
          EventParticipationStatus.checkedIn,
        ),
        'Geldi',
      );
      expect(
        EventParticipationStatus.businessAttendanceLabel(
          EventParticipationStatus.noShow,
        ),
        'Gelmedi',
      );
    });

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

  group('notifications', () {
    test('notification type mapping is user-facing', () {
      final notification = AppNotification(
        id: 'notification-1',
        recipientId: 'user-1',
        type: 'follow_request',
        title: 'follow_request',
        entityId: 'request-1',
        entityType: 'profile',
        isRead: false,
        createdAt: DateTime(2026),
      );

      expect(notification.displayTitle, 'Takip isteği');
      expect(notification.displayBody, 'Yeni bir takip isteğin var.');
      expect(notification.typeLabel, 'Sosyal');
      expect(notification.canRespondToFollowRequest, isTrue);
    });

    test('business event confirmation notification opens event', () {
      final notification = AppNotification(
        id: 'notification-1',
        recipientId: 'user-1',
        type: 'business_event_confirm_required',
        title: '',
        entityType: 'event',
        entityId: 'event-1',
        isRead: false,
        createdAt: DateTime(2026),
      );

      expect(notification.displayTitle, 'Katılımını doğrula');
      expect(notification.isBusinessEventConfirmRequired, isTrue);
      expect(notification.opensEvent, isTrue);
    });

    test('approve RPC inserts notification entity id as uuid', () {
      final migration = File(
        'supabase/migrations/20260529114500_fix_approve_notification_entity_id_uuid.sql',
      ).readAsStringSync();

      expect(migration, contains('entity_id'));
      expect(migration, contains("'event',\n        v_event.id,"));
      expect(migration, isNot(contains("'event',\n        v_event.id::text,")));
      expect(migration, contains("'event_id', v_event.id::text"));
    });
  });

  group('feed polish helpers', () {
    test('sport label mapper returns Turkish labels', () {
      expect(sportLabelFor('football'), 'Futbol');
      expect(sportLabelFor('basketbol'), 'Basketbol');
      expect(sportLabelFor('voleybol'), 'Voleybol');
      expect(sportLabelFor('running'), 'Koşu');
      expect(sportLabelFor('bisiklet'), 'Bisiklet');
      expect(sportLabelFor('tennis'), 'Tenis');
      expect(sportLabelFor('hiking'), 'Outdoor');
    });

    test('event cover mapper returns fallback for unknown sport', () {
      final cover = eventCoverStyleForSport('pickleball');

      expect(cover.label, 'Spor');
      expect(cover.icon, Icons.sports_handball);
    });

    test('sport and cover mappers handle null safely', () {
      expect(sportLabelFor(null), 'Spor');
      expect(sportIconFor(null), Icons.sports_handball);

      final cover = eventCoverStyleForSport(null);
      expect(cover.label, 'Spor');
      expect(cover.icon, Icons.sports_handball);
    });

    testWidgets('event cover renders fallback for null sport', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: EventCoverImage(sportType: null)),
        ),
      );

      expect(find.byType(EventCoverImage), findsOneWidget);
      expect(find.text('Spor'), findsOneWidget);
    });

    test('event model tolerates null or unknown sport type', () {
      final event = Event.fromJson({
        'id': 'event-1',
        'host_id': 'host-1',
        'title': 'Friendly Match',
        'sport_type': null,
        'city': 'Istanbul',
        'event_date': '2026-05-28T10:00:00Z',
        'capacity_total': 12,
        'status': 'active',
      });

      expect(event.sportType, isNull);
      expect(sportLabelFor(event.sportType), 'Spor');
      expect(eventCoverStyleForSport(event.sportType).label, 'Spor');
    });

    test('event organizer type falls back to user', () {
      final event = Event.fromJson({
        'id': 'event-1',
        'host_id': 'host-1',
        'title': 'Friendly Match',
        'sport_type': 'Futbol',
        'city': 'Istanbul',
        'event_date': '2026-05-28T10:00:00Z',
        'capacity_total': 12,
        'status': 'active',
      });

      expect(event.organizerType, EventOrganizerType.user);
      expect(event.isBusinessEvent, isFalse);
      expect(event.priceLabel, '');
    });

    test('business event maps organizer and paid price display', () {
      final event = Event.fromJson({
        'id': 'event-1',
        'host_id': 'host-1',
        'title': 'Padel Night',
        'sport_type': 'Padel',
        'city': 'Istanbul',
        'event_date': '2026-05-28T10:00:00Z',
        'capacity_total': 12,
        'status': 'active',
        'organizer_type': 'business',
        'organizer_business_id': 'business-1',
        'is_paid': true,
        'price_amount': 450,
        'price_currency': 'TRY',
        'business_accounts': {
          'id': 'business-1',
          'name': 'Padel Club',
          'username': 'padelclub',
          'business_tag': '1234',
          'is_verified': true,
        },
      });

      expect(event.isBusinessEvent, isTrue);
      expect(event.businessOrganizer?.displayName, 'Padel Club');
      expect(event.businessOrganizer?.isVerified, isTrue);
      expect(event.priceLabel, '₺450 (İşletmede)');
    });

    test('free business event displays Ucretsiz', () {
      final event = Event.fromJson({
        'id': 'event-1',
        'host_id': 'host-1',
        'title': 'Open Day',
        'sport_type': 'Yoga',
        'city': 'Istanbul',
        'event_date': '2026-05-28T10:00:00Z',
        'capacity_total': 12,
        'status': 'active',
        'organizer_type': 'business',
        'organizer_business_id': 'business-1',
        'is_paid': false,
      });

      expect(event.isBusinessEvent, isTrue);
      expect(event.priceLabel, 'Ücretsiz');
    });

    test('business event create payload requires account helper', () {
      expect(CreateEventInput.canSelectBusinessEvent(null), isFalse);

      const account = BusinessAccount(
        id: 'business-1',
        ownerUserId: 'user-1',
        name: 'Padel Club',
        username: 'padelclub',
        category: 'Padel Kortu',
        city: 'Istanbul',
        district: 'Kadikoy',
      );
      expect(CreateEventInput.canSelectBusinessEvent(account), isFalse);

      final input = CreateEventInput(
        title: 'Padel Night',
        sportType: 'Padel',
        city: 'Istanbul',
        district: 'Kadikoy',
        locationText: 'Kadikoy Padel Club, Kort 2',
        locationLat: 40.9901,
        locationLng: 29.028,
        eventDate: DateTime(2026, 5, 28),
        capacityTotal: 12,
        capacityMale: 0,
        capacityFemale: 0,
        capacityAny: 12,
        organizerType: EventOrganizerType.business,
        businessAccount: account,
        isPaid: true,
        priceAmount: 450,
      );
      final payload = input.toCreateJson(hostId: 'user-1');

      expect(payload['organizer_type'], EventOrganizerType.business);
      expect(payload['organizer_user_id'], 'user-1');
      expect(payload['organizer_business_id'], 'business-1');
      expect(payload['is_paid'], isTrue);
      expect(payload['price_amount'], 450);
      expect(payload['price_currency'], 'TRY');
      expect(payload['city'], 'Istanbul');
      expect(payload['district'], 'Kadikoy');
      expect(payload['location_text'], 'Kadikoy Padel Club, Kort 2');
      expect(payload['location_lat'], 40.9901);
      expect(payload['location_lng'], 29.028);
      expect(payload['capacity_total'], 12);
      expect(payload['generic_capacity'], 12);
      expect(payload['male_capacity'], 0);
      expect(payload['female_capacity'], 0);
      expect(input.hasEventLocationInfo, isTrue);
      expect(payload.containsKey('is_sponsored'), isFalse);
      expect(payload.containsKey('sponsored_until'), isFalse);
      expect(payload.containsKey('sponsored_priority'), isFalse);
      expect(payload.containsKey('is_verified'), isFalse);
    });

    test(
      'normal generic capacity create payload keeps gender buckets zero',
      () {
        final input = CreateEventInput(
          title: 'Ankara mac',
          sportType: 'Futbol',
          city: 'Ankara',
          district: 'Mamak',
          locationText: 'Can spor tesisleri',
          eventDate: DateTime(2026, 6, 13, 15, 9),
          capacityTotal: 3,
          capacityMale: 0,
          capacityFemale: 0,
          capacityAny: 3,
        );

        final payload = input.toCreateJson(hostId: 'user-1');
        final legacyPayload = input.toLegacyCreateJson(hostId: 'user-1');

        expect(payload['capacity_total'], 3);
        expect(payload['generic_capacity'], 3);
        expect(payload['male_capacity'], 0);
        expect(payload['female_capacity'], 0);
        expect(payload['organizer_type'], EventOrganizerType.user);
        expect(legacyPayload['capacity_total'], 3);
        expect(legacyPayload.containsKey('generic_capacity'), isFalse);
        expect(legacyPayload.containsKey('male_capacity'), isFalse);
        expect(legacyPayload.containsKey('female_capacity'), isFalse);
      },
    );

    test('business account creates business event by default', () {
      const account = BusinessAccount(
        id: 'business-1',
        ownerUserId: 'user-1',
        name: 'Padel Club',
        username: 'padelclub',
        category: 'Padel Kortu',
        city: 'Istanbul',
        district: 'Kadikoy',
      );

      expect(
        CreateEventInput.defaultOrganizerType(
          isBusinessAccount: true,
          businessAccount: account,
        ),
        EventOrganizerType.business,
      );
    });

    test('user account creates normal event', () {
      expect(
        CreateEventInput.defaultOrganizerType(
          isBusinessAccount: false,
          businessAccount: null,
        ),
        EventOrganizerType.user,
      );
    });

    test('user mode cannot create paid business event from stale account', () {
      const account = BusinessAccount(
        id: 'business-1',
        ownerUserId: 'user-1',
        name: 'Padel Club',
        username: 'padelclub',
        category: 'Padel Kortu',
        city: 'Istanbul',
        district: 'Kadikoy',
      );

      expect(
        CreateEventInput.canUseBusinessEventFields(
          isBusinessAccount: false,
          businessAccount: account,
        ),
        isFalse,
      );

      final input = CreateEventInput(
        title: 'Normal Padel',
        sportType: 'Padel',
        city: 'Istanbul',
        locationText: 'Moda Sahil buluşma noktası',
        eventDate: DateTime(2026, 5, 28),
        capacityTotal: 12,
        capacityMale: 0,
        capacityFemale: 0,
        capacityAny: 12,
        organizerType: EventOrganizerType.user,
        businessAccount: account,
        isPaid: true,
        priceAmount: 450,
      );
      final payload = input.toCreateJson(hostId: 'user-1');

      expect(payload['organizer_type'], EventOrganizerType.user);
      expect(payload.containsKey('organizer_business_id'), isFalse);
      expect(payload['is_paid'], isFalse);
      expect(payload.containsKey('price_amount'), isFalse);
      expect(payload.containsKey('price_currency'), isFalse);
    });

    test('event location validation requires event-specific address text', () {
      expect(Validators.eventLocation(''), 'Etkinlik konumunu yazmalısın.');
      expect(
        Validators.eventLocation('  A  '),
        'Etkinlik konumunu yazmalısın.',
      );
      expect(Validators.eventLocation('Kadıköy Padel Club Kort 2'), isNull);

      final input = CreateEventInput(
        title: 'Adres eksik',
        sportType: 'Padel',
        city: 'Istanbul',
        eventDate: DateTime(2026, 5, 28),
        capacityTotal: 12,
        capacityMale: 0,
        capacityFemale: 0,
        capacityAny: 12,
      );

      expect(input.hasEventLocationInfo, isFalse);
      expect(
        friendlyErrorMessage(StateError('Etkinlik konumunu yazmalısın.')),
        'Etkinlik konumunu yazmalısın.',
      );
    });

    test('event capacity model falls back old total to generic capacity', () {
      final oldEvent = Event(
        id: 'event-1',
        hostId: 'host-1',
        title: 'Legacy match',
        city: 'Ankara',
        eventDate: DateTime(2026, 7, 24),
        capacityTotal: 10,
        approvedCount: 3,
        status: 'active',
      );

      expect(oldEvent.genericCapacity, 10);
      expect(oldEvent.maleCapacity, 0);
      expect(oldEvent.femaleCapacity, 0);
      expect(oldEvent.safeCapacityTotal, 10);
      expect(oldEvent.isFull, isFalse);
      expect(oldEvent.formattedCapacityLabel, '3 / 10 kişi onaylandı');
      expect(
        oldEvent.capacityBreakdownLabel,
        'Karışık: 10, Erkek: 0, Kadın: 0',
      );

      final missingCapacityEvent = Event(
        id: 'event-2',
        hostId: 'host-1',
        title: 'Missing capacity',
        city: 'Ankara',
        eventDate: DateTime(2026, 7, 24),
        capacityTotal: 0,
        status: 'active',
      );
      expect(missingCapacityEvent.safeCapacityTotal, 0);
      expect(missingCapacityEvent.isFull, isFalse);
      expect(
        missingCapacityEvent.formattedCapacityLabel,
        '0 / 0 kişi onaylandı',
      );
    });

    test('capacity schema errors are not shown as event full', () {
      final message = friendlyErrorMessage(
        'PostgrestException column events.generic_capacity does not exist',
      );

      expect(message, isNot('Bu etkinlik şu anda dolu.'));
    });

    test('create form and event list state are kept separate', () {
      final createSource = File(
        'lib/features/events/create_event_page.dart',
      ).readAsStringSync();
      final providerSource = File(
        'lib/features/events/events_provider.dart',
      ).readAsStringSync();

      expect(createSource, contains('capacityTotal < 1'));
      expect(createSource, contains('En az bir kontenjan'));
      expect(createSource, isNot(contains('dolu')));
      expect(createSource, contains('eventsState.isMutating'));
      expect(createSource, contains('eventsState.mutationMessage'));
      expect(providerSource, contains('mutationMessage'));
      expect(providerSource, contains('isMutating'));
    });

    test('gender-aware capacity rules choose eligible buckets', () {
      expect(
        EventCapacityRules.bucketFor(
          gender: 'Erkek',
          genericRemaining: 4,
          maleRemaining: 2,
          femaleRemaining: 2,
        ),
        EventCapacityBucket.male,
      );
      expect(
        EventCapacityRules.bucketFor(
          gender: 'Erkek',
          genericRemaining: 4,
          maleRemaining: 0,
          femaleRemaining: 2,
        ),
        EventCapacityBucket.generic,
      );
      expect(
        EventCapacityRules.bucketFor(
          gender: 'Kadın',
          genericRemaining: 4,
          maleRemaining: 2,
          femaleRemaining: 1,
        ),
        EventCapacityBucket.female,
      );
      expect(
        EventCapacityRules.bucketFor(
          gender: 'Belirtmek istemiyorum',
          genericRemaining: 1,
          maleRemaining: 2,
          femaleRemaining: 2,
        ),
        EventCapacityBucket.generic,
      );
      expect(
        EventCapacityRules.bucketFor(
          gender: null,
          genericRemaining: 0,
          maleRemaining: 2,
          femaleRemaining: 2,
        ),
        isNull,
      );
    });

    test('event map candidates prefer generic map schemes', () {
      const service = MapsService();

      final coordinateUrls = service.eventLocationCandidates(
        latitude: 41.015,
        longitude: 29.02,
        label: 'Kadıköy Padel Club',
      );
      expect(coordinateUrls.first.scheme, 'geo');
      expect(coordinateUrls.map((uri) => uri.host), contains('maps.apple.com'));
      expect(
        coordinateUrls.map((uri) => uri.host),
        contains('www.openstreetmap.org'),
      );

      final addressUrls = service.eventLocationCandidates(
        locationText: 'Kadıköy Padel Club Kort 2',
      );
      expect(addressUrls.first.scheme, 'geo');
      expect(addressUrls.first.query, contains('Kad%C4%B1k%C3%B6y'));
      expect(
        addressUrls.map((uri) => uri.host),
        isNot(contains('www.google.com')),
      );

      final contextualQuery = service.contextualSearchQuery(
        locationText: 'Can Spor Tesisleri',
        district: 'Çankaya',
        city: 'Ankara',
      );
      expect(contextualQuery, 'Can Spor Tesisleri, Çankaya, Ankara, Türkiye');

      final duplicateSafeQuery = service.contextualSearchQuery(
        locationText: 'Can Spor Tesisleri, Çankaya, Ankara',
        district: 'Çankaya',
        city: 'Ankara',
      );
      expect(
        duplicateSafeQuery,
        'Can Spor Tesisleri, Çankaya, Ankara, Türkiye',
      );
    });

    test('sponsored business event is inserted after 4 normal events', () {
      final now = DateTime(2026, 5, 28);
      final normalEvents = List.generate(
        5,
        (index) => _event(
          id: 'normal-$index',
          eventDate: now.add(Duration(days: index + 1)),
        ),
      );
      final sponsored = _event(
        id: 'sponsored-1',
        organizerType: EventOrganizerType.business,
        businessIsVerified: true,
        businessIsPlusActive: true,
        isSponsored: true,
        sponsoredUntil: now.add(const Duration(days: 7)),
        sponsoredPriority: 10,
        eventDate: now.add(const Duration(days: 2)),
      );

      final placed = eventsWithSponsoredPlacement([
        ...normalEvents,
        sponsored,
      ], now: now);

      expect(placed.map((event) => event.id), [
        'normal-0',
        'normal-1',
        'normal-2',
        'normal-3',
        'sponsored-1',
        'normal-4',
      ]);
    });

    test('sponsored placement avoids duplicate sponsored events', () {
      final now = DateTime(2026, 5, 28);
      final normalEvents = List.generate(
        4,
        (index) => _event(id: 'normal-$index'),
      );
      final sponsored = _event(
        id: 'sponsored-1',
        organizerType: EventOrganizerType.business,
        businessIsVerified: true,
        businessIsPlusActive: true,
        isSponsored: true,
        sponsoredUntil: now.add(const Duration(days: 7)),
      );

      final placed = eventsWithSponsoredPlacement([
        sponsored,
        ...normalEvents,
      ], now: now);

      expect(placed.where((event) => event.id == 'sponsored-1'), hasLength(1));
    });

    test('sponsored-only list does not create placement', () {
      final now = DateTime(2026, 5, 28);
      final sponsored = _event(
        id: 'sponsored-1',
        organizerType: EventOrganizerType.business,
        businessIsVerified: true,
        businessIsPlusActive: true,
        isSponsored: true,
        sponsoredUntil: now.add(const Duration(days: 7)),
      );

      expect(eventsWithSponsoredPlacement([sponsored], now: now), isEmpty);
    });

    test('expired sponsored event is ignored for sponsored placement', () {
      final now = DateTime(2026, 5, 28);
      final normalEvents = List.generate(
        4,
        (index) => _event(id: 'normal-$index'),
      );
      final expired = _event(
        id: 'expired-sponsored',
        organizerType: EventOrganizerType.business,
        businessIsVerified: true,
        businessIsPlusActive: true,
        isSponsored: true,
        sponsoredUntil: now.subtract(const Duration(days: 1)),
      );
      final active = _event(
        id: 'active-sponsored',
        organizerType: EventOrganizerType.business,
        businessIsVerified: true,
        businessIsPlusActive: true,
        isSponsored: true,
        sponsoredUntil: now.add(const Duration(days: 1)),
      );

      final placed = eventsWithSponsoredPlacement([
        ...normalEvents,
        expired,
        active,
      ], now: now);

      expect(placed[4].id, 'active-sponsored');
      expect(placed[5].id, 'expired-sponsored');
    });

    test('unverified sponsored flag does not show sponsor placement', () {
      final now = DateTime(2026, 5, 28);
      final normalEvents = List.generate(
        4,
        (index) => _event(id: 'normal-$index'),
      );
      final unverifiedSponsored = _event(
        id: 'unverified-sponsored',
        organizerType: EventOrganizerType.business,
        businessIsVerified: false,
        isSponsored: true,
        sponsoredUntil: now.add(const Duration(days: 1)),
      );

      final placed = eventsWithSponsoredPlacement([
        ...normalEvents,
        unverifiedSponsored,
      ], now: now);

      expect(placed.map((event) => event.id), [
        'normal-0',
        'normal-1',
        'normal-2',
        'normal-3',
        'unverified-sponsored',
      ]);
      expect(unverifiedSponsored.isActiveSponsoredPlacement(now), isFalse);
    });

    test('sponsored placement ignores deleted business after delete', () {
      final now = DateTime(2026, 5, 28);
      final normalEvents = List.generate(
        4,
        (index) => _event(id: 'normal-$index'),
      );
      final deletedSponsored = _event(
        id: 'deleted-sponsored',
        organizerType: EventOrganizerType.business,
        businessIsVerified: true,
        businessStatus: BusinessAccountStatus.deleted,
        isSponsored: true,
        sponsoredUntil: now.add(const Duration(days: 1)),
      );

      final placed = eventsWithSponsoredPlacement([
        ...normalEvents,
        deletedSponsored,
      ], now: now);

      expect(placed.map((event) => event.id), [
        'normal-0',
        'normal-1',
        'normal-2',
        'normal-3',
        'deleted-sponsored',
      ]);
      expect(deletedSponsored.isActiveSponsoredPlacement(now), isFalse);
      expect(deletedSponsored.isVisibleInEventsList(), isFalse);
    });

    test('normal event list remains unchanged without sponsored events', () {
      final normalEvents = List.generate(
        3,
        (index) => _event(id: 'normal-$index'),
      );

      final placed = eventsWithSponsoredPlacement(normalEvents);

      expect(placed.map((event) => event.id), [
        'normal-0',
        'normal-1',
        'normal-2',
      ]);
    });

    testWidgets('event card renders fallback sport and compact button', (
      tester,
    ) async {
      final futureDate = DateTime.now().add(const Duration(days: 30));
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                child: EventCard(
                  event: Event(
                    id: 'event-1',
                    hostId: '',
                    title: '',
                    sportType: null,
                    city: '',
                    eventDate: futureDate,
                    capacityTotal: 0,
                    status: 'active',
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Etkinlik'), findsOneWidget);
      expect(find.text('Spor'), findsOneWidget);
      expect(find.text('Konum belirtilmedi'), findsOneWidget);
      expect(find.text('Katıl'), findsOneWidget);
    });

    testWidgets('sponsor chip only appears for verified sponsored business', (
      tester,
    ) async {
      final future = DateTime.now().add(const Duration(days: 2));
      final sponsoredUntil = DateTime.now().add(const Duration(days: 7));
      final verifiedSponsored = _event(
        id: 'business-verified-sponsored',
        organizerType: EventOrganizerType.business,
        businessIsVerified: true,
        businessIsPlusActive: true,
        isSponsored: true,
        sponsoredUntil: sponsoredUntil,
        eventDate: future,
      );

      expect(
        verifiedSponsored.isActiveSponsoredPlacement(DateTime.now()),
        isTrue,
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    EventCard(
                      event: _event(
                        id: 'business-normal',
                        organizerType: EventOrganizerType.business,
                        businessIsVerified: true,
                        businessIsPlusActive: true,
                        isSponsored: false,
                        eventDate: future,
                      ),
                    ),
                    EventCard(
                      event: _event(
                        id: 'business-unverified-sponsored',
                        organizerType: EventOrganizerType.business,
                        businessIsVerified: false,
                        businessIsPlusActive: true,
                        isSponsored: true,
                        sponsoredUntil: sponsoredUntil,
                        eventDate: future,
                      ),
                    ),
                    EventCard(event: verifiedSponsored),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Öne Çıkarıldı'), findsOneWidget);
      expect(find.text('İşletme'), findsOneWidget);
      expect(find.text('Doğrulanmış İşletme'), findsNWidgets(2));
    });

    test('linkable event model tolerates null sport type', () {
      final event = LinkableEvent.fromJson({
        'id': 'event-1',
        'title': 'Post Match',
        'sport_type': null,
        'city': 'Istanbul',
        'event_date': '2026-05-28T10:00:00Z',
      });

      expect(event.sportType, '');
      expect(sportLabelFor(event.sportType), 'Spor');
    });

    test('feed state tracks per-post like loading', () {
      const state = FeedState(
        status: FeedStatus.success,
        likeLoadingPostIds: {'post-1'},
      );

      expect(state.isLikeLoading('post-1'), isTrue);
      expect(state.isLikeLoading('post-2'), isFalse);
    });

    test('feed post stats mapping tolerates missing media fields', () {
      final item = PostWithStats.fromFeedJson({
        'id': 'post-1',
        'user_id': 'user-1',
        'image_url': null,
        'caption': 'Match day',
        'author_username': 'emirwithhan',
        'author_tag': '6385',
        'author_avatar_url': null,
        'created_at': '2026-05-27T10:00:00Z',
        'like_count': 2,
        'comment_count': 1,
        'is_liked_by_me': true,
      });

      expect(item.post.imageUrl, '');
      expect(
        formatUserHandle(item.post.authorUsername, item.post.authorTag),
        'emirwithhan#6385',
      );
      expect(item.post.authorAvatarUrl, isNull);
      expect(item.likeCount, 2);
      expect(item.commentCount, 1);
      expect(item.isLikedByMe, isTrue);
    });

    test('feed post model handles null event sport type', () {
      final item = PostWithStats.fromFeedJson({
        'id': 'post-1',
        'user_id': 'user-1',
        'event_id': 'event-1',
        'event_sport_type': null,
        'image_url': 'https://example.com/match.jpg',
        'created_at': '2026-05-27T10:00:00Z',
      });

      expect(item.post.eventId, 'event-1');
      expect(item.post.eventSportType, isNull);
    });

    test('feed post model maps event sport type when present', () {
      final item = PostWithStats.fromFeedJson({
        'id': 'post-1',
        'user_id': 'user-1',
        'event_id': 'event-1',
        'event_sport_type': 'Futbol',
        'image_url': 'https://example.com/match.jpg',
        'created_at': '2026-05-27T10:00:00Z',
      });

      expect(item.post.eventSportType, 'Futbol');
      expect(sportLabelFor(item.post.eventSportType), 'Futbol');
    });

    test('empty successful feed state is not an error', () {
      const state = FeedState(status: FeedStatus.success);

      expect(state.posts, isEmpty);
      expect(state.isEmptySuccess, isTrue);
      expect(state.status, isNot(FeedStatus.error));
    });

    test('create post payload omits null event link', () {
      final input = CreatePostInput(
        imageBytes: Uint8List(1),
        fileName: 'match.jpg',
        caption: '  Great match  ',
      );

      final payload = input.toInsertJson(
        userId: 'user-1',
        imageUrl: 'https://example.com/match.jpg',
      );

      expect(payload['caption'], 'Great match');
      expect(payload.containsKey('event_id'), isFalse);
    });

    test('post image storage path is scoped to authenticated user folder', () {
      final path = StorageService.postImagePath(
        userId: 'user-1',
        fileName: 'maç günü!.jpg',
        now: DateTime.fromMillisecondsSinceEpoch(12345),
      );

      expect(path, 'user-1/12345_ma__g_n__.jpg');
      expect(StorageService.safeStorageFileName(''), 'photo.jpg');
      expect(
        StorageService.imageContentTypeFor(fileName: 'match.PNG'),
        'image/png',
      );
      expect(
        StorageService.imageContentTypeFor(
          fileName: 'match.jpg',
          contentType: 'application/octet-stream',
        ),
        'image/jpeg',
      );
    });

    test('post image storage migration keeps writes owner scoped', () {
      final migration = File(
        'supabase/migrations/20260612110000_post_images_storage_bucket.sql',
      ).readAsStringSync();

      expect(migration, contains("'post-images'"));
      expect(migration, contains('to authenticated'));
      expect(migration, contains('for insert'));
      expect(migration, contains('auth.uid()::text'));
      expect(migration, contains('storage.foldername(name)'));
      expect(migration, isNot(contains('for insert\nto public')));
    });

    test('feed and create post errors use focused Turkish copy', () {
      expect(
        friendlyFeedLoadErrorMessage('PostgrestException policy 42501'),
        'Ak\u0131\u015f y\u00fcklenemedi.',
      );
      expect(
        friendlyFeedLoadErrorMessage('PGRST202 schema cache missing function'),
        'Ak\u0131\u015f y\u00fcklenemedi.',
      );
      expect(
        friendlyCreatePostErrorMessage('Storage bucket not found'),
        'Foto\u011fraf y\u00fcklenemedi. Tekrar dene.',
      );
      expect(
        friendlyCreatePostErrorMessage('PostgrestException insert failed'),
        'Payla\u015f\u0131m olu\u015fturulamad\u0131. Tekrar dene.',
      );
      expect(
        friendlyFeedRefreshErrorMessage('PGRST202 schema cache'),
        'Ak\u0131\u015f yenilenemedi. Tekrar dene.',
      );
    });

    test('post creation success survives feed refresh failure', () async {
      final controller = FeedController(
        const _CreateSucceedsRefreshFailsFeedService(),
      );

      final post = await controller.createPost(
        CreatePostInput(imageBytes: Uint8List(1), fileName: 'match.jpg'),
      );

      expect(post?.id, 'post-1');
      expect(controller.state.isCreating, isFalse);
      expect(
        controller.state.message,
        'Ak\u0131\u015f yenilenemedi. Tekrar dene.',
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

      expect(find.byType(AppLogo), findsOneWidget);
    });
  });

  group('profile badge helpers', () {
    test('badge display helper handles empty badges', () {
      expect(ProfileBadgeCatalog.preview(const []), isEmpty);
    });

    test('badge display helper limits preview count to earned badges', () {
      final badges = List.generate(
        7,
        (index) => ProfileBadge(
          id: 'badge-$index',
          label: 'Badge $index',
          description: 'Description',
          icon: Icons.star_outline,
          status: ProfileBadgeStatus.earned,
        ),
      );

      expect(
        ProfileBadgeCatalog.preview(badges),
        hasLength(ProfileBadgeCatalog.previewLimit),
      );
    });

    test('duplicate badge award is idempotent by badge id', () {
      final earnedBadgeIds = <String>{};

      expect(earnedBadgeIds.add('first_event'), isTrue);
      expect(earnedBadgeIds.add('first_event'), isFalse);
      expect(earnedBadgeIds, hasLength(1));
    });

    test('locked badges are not shown in preview as earned', () {
      final badges = ProfileBadgeCatalog.fallbackCatalog();

      expect(ProfileBadgeCatalog.preview(badges), isEmpty);
      expect(
        badges.any((badge) => badge.status == ProfileBadgeStatus.locked),
        isTrue,
      );
    });

    test('locked and earned badge mapping uses earned_at', () {
      final locked = ProfileBadge.fromJson({
        'id': 'first_event',
        'title': 'İlk Etkinlik',
        'description': 'İlk etkinliğine katıldı.',
        'icon_key': 'event',
        'sort_order': 20,
        'earned_at': null,
      });
      final earned = ProfileBadge.fromJson({
        'id': 'first_event',
        'title': 'İlk Etkinlik',
        'description': 'İlk etkinliğine katıldı.',
        'icon_key': 'event',
        'sort_order': 20,
        'earned_at': '2026-05-28T10:00:00Z',
      });

      expect(locked.status, ProfileBadgeStatus.locked);
      expect(earned.status, ProfileBadgeStatus.earned);
      expect(earned.earnedAt, isNotNull);
    });

    test('profile with no badges does not crash preview', () {
      final badges = ProfileBadgeCatalog.withUpcoming(const []);

      expect(ProfileBadgeCatalog.preview(badges), isEmpty);
      expect(
        badges.every((badge) => badge.status != ProfileBadgeStatus.earned),
        isTrue,
      );
    });
  });

  group('trust score rules', () {
    test('trust score clamps min and max', () {
      expect(TrustScoreRules.clamp(-10), TrustScoreRules.minScore);
      expect(TrustScoreRules.clamp(140), TrustScoreRules.maxScore);
      expect(TrustScoreRules.applyDelta(99, 5), 100);
      expect(TrustScoreRules.applyDelta(1, -5), 0);
    });

    test('trust score delta mapping is conservative', () {
      expect(TrustScoreRules.deltaFor('profile_event_ready'), 2);
      expect(TrustScoreRules.deltaFor('first_event_approved'), 3);
      expect(TrustScoreRules.deltaFor('event_join_approved'), 1);
      expect(TrustScoreRules.deltaFor('event_linked_post'), 1);
      expect(TrustScoreRules.deltaFor('business_event_checked_in'), 1);
      expect(TrustScoreRules.deltaFor('approved_event_left'), -2);
      expect(TrustScoreRules.deltaFor('business_event_no_show'), -5);
    });

    test('trust score display handles null safely', () {
      const profile = Profile(id: 'profile-1', userId: 'user-1');

      expect(profile.trustScore, isNull);
      expect(profile.trustScoreValue, TrustScoreRules.neutralScore);
    });

    test('host rejection does not reduce trust score', () {
      expect(TrustScoreRules.deltaFor('event_join_rejected'), 0);
    });

    test('event-ready profile bonus rule is idempotent by source', () {
      final logs = <String>{};
      final first = logs.add('user-1:profile_event_ready:profile:user-1');
      final second = logs.add('user-1:profile_event_ready:profile:user-1');

      expect(first, isTrue);
      expect(second, isFalse);
    });

    test(
      'business check-in and no-show trust events are idempotent by event',
      () {
        final logs = <String>{};
        final checkedInFirst = logs.add(
          'user-1:business_event_checked_in:event:event-1',
        );
        final checkedInSecond = logs.add(
          'user-1:business_event_checked_in:event:event-1',
        );
        final noShowFirst = logs.add(
          'user-1:business_event_no_show:event:event-2',
        );
        final noShowSecond = logs.add(
          'user-1:business_event_no_show:event:event-2',
        );

        expect(checkedInFirst, isTrue);
        expect(checkedInSecond, isFalse);
        expect(noShowFirst, isTrue);
        expect(noShowSecond, isFalse);
      },
    );
  });

  group('business account helpers', () {
    test('business username normalization is lowercase and safe', () {
      expect(
        BusinessAccountValidators.normalizeUsername(' Bozkir At Ciftligi '),
        'bozkir_at_ciftligi',
      );
      expect(BusinessAccountValidators.username('bozkir_01'), isNull);
      expect(BusinessAccountValidators.username('bozkir-01'), isNotNull);
    });

    test('business handle uses existing username tag formatting', () {
      const account = BusinessAccount(
        id: 'business-1',
        ownerUserId: 'user-1',
        name: 'Bozkir At Ciftligi',
        username: 'bozkiratciftligi',
        businessTag: '1234',
        category: 'At Çiftliği',
        city: 'Ankara',
        district: 'Cankaya',
      );

      expect(account.displayHandle, 'bozkiratciftligi#1234');
    });

    test('business required field validation is friendly', () {
      expect(BusinessAccountValidators.name(''), 'İşletme adı gerekli.');
      expect(BusinessAccountValidators.category(null), 'Kategori seçmelisin.');
      expect(
        BusinessApplicationValidators.manualCategory(''),
        'İşletme kategorisini yazmalısın.',
      );
      expect(
        BusinessApplicationValidators.manualCategory('At Çiftliği'),
        isNull,
      );
      expect(
        BusinessAccountValidators.cityDistrict(city: 'Ankara', district: ''),
        'Şehir ve ilçe seçmelisin.',
      );
      expect(BusinessAccountValidators.website('matchaman.app'), isNull);
      expect(BusinessAccountValidators.instagram('@bozkir.club'), isNull);
    });

    test('business category list includes expanded options', () {
      expect(BusinessCategories.values, contains('At Çiftliği'));
      expect(BusinessCategories.values, contains('Halı Saha'));
      expect(BusinessCategories.values, contains('Padel Kortu'));
      expect(BusinessCategories.values, contains('Diğer'));
      expect(BusinessCategories.values, contains('E-Spor / Gaming Alanı'));
    });

    test('custom category is required only for Diger', () {
      expect(
        BusinessAccountValidators.customCategory(
          category: BusinessCategories.other,
          value: '',
        ),
        'İşletme türünü yazmalısın.',
      );
      expect(
        BusinessAccountValidators.customCategory(
          category: BusinessCategories.other,
          value: 'A',
        ),
        'İşletme türü en az 2 karakter olmalı.',
      );
      expect(
        BusinessAccountValidators.customCategory(
          category: BusinessCategories.other,
          value: List.filled(41, 'x').join(),
        ),
        'İşletme türü en fazla 40 karakter olabilir.',
      );
      expect(
        BusinessAccountValidators.customCategory(
          category: BusinessCategories.other,
          value: 'Okçuluk Kulübü',
        ),
        isNull,
      );
      expect(
        BusinessAccountValidators.customCategory(
          category: 'Halı Saha',
          value: '',
        ),
        isNull,
      );
    });

    test('business display category prefers custom Diger value', () {
      const custom = BusinessAccount(
        id: 'business-1',
        ownerUserId: 'user-1',
        name: 'Kano Merkezi',
        username: 'kano',
        category: BusinessCategories.other,
        customCategory: 'Kano Merkezi',
        city: 'Antalya',
        district: 'Konyaalti',
      );
      const normal = BusinessAccount(
        id: 'business-2',
        ownerUserId: 'user-1',
        name: 'Padel Club',
        username: 'padel',
        category: 'Padel Kortu',
        city: 'Istanbul',
        district: 'Kadikoy',
      );

      expect(custom.displayCategory, 'Kano Merkezi');
      expect(normal.displayCategory, 'Padel Kortu');
      expect(
        BusinessAccountValidators.normalizeCustomCategory(
          '  Okçuluk   Kulübü  ',
        ),
        'Okçuluk Kulübü',
      );
    });

    test('business creation payload is owner-scoped and not verified', () {
      const input = BusinessAccountInput(
        name: 'Bozkir At Ciftligi',
        username: ' Bozkir At Ciftligi ',
        category: 'At Çiftliği',
        city: 'Ankara',
        district: 'Cankaya',
      );

      final payload = input.toCreateJson(ownerUserId: 'user-1');

      expect(payload['owner_user_id'], 'user-1');
      expect(payload['username'], 'bozkir_at_ciftligi');
      expect(payload.containsKey('custom_category'), isFalse);
      expect(payload.containsKey('is_verified'), isFalse);
      expect(payload.containsKey('status'), isFalse);
    });

    test('business update payload cannot set is_verified', () {
      const input = BusinessAccountInput(
        name: 'Bozkir At Ciftligi',
        username: 'bozkir_at_ciftligi',
        category: 'At Çiftliği',
        city: 'Ankara',
        district: 'Cankaya',
      );

      final payload = input.toUpdateJson();

      expect(payload.containsKey('is_verified'), isFalse);
      expect(payload.containsKey('status'), isFalse);
    });

    test(
      'business creation payload includes custom Diger category only then',
      () {
        const input = BusinessAccountInput(
          name: 'Kano Merkezi',
          username: 'kano_merkezi',
          category: BusinessCategories.other,
          customCategory: '  Kano   Merkezi  ',
          city: 'Antalya',
          district: 'Konyaalti',
        );

        final payload = input.toCreateJson(ownerUserId: 'user-1');

        expect(payload['category'], BusinessCategories.other);
        expect(payload['custom_category'], 'Kano Merkezi');
      },
    );

    test('business permission error maps to friendly message', () {
      final message = friendlyBusinessAccountErrorMessage(
        'PostgrestException code: 42501 message: permission denied for table business_accounts',
      );

      expect(
        message,
        'İşletme hesabı oluşturulamadı. Yetki ayarları kontrol edilmeli.',
      );
    });

    test('business settings action copy changes with account state', () {
      expect(
        BusinessSettingsCopy.actionTitle(isBusinessAccount: false),
        'İşletme hesabı başvurusu yap',
      );

      const account = BusinessAccount(
        id: 'business-1',
        ownerUserId: 'user-1',
        name: 'Bozkir At Ciftligi',
        username: 'bozkiratciftligi',
        businessTag: '1234',
        category: 'At Çiftliği',
        city: 'Ankara',
        district: 'Cankaya',
      );
      const pending = BusinessApplication(
        id: 'application-1',
        userId: 'user-1',
        businessName: 'Bozkir At Ciftligi',
        businessPhone: '+903123211212',
        fullAddress: 'Ankara Cankaya tam adres',
      );

      expect(
        BusinessSettingsCopy.actionTitle(isBusinessAccount: true),
        'İşletme hesabını düzenle',
      );
      expect(
        BusinessSettingsCopy.actionTitle(
          isBusinessAccount: false,
          application: pending,
        ),
        'İşletme başvurun inceleniyor.',
      );
      expect(
        BusinessSettingsCopy.actionSubtitle(
          isBusinessAccount: true,
          account: account,
        ),
        'Bozkir At Ciftligi · At Çiftliği',
      );
    });

    test('business application validates phone examples', () {
      for (final phone in [
        '03123211212',
        '3123211212',
        '05555555252',
        '5555555252',
        '+903123211212',
        '+905555555252',
      ]) {
        expect(BusinessApplicationValidators.phone(phone), isNull);
      }

      expect(
        BusinessApplicationValidators.phone('123123123'),
        'Geçerli bir işletme telefon numarası gir.',
      );
    });

    test('user can submit business application payload', () {
      const input = BusinessApplicationInput(
        businessName: 'Golbasi At Ciftligi',
        businessPhone: '03123211212',
        fullAddress: 'Ankara Golbasi tam konum adres',
        category: 'At Ã‡iftliÄŸi',
        website: 'https://example.com',
        description: 'At binme etkinlikleri.',
      );

      final payload = input.toCreateJson(userId: 'user-1');

      expect(payload['user_id'], 'user-1');
      expect(payload['business_name'], 'Golbasi At Ciftligi');
      expect(payload['business_phone'], '+903123211212');
      expect(payload['full_address'], 'Ankara Golbasi tam konum adres');
      expect(payload['category'], 'At Ã‡iftliÄŸi');
      expect(payload['custom_category'], isNull);
    });

    test('Diger application category requires custom category', () {
      expect(
        BusinessApplicationValidators.customCategory(
          category: BusinessCategories.other,
          value: null,
        ),
        isNotNull,
      );
    });

    test('old application category fallback does not violate constraint', () {
      final resolved = BusinessApplicationApprovalCategory.resolve(
        businessName: 'Golbasi At Ciftligi',
      );

      expect(resolved['category'], BusinessCategories.other);
      expect(resolved['custom_category'], 'Golbasi At Ciftligi');
    });

    test('application with category approves without custom fallback', () {
      final resolved = BusinessApplicationApprovalCategory.resolve(
        businessName: 'Golbasi At Ciftligi',
        category: 'At Ã‡iftliÄŸi',
      );

      expect(resolved['category'], 'At Ã‡iftliÄŸi');
      expect(resolved['custom_category'], isNull);
    });

    test('approve double click is blocked while review is loading', () {
      const application = BusinessApplication(
        id: 'application-1',
        userId: 'user-1',
        businessName: 'Golbasi At Ciftligi',
        businessPhone: '+903123211212',
        fullAddress: 'Ankara Golbasi tam konum adres',
      );

      expect(
        BusinessApplicationReviewRules.canReview(
          application: application,
          isLoading: true,
        ),
        isFalse,
      );
    });

    test('approved application cannot be approved twice', () {
      const application = BusinessApplication(
        id: 'application-1',
        userId: 'user-1',
        businessName: 'Golbasi At Ciftligi',
        businessPhone: '+903123211212',
        fullAddress: 'Ankara Golbasi tam konum adres',
        status: BusinessApplicationStatus.approved,
      );

      expect(
        BusinessApplicationReviewRules.canReview(
          application: application,
          isLoading: false,
        ),
        isFalse,
      );
    });

    test('business application permission error maps to friendly text', () {
      final message = friendlyBusinessApplicationErrorMessage(
        'PostgrestException code: 42501 message: permission denied for table business_applications',
      );

      expect(
        message,
        'Başvuru gönderilemedi. Yetki ayarları kontrol edilmeli.',
      );
    });

    test('business application approval errors stay friendly', () {
      expect(
        friendlyBusinessApplicationReviewErrorMessage(
          'PostgrestException business_accounts_other_custom_category_check',
        ),
        'Başvuru onaylanamadı. Tekrar dene.',
      );
    });

    test('duplicate pending application maps to friendly text', () {
      final message = friendlyBusinessApplicationErrorMessage(
        'PostgrestException code: 23505 details: business_applications_one_pending_per_user',
      );

      expect(message, 'Bekleyen bir işletme başvurun var.');
    });

    test('pending application blocks duplicate application helper', () {
      const application = BusinessApplication(
        id: 'application-1',
        userId: 'user-1',
        businessName: 'Golbasi At Ciftligi',
        businessPhone: '+903123211212',
        fullAddress: 'Ankara Golbasi tam konum adres',
      );

      expect(application.isPending, isTrue);
      expect(
        BusinessSettingsCopy.actionTitle(
          isBusinessAccount: false,
          application: application,
        ),
        'İşletme başvurun inceleniyor.',
      );
    });

    test('admin approval rules are explicit in route constants', () {
      expect(RouteNames.admin, 'admin');
      expect(RoutePaths.admin, '/admin');
    });

    test('non-admin cannot approve applications', () {
      const message = 'PostgrestException not_admin';

      expect(message.contains('not_admin'), isTrue);
    });

    test('admin approve converts same profile to business', () {
      const profile = Profile(
        id: 'profile-1',
        userId: 'user-1',
        username: 'emir',
        firstName: 'Emir',
        accountType: ProfileAccountType.user,
      );
      const application = BusinessApplication(
        id: 'application-1',
        userId: 'user-1',
        businessName: 'Golbasi At Ciftligi',
        businessPhone: '+903123211212',
        fullAddress: 'Ankara Golbasi tam konum adres',
        description: 'At binme etkinlikleri.',
        status: BusinessApplicationStatus.approved,
      );

      final approved = profile.copyWith(
        accountType: ProfileAccountType.business,
        firstName: application.businessName,
        username: 'golbasi_at_ciftligi',
        bio: application.description,
      );

      expect(approved.id, profile.id);
      expect(approved.userId, profile.userId);
      expect(approved.accountType, ProfileAccountType.business);
      expect(approved.firstName, 'Golbasi At Ciftligi');
    });

    test('reject keeps profile as user', () {
      const profile = Profile(
        id: 'profile-1',
        userId: 'user-1',
        username: 'emir',
        firstName: 'Emir',
        accountType: ProfileAccountType.user,
      );
      const rejected = BusinessApplication(
        id: 'application-1',
        userId: 'user-1',
        businessName: 'Golbasi At Ciftligi',
        businessPhone: '+903123211212',
        fullAddress: 'Ankara Golbasi tam konum adres',
        status: BusinessApplicationStatus.rejected,
      );

      expect(rejected.status, BusinessApplicationStatus.rejected);
      expect(profile.accountType, ProfileAccountType.user);
      expect(profile.firstName, 'Emir');
    });

    test('business badge label maps verified state', () {
      expect(BusinessBadgeLabels.forVerified(false), 'İşletme');
      expect(BusinessBadgeLabels.forVerified(true), 'Doğrulanmış İşletme');
    });

    test('business mode has one canonical public identity', () {
      const account = BusinessAccount(
        id: 'business-1',
        ownerUserId: 'user-1',
        name: 'Bozkir At Ciftligi',
        username: 'bozkiratciftligi',
        businessTag: '1234',
        category: 'At Ãƒâ€¡iftliÃ„Å¸i',
        city: 'Ankara',
        district: 'Cankaya',
      );

      expect(BusinessIdentityRules.canonicalProfileUserId(account), 'user-1');
      expect(BusinessIdentityRules.isSeparatelyFollowable(account), isFalse);
    });

    test('business public route resolves to owner profile route', () {
      const account = BusinessAccount(
        id: 'business-1',
        ownerUserId: 'user-1',
        name: 'Bozkir At Ciftligi',
        username: 'bozkiratciftligi',
        category: 'At Ãƒâ€¡iftliÃ„Å¸i',
        city: 'Ankara',
        district: 'Cankaya',
      );

      expect(RouteNames.businessProfile, 'businessProfile');
      expect(RouteNames.publicProfile, 'publicProfile');
      expect(
        BusinessIdentityRules.canonicalProfileUserId(account),
        account.ownerUserId,
      );
    });

    test('user cannot follow own business identity', () {
      const account = BusinessAccount(
        id: 'business-1',
        ownerUserId: 'user-1',
        name: 'Bozkir At Ciftligi',
        username: 'bozkiratciftligi',
        category: 'At Ãƒâ€¡iftliÃ„Å¸i',
        city: 'Ankara',
        district: 'Cankaya',
      );

      expect(
        BusinessIdentityRules.canFollowBusinessIdentity(
          currentUserId: 'user-1',
          account: account,
        ),
        isFalse,
      );
      expect(
        BusinessIdentityRules.canFollowBusinessIdentity(
          currentUserId: 'user-2',
          account: account,
        ),
        isFalse,
      );
    });

    test('converting to business twice reuses existing account', () {
      const existing = BusinessAccount(
        id: 'business-1',
        ownerUserId: 'user-1',
        name: 'Bozkir At Ciftligi',
        username: 'bozkiratciftligi',
        category: 'At Ãƒâ€¡iftliÃ„Å¸i',
        city: 'Ankara',
        district: 'Cankaya',
      );
      const suspended = BusinessAccount(
        id: 'business-2',
        ownerUserId: 'user-1',
        name: 'Old Business',
        username: 'old_business',
        category: 'Kafe',
        city: 'Ankara',
        district: 'Cankaya',
        status: BusinessAccountStatus.suspended,
      );

      expect(
        BusinessIdentityRules.shouldReuseExistingAccount(existing),
        isTrue,
      );
      expect(
        BusinessIdentityRules.shouldReuseExistingAccount(suspended),
        isFalse,
      );
      expect(BusinessIdentityRules.shouldReuseExistingAccount(null), isFalse);
    });

    test('business edit does not create duplicate business account', () {
      const existing = BusinessAccount(
        id: 'business-1',
        ownerUserId: 'user-1',
        name: 'Golbasi At Ciftligi',
        username: 'golbasi_at_ciftligi',
        category: 'At Çiftliği',
        city: 'Ankara',
        district: 'Cankaya',
      );
      const input = BusinessAccountInput(
        name: 'Golbasi At Ciftligi Updated',
        username: 'golbasi_at_ciftligi',
        category: 'At Çiftliği',
        city: 'Ankara',
        district: 'Gölbaşı',
      );

      expect(
        BusinessIdentityRules.shouldReuseExistingAccount(existing),
        isTrue,
      );
      expect(input.toUpdateJson().containsKey('owner_user_id'), isFalse);
      expect(input.toUpdateJson().containsKey('is_verified'), isFalse);
    });

    test('host card links to canonical owner profile', () {
      final event = Event(
        id: 'event-1',
        title: 'At Binme',
        description: 'Hafta sonu bulusmasi',
        sportType: 'At Binme',
        city: 'Ankara',
        eventDate: DateTime(2026, 6, 1),
        capacityTotal: 12,
        status: 'active',
        hostId: 'user-1',
        organizerType: EventOrganizerType.business,
        organizerUserId: 'user-1',
        organizerBusinessId: 'business-1',
      );

      expect(event.isBusinessEvent, isTrue);
      expect(event.hostId, 'user-1');
      expect(event.organizerBusinessId, isNot(event.hostId));
      expect(RouteNames.publicProfile, 'publicProfile');
    });

    test('business account is not separately followable', () {
      const account = BusinessAccount(
        id: 'business-1',
        ownerUserId: 'user-1',
        name: 'Bozkir At Ciftligi',
        username: 'bozkiratciftligi',
        category: 'At Ãƒâ€¡iftliÃ„Å¸i',
        city: 'Ankara',
        district: 'Cankaya',
      );

      expect(BusinessIdentityRules.isSeparatelyFollowable(account), isFalse);
    });

    test('business account public profile uses profile identity only', () {
      final preview = PublicProfilePreview.fromJson({
        'user_id': 'user-1',
        'username': 'golbasi_at_ciftligi',
        'tag': '0001',
        'first_name': 'Golbasi At Ciftligi',
        'account_type': ProfileAccountType.business,
        'business_name': 'Ignored Business Row',
        'business_username': 'ignored_business',
        'business_tag': '1234',
        'business_is_verified': false,
      });

      expect(preview.displayName, 'Golbasi At Ciftligi');
      expect(preview.usernameTag, 'golbasi_at_ciftligi#0001');
      expect(preview.isBusinessAccount, isTrue);
    });

    test('business mode old posts and events keep same profile owner', () {
      final post = Post.fromJson({
        'id': 'post-1',
        'user_id': 'user-1',
        'image_url': 'https://example.com/post.jpg',
        'author_username': 'golbasi_at_ciftligi',
        'author_tag': '3031',
        'created_at': DateTime(2026, 5, 28).toIso8601String(),
      });
      final event = Event(
        id: 'event-1',
        title: 'At Binme',
        sportType: 'At Binme',
        city: 'Ankara',
        eventDate: DateTime(2026, 6, 1),
        capacityTotal: 12,
        status: 'active',
        hostId: 'user-1',
        organizerType: EventOrganizerType.business,
        organizerUserId: 'user-1',
        organizerBusinessId: 'business-1',
      );

      expect(post.userId, 'user-1');
      expect(post.authorUsername, 'golbasi_at_ciftligi');
      expect(post.authorTag, '3031');
      expect(event.hostId, 'user-1');
      expect(
        event.isVisibleInPublicProfileForAccountType(
          ProfileAccountType.business,
        ),
        isTrue,
      );
    });

    test('user mode public profile keeps personal identity', () {
      final preview = PublicProfilePreview.fromJson({
        'user_id': 'user-1',
        'username': 'selin',
        'tag': '0002',
        'first_name': 'Selin',
        'account_type': ProfileAccountType.user,
        'business_name': 'Selin Studio',
        'business_username': 'selinstudio',
        'business_tag': '1111',
      });

      expect(preview.displayName, 'Selin');
      expect(preview.usernameTag, 'selin#0002');
      expect(preview.isBusinessAccount, isFalse);
    });

    test('switching back hides future business events from user profile', () {
      final futureBusinessEvent = Event(
        id: 'event-1',
        title: 'At Binme',
        sportType: 'At Binme',
        city: 'Ankara',
        eventDate: DateTime(2026, 6, 1),
        capacityTotal: 12,
        status: 'active',
        hostId: 'user-1',
        organizerType: EventOrganizerType.business,
        organizerUserId: 'user-1',
        organizerBusinessId: 'business-1',
      );
      final personalEvent = futureBusinessEvent.copyWith(
        id: 'event-2',
        organizerType: EventOrganizerType.user,
        organizerBusinessId: null,
      );

      expect(
        futureBusinessEvent.shouldCancelWhenSwitchingBackToUser(
          DateTime(2026, 5, 30),
        ),
        isTrue,
      );
      expect(
        futureBusinessEvent.isVisibleInPublicProfileForAccountType(
          ProfileAccountType.user,
        ),
        isFalse,
      );
      expect(
        personalEvent.isVisibleInPublicProfileForAccountType(
          ProfileAccountType.user,
        ),
        isTrue,
      );
    });

    test('business delete sets account type to user', () {
      expect(
        BusinessAccountDeletionRules.profileAccountTypeAfterDelete(),
        ProfileAccountType.user,
      );
    });

    test('business delete sets business status deleted', () {
      const account = BusinessAccount(
        id: 'business-1',
        ownerUserId: 'user-1',
        name: 'Padel Club',
        username: 'padelclub',
        category: 'Padel Kortu',
        city: 'Istanbul',
        district: 'Kadikoy',
      );

      expect(
        BusinessAccountDeletionRules.businessStatusAfterDelete(),
        BusinessAccountStatus.deleted,
      );
      expect(
        BusinessAccountDeletionRules.shouldDeactivateBusinessAccount(account),
        isTrue,
      );
    });

    test('deleted business account is not publicly visible', () {
      const account = BusinessAccount(
        id: 'business-1',
        ownerUserId: 'user-1',
        name: 'Padel Club',
        username: 'padelclub',
        category: 'Padel Kortu',
        city: 'Istanbul',
        district: 'Kadikoy',
        status: BusinessAccountStatus.deleted,
      );

      expect(account.isPubliclyVisible, isFalse);
    });

    test('user mode cannot select business event fields', () {
      const account = BusinessAccount(
        id: 'business-1',
        ownerUserId: 'user-1',
        name: 'Padel Club',
        username: 'padelclub',
        category: 'Padel Kortu',
        city: 'Istanbul',
        district: 'Kadikoy',
      );

      expect(
        CreateEventInput.canUseBusinessEventFields(
          isBusinessAccount: false,
          businessAccount: account,
        ),
        isFalse,
      );
      expect(
        CreateEventInput.defaultOrganizerType(
          isBusinessAccount: false,
          businessAccount: account,
        ),
        EventOrganizerType.user,
      );
    });

    test('business delete removes sponsored flags in RPC', () {
      final migration = File(
        'supabase/migrations/20260604123000_fix_business_delete_moderation_bypass.sql',
      ).readAsStringSync();

      expect(migration, contains("set status = 'deleted'"));
      expect(migration, contains('is_sponsored = false'));
      expect(migration, contains('sponsored_until = null'));
      expect(migration, contains('sponsored_priority = 0'));
    });

    test('business delete RPC is idempotent', () {
      final migration = File(
        'supabase/migrations/20260604123000_fix_business_delete_moderation_bypass.sql',
      ).readAsStringSync();

      expect(
        migration,
        contains("and business.status in ('active', 'pending')"),
      );
      expect(migration, contains("profile.account_type = 'business'"));
      expect(migration, contains('return query'));
      expect(migration, isNot(contains('business_account_missing')));
    });

    test('normal client cannot set status or is_verified', () {
      final migration = File(
        'supabase/migrations/20260604123000_fix_business_delete_moderation_bypass.sql',
      ).readAsStringSync();

      expect(
        migration,
        contains("current_setting('app.bypass_business_moderation', true)"),
      );
      expect(
        migration,
        contains('new.is_verified is distinct from old.is_verified'),
      );
      expect(migration, contains('new.status is distinct from old.status'));
      expect(
        migration,
        contains(
          "raise exception 'Business moderation fields cannot be changed by clients.'",
        ),
      );
    });

    test(
      'delete RPC can bypass moderation trigger for status and verification',
      () {
        final migration = File(
          'supabase/migrations/20260604123000_fix_business_delete_moderation_bypass.sql',
        ).readAsStringSync();

        expect(
          migration,
          contains(
            "perform set_config('app.bypass_business_moderation', 'on', true)",
          ),
        );
        expect(migration, contains("set status = 'deleted'"));
        expect(migration, contains('is_verified = false'));
        expect(
          migration.indexOf("where business.owner_user_id = v_user_id"),
          lessThan(migration.indexOf("perform set_config(")),
        );
      },
    );

    test('business delete hides future business events', () {
      final now = DateTime(2026, 5, 30);
      final futureBusinessEvent = _event(
        id: 'future-business',
        organizerType: EventOrganizerType.business,
        eventDate: DateTime(2026, 6, 1),
      );
      final pastBusinessEvent = _event(
        id: 'past-business',
        organizerType: EventOrganizerType.business,
        eventDate: DateTime(2026, 5, 1),
      );

      expect(
        BusinessAccountDeletionRules.shouldCancelBusinessEvent(
          isBusinessEvent: futureBusinessEvent.isBusinessEvent,
          status: futureBusinessEvent.status,
          eventDate: futureBusinessEvent.eventDate,
          now: now,
        ),
        isTrue,
      );
      expect(
        BusinessAccountDeletionRules.shouldCancelBusinessEvent(
          isBusinessEvent: pastBusinessEvent.isBusinessEvent,
          status: pastBusinessEvent.status,
          eventDate: pastBusinessEvent.eventDate,
          now: now,
        ),
        isFalse,
      );
    });

    test('normal user event creation still works after business delete', () {
      final input = CreateEventInput(
        title: 'User Padel',
        sportType: 'Padel',
        city: 'Istanbul',
        locationText: 'Kadikoy Padel Club',
        eventDate: DateTime(2026, 6, 4),
        capacityTotal: 8,
        capacityMale: 0,
        capacityFemale: 0,
        capacityAny: 8,
        organizerType: EventOrganizerType.user,
        isPaid: true,
        priceAmount: 300,
      );

      final payload = input.toCreateJson(hostId: 'user-1');

      expect(payload['organizer_type'], EventOrganizerType.user);
      expect(payload['host_id'], 'user-1');
      expect(payload['is_paid'], isFalse);
      expect(payload.containsKey('organizer_business_id'), isFalse);
    });

    test('non-owner cannot delete business account', () {
      const account = BusinessAccount(
        id: 'business-1',
        ownerUserId: 'owner-1',
        name: 'Padel Club',
        username: 'padelclub',
        category: 'Padel Kortu',
        city: 'Istanbul',
        district: 'Kadikoy',
      );
      final migration = File(
        'supabase/migrations/20260604123000_fix_business_delete_moderation_bypass.sql',
      ).readAsStringSync();

      expect(
        BusinessAccountDeletionRules.canDeleteBusinessAccount(
          currentUserId: 'user-2',
          account: account,
        ),
        isFalse,
      );
      expect(migration, contains('business.owner_user_id = v_user_id'));
      expect(migration, contains('auth.uid()'));
    });

    test('business upgrade keeps same profile id and followers', () {
      const personal = Profile(
        id: 'profile-1',
        userId: 'user-1',
        username: 'emir',
        tag: '0001',
        firstName: 'Emir',
        accountType: ProfileAccountType.user,
      );
      final upgraded = personal.copyWith(
        accountType: ProfileAccountType.business,
        username: 'golbasi_at_ciftligi',
        firstName: 'Golbasi At Ciftligi',
        businessAccountId: 'business-1',
      );
      final detail = PublicProfileDetail.fromJson({
        'user_id': 'user-1',
        'username': 'golbasi_at_ciftligi',
        'tag': '0001',
        'first_name': 'Golbasi At Ciftligi',
        'account_type': ProfileAccountType.business,
        'business_account_id': 'business-1',
        'business_name': 'Ignored Business Row',
        'business_username': 'ignored_business',
        'business_tag': '9999',
        'followers_count': 12,
        'following_count': 8,
      });

      expect(upgraded.id, personal.id);
      expect(upgraded.userId, personal.userId);
      expect(detail.followersCount, 12);
      expect(detail.followingCount, 8);
      expect(detail.displayName, 'Golbasi At Ciftligi');
      expect(detail.handleLabel, 'golbasi_at_ciftligi#0001');
    });

    test('feed author uses current profile identity', () {
      final post = Post.fromJson({
        'id': 'post-1',
        'user_id': 'user-1',
        'image_url': 'https://example.com/post.jpg',
        'author_username': 'golbasi_at_ciftligi',
        'author_tag': '0001',
        'author_avatar_url': 'https://example.com/profile.jpg',
        'created_at': DateTime(2026, 5, 28).toIso8601String(),
      });

      expect(post.userId, 'user-1');
      expect(post.authorUsername, 'golbasi_at_ciftligi');
      expect(post.authorTag, '0001');
      expect(post.authorAvatarUrl, 'https://example.com/profile.jpg');
    });

    test('event host uses current profile identity route', () {
      final event = Event(
        id: 'event-1',
        title: 'At Binme',
        sportType: 'At Binme',
        city: 'Ankara',
        eventDate: DateTime(2026, 6, 1),
        capacityTotal: 12,
        status: 'active',
        hostId: 'user-1',
        organizerType: EventOrganizerType.business,
        organizerUserId: 'user-1',
        organizerBusinessId: 'business-1',
      );
      final hostPreview = PublicProfilePreview.fromJson({
        'user_id': event.hostId,
        'username': 'golbasi_at_ciftligi',
        'tag': '0001',
        'first_name': 'Golbasi At Ciftligi',
        'account_type': ProfileAccountType.business,
        'business_username': 'ignored_business',
        'business_tag': '9999',
      });

      expect(event.hostId, 'user-1');
      expect(RouteNames.publicProfile, 'publicProfile');
      expect(hostPreview.displayName, 'Golbasi At Ciftligi');
      expect(hostPreview.usernameTag, 'golbasi_at_ciftligi#0001');
    });

    test('switching business to user succeeds in controller', () async {
      final controller = ProfileController(
        const _SwitchProfileService(ProfileAccountType.user),
      );

      final ok = await controller.switchAccountType(ProfileAccountType.user);

      expect(ok, isTrue);
      expect(controller.state.profile?.accountType, ProfileAccountType.user);
      expect(controller.state.message, isNull);
    });

    test('switching business to user maps failure to friendly copy', () async {
      final controller = ProfileController(
        const _FailingSwitchProfileService(),
      );

      final ok = await controller.switchAccountType(ProfileAccountType.user);

      expect(ok, isFalse);
      expect(
        controller.state.message,
        'Hesap türü değiştirilemedi. Tekrar dene.',
      );
    });

    test('switching business to user changes active identity helper', () {
      const business = Profile(
        id: 'user-1',
        userId: 'user-1',
        username: 'selin',
        tag: '0002',
        firstName: 'Selin',
        accountType: ProfileAccountType.business,
        businessAccountId: 'business-1',
      );

      final user = business.copyWith(accountType: ProfileAccountType.user);

      expect(business.isBusinessAccount, isTrue);
      expect(user.isBusinessAccount, isFalse);
      expect(user.businessAccountId, 'business-1');
    });

    test('At Ciftligi cannot select Futbol', () {
      expect(
        BusinessCategories.allowedActivitiesForBusinessCategory(
          category: 'At Çiftliği',
        ),
        contains('At Binme'),
      );
      expect(
        BusinessCategories.canCreateActivity(
          category: 'At Çiftliği',
          activity: 'At Binme',
        ),
        isTrue,
      );
      expect(
        BusinessCategories.canCreateActivity(
          category: 'At Çiftliği',
          activity: 'Futbol',
        ),
        isFalse,
      );
    });

    test('Kafe category allows social workshop and custom activity', () {
      final activities =
          BusinessCategories.allowedActivitiesForBusinessCategory(
            category: 'Kafe',
          );

      expect(activities, contains('Sosyal Buluşma'));
      expect(activities, contains('Workshop'));
      expect(activities, contains('Diğer'));
      expect(
        BusinessCategories.canCreateActivity(
          category: 'Kafe',
          activity: 'Kitap Kulübü',
        ),
        isTrue,
      );
    });

    test('Diger category allows valid custom activity', () {
      expect(
        BusinessCategories.canCreateActivity(
          category: BusinessCategories.other,
          customCategory: 'Kano Merkezi',
          activity: 'Kano Turu',
        ),
        isTrue,
      );
      expect(
        BusinessCategories.canCreateActivity(
          category: BusinessCategories.other,
          customCategory: 'Kano Merkezi',
          activity: 'A',
        ),
        isFalse,
      );
    });

    test('business review rating validation is 1 to 5', () {
      expect(BusinessReviewRules.isValidRating(1), isTrue);
      expect(BusinessReviewRules.isValidRating(5), isTrue);
      expect(BusinessReviewRules.isValidRating(0), isFalse);
      expect(BusinessReviewRules.isValidRating(6), isFalse);
      expect(BusinessReviewRules.clampRating(9), 5);
      expect(BusinessReviewRules.clampRating(-2), 1);
    });

    test('business review uniqueness is one per business event user', () {
      final reviewKeys = <String>{};
      final first = reviewKeys.add('business-1:event-1:user-1');
      final second = reviewKeys.add('business-1:event-1:user-1');

      expect(first, isTrue);
      expect(second, isFalse);
    });

    test('business review helper blocks own business and normal events', () {
      expect(
        BusinessReviewRules.canReviewBusinessEvent(
          isBusinessEvent: true,
          isOwner: false,
          attendanceStatus: EventParticipationStatus.checkedIn,
        ),
        isTrue,
      );
      expect(
        BusinessReviewRules.canReviewBusinessEvent(
          isBusinessEvent: true,
          isOwner: true,
          attendanceStatus: EventParticipationStatus.checkedIn,
        ),
        isFalse,
      );
      expect(
        BusinessReviewRules.canReviewBusinessEvent(
          isBusinessEvent: false,
          isOwner: false,
          attendanceStatus: EventParticipationStatus.checkedIn,
        ),
        isFalse,
      );
      expect(
        BusinessReviewRules.canReviewBusinessEvent(
          isBusinessEvent: true,
          isOwner: false,
          attendanceStatus: EventParticipationStatus.waitlisted,
        ),
        isFalse,
      );
    });

    test('business rating summary formats no rating and average', () {
      final empty = BusinessRatingSummary.empty();
      const rated = BusinessRatingSummary(averageRating: 4.6, ratingCount: 23);

      expect(empty.hasRatings, isFalse);
      expect(empty.countLabel, 'Henüz değerlendirme yok.');
      expect(rated.averageLabel, '4.6 ★');
      expect(rated.countLabel, '23 değerlendirme');
    });

    test('business review errors are friendly', () {
      expect(
        friendlyBusinessReviewErrorMessage('PostgrestException invalid_rating'),
        'Puan 1 ile 5 arasında olmalı.',
      );
      expect(
        friendlyBusinessReviewErrorMessage(
          'PostgrestException event_not_attended',
        ),
        'Bu işletmeyi değerlendirmek için etkinliğe katılmış olmalısın.',
      );
      expect(
        friendlyBusinessReviewErrorMessage('PostgrestException unknown'),
        'Değerlendirme gönderilemedi. Tekrar dene.',
      );
    });
    test('business stats model parses nulls safely', () {
      final stats = BusinessStats.fromJson({
        'total_events': null,
        'upcoming_events': '2',
        'past_events': null,
        'total_join_requests': 5,
        'confirmed_participants': null,
        'checked_in_count': 3,
        'no_show_count': null,
        'waitlisted_count': null,
        'average_rating': '4.6',
        'rating_count': null,
        'sponsored_events_count': 1,
      });

      expect(stats.totalEvents, 0);
      expect(stats.upcomingEvents, 2);
      expect(stats.confirmedParticipants, 0);
      expect(stats.checkedInCount, 3);
      expect(stats.averageRatingLabel, '-');
      expect(stats.sponsoredEventsCount, 1);
    });

    test('business stats empty display helper works', () {
      final stats = BusinessStats.empty();

      expect(stats.isEmpty, isTrue);
      expect(stats.averageRatingLabel, '-');
    });

    test('business stats rating formatting works', () {
      const stats = BusinessStats(
        totalEvents: 1,
        upcomingEvents: 1,
        pastEvents: 0,
        totalJoinRequests: 2,
        confirmedParticipants: 2,
        checkedInCount: 1,
        noShowCount: 0,
        waitlistedCount: 0,
        averageRating: 4.56,
        ratingCount: 4,
        sponsoredEventsCount: 1,
      );

      expect(stats.isEmpty, isFalse);
      expect(stats.averageRatingLabel, '4.6');
    });

    test('business stats owner helper gates private stats', () {
      expect(
        BusinessStatsRules.canViewStats(
          ownerUserId: 'owner-1',
          currentUserId: 'owner-1',
        ),
        isTrue,
      );
      expect(
        BusinessStatsRules.canViewStats(
          ownerUserId: 'owner-1',
          currentUserId: 'user-1',
        ),
        isFalse,
      );
    });
  });
}

class _CreateSucceedsRefreshFailsFeedService extends FeedService {
  const _CreateSucceedsRefreshFailsFeedService();

  @override
  Future<Post> createPost(CreatePostInput input) async {
    return Post(
      id: 'post-1',
      userId: 'user-1',
      imageUrl: 'https://example.com/post.jpg',
      createdAt: DateTime(2026, 5, 27),
    );
  }

  @override
  Future<List<PostWithStats>> fetchPostsWithStats({
    int limit = SupabasePageSizes.feed,
    int offset = 0,
  }) async {
    throw StateError('PGRST202 schema cache');
  }
}

Event _event({
  String id = 'event-1',
  DateTime? eventDate,
  int approvedCount = 0,
  int capacityTotal = 12,
  String organizerType = EventOrganizerType.user,
  bool businessIsVerified = false,
  String businessStatus = BusinessAccountStatus.active,
  bool businessIsPlusActive = false,
  bool isSponsored = false,
  DateTime? sponsoredUntil,
  int sponsoredPriority = 0,
}) {
  return Event(
    id: id,
    hostId: 'host-1',
    title: 'Basketbol',
    sportType: 'Basketbol',
    city: 'İstanbul',
    eventDate: eventDate ?? DateTime.now().add(const Duration(days: 1)),
    capacityTotal: capacityTotal,
    approvedCount: approvedCount,
    status: 'active',
    organizerType: organizerType,
    organizerBusinessId: organizerType == EventOrganizerType.business
        ? 'business-1'
        : null,
    businessOrganizer: organizerType == EventOrganizerType.business
        ? EventBusinessOrganizer(
            id: 'business-1',
            name: 'Padel Club',
            username: 'padelclub',
            isVerified: businessIsVerified,
            isPlusActive: businessIsPlusActive,
            status: businessStatus,
          )
        : null,
    isSponsored: isSponsored,
    sponsoredUntil: sponsoredUntil,
    sponsoredPriority: sponsoredPriority,
  );
}

class _SwitchProfileService extends ProfileService {
  const _SwitchProfileService(this.accountType);

  final String accountType;

  @override
  Future<Profile> updateMyAccountType(String accountType) async {
    return Profile(
      id: 'user-1',
      userId: 'user-1',
      username: 'selin',
      tag: '0002',
      firstName: 'Selin',
      accountType: this.accountType,
      businessAccountId: 'business-1',
    );
  }
}

class _FailingSwitchProfileService extends ProfileService {
  const _FailingSwitchProfileService();

  @override
  Future<Profile> updateMyAccountType(String accountType) async {
    throw StateError('event_sponsorship_fields_are_admin_only');
  }
}
