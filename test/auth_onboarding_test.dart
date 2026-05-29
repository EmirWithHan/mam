import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_a_man/core/constants/sport_types.dart';
import 'package:match_a_man/core/router/route_names.dart';
import 'package:match_a_man/core/widgets/event_cover_image.dart';
import 'package:match_a_man/core/widgets/main_navigation_shell.dart';
import 'package:match_a_man/core/utils/error_messages.dart';
import 'package:match_a_man/core/utils/phone_verification.dart';
import 'package:match_a_man/core/utils/trust_score_rules.dart';
import 'package:match_a_man/core/utils/user_handle.dart';
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
import 'package:match_a_man/features/profile/public_profile_models.dart';
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

    test('event route constants remain available', () {
      expect(RouteNames.events, 'events');
      expect(RoutePaths.events, '/events');
      expect(RouteNames.eventDetail, 'eventDetail');
      expect(RoutePaths.eventDetail, '/events/:eventId');
      expect(RouteNames.createEvent, 'createEvent');
      expect(RoutePaths.createEvent, '/events/create');
    });

    testWidgets('main navigation keeps Events tab visible', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MainNavigationShell(currentIndex: 1, child: SizedBox.shrink()),
        ),
      );

      expect(find.text('Events'), findsOneWidget);
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

    test('phone normalization supports Turkey formats', () {
      expect(PhoneVerification.normalize('0532 123 45 67'), '+905321234567');
      expect(PhoneVerification.normalize('5321234567'), '+905321234567');
      expect(PhoneVerification.normalize('+90 532 123 45 67'), '+905321234567');
      expect(PhoneVerification.validateOptional('0532 123 45 67'), isNull);
      expect(
        PhoneVerification.validateOptional('123'),
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
    });

    test('duplicate username errors are friendly', () {
      expect(
        friendlyErrorMessage(
          'PostgrestException duplicate key violates profiles_username_key 23505',
        ),
        'Bu kullanıcı adı alınmış.',
      );
    });

    test('business event approve RPC errors stay user-facing', () {
      expect(
        friendlyErrorMessage('PostgrestException business_event_not_owned'),
        'Bu işlem için yetkin yok.',
      );
      expect(
        friendlyErrorMessage('PostgrestException join_request_not_pending'),
        'Bu istek zaten güncellenmiş.',
      );
      expect(
        friendlyErrorMessage('PostgrestException join_request_not_found'),
        'Katılım isteği bulunamadı.',
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
      expect(event.priceLabel, '₺450');
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
      expect(CreateEventInput.canSelectBusinessEvent(account), isTrue);

      final input = CreateEventInput(
        title: 'Padel Night',
        sportType: 'Padel',
        city: 'Istanbul',
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
      expect(payload.containsKey('is_sponsored'), isFalse);
      expect(payload.containsKey('sponsored_until'), isFalse);
      expect(payload.containsKey('sponsored_priority'), isFalse);
    });

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
        isSponsored: true,
        sponsoredUntil: now.subtract(const Duration(days: 1)),
      );
      final active = _event(
        id: 'active-sponsored',
        organizerType: EventOrganizerType.business,
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
                    eventDate: DateTime(2026, 5, 28, 20),
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

      final buttonBox = tester.renderObject<RenderBox>(
        find.byType(FilledButton),
      );
      expect(buttonBox.size.width, lessThanOrEqualTo(96));
    });

    testWidgets('sponsored chip only appears when is_sponsored is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ListView(
                children: [
                  EventCard(
                    event: _event(
                      id: 'business-normal',
                      organizerType: EventOrganizerType.business,
                      isSponsored: false,
                    ),
                  ),
                  EventCard(
                    event: _event(
                      id: 'business-sponsored',
                      organizerType: EventOrganizerType.business,
                      isSponsored: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Sponsorlu'), findsOneWidget);
      expect(find.text('İşletme'), findsNWidgets(2));
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

      expect(find.text('E'), findsOneWidget);
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
      expect(BusinessSettingsCopy.actionTitle(null), 'İşletme hesabına geç');

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

      expect(
        BusinessSettingsCopy.actionTitle(account),
        'İşletme profilini yönet',
      );
      expect(
        BusinessSettingsCopy.actionSubtitle(account),
        'Bozkir At Ciftligi · At Çiftliği',
      );
    });

    test('business badge label maps verified state', () {
      expect(BusinessBadgeLabels.forVerified(false), 'İşletme');
      expect(BusinessBadgeLabels.forVerified(true), 'Doğrulanmış İşletme');
    });
    test('business account public profile replaces personal identity', () {
      final preview = PublicProfilePreview.fromJson({
        'user_id': 'user-1',
        'username': 'emir',
        'tag': '0001',
        'first_name': 'Emir',
        'account_type': ProfileAccountType.business,
        'business_name': 'Bozkir At Ciftligi',
        'business_username': 'bozkirat',
        'business_tag': '1234',
        'business_is_verified': false,
      });

      expect(preview.displayName, 'Bozkir At Ciftligi');
      expect(preview.usernameTag, 'bozkirat#1234');
      expect(preview.isBusinessAccount, isTrue);
    });

    test('At Ciftligi cannot select Futbol', () {
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
  Future<List<PostWithStats>> fetchPostsWithStats() async {
    throw StateError('PGRST202 schema cache');
  }
}

Event _event({
  String id = 'event-1',
  DateTime? eventDate,
  int approvedCount = 0,
  int capacityTotal = 12,
  String organizerType = EventOrganizerType.user,
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
    isSponsored: isSponsored,
    sponsoredUntil: sponsoredUntil,
    sponsoredPriority: sponsoredPriority,
  );
}
