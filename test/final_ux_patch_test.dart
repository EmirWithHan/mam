import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_a_man/features/chat/event_chat_models.dart';
import 'package:match_a_man/features/events/events_models.dart';

void main() {
  group('event editing readiness', () {
    test('editable event excludes past and non-active events', () {
      final future = _event(
        eventDate: DateTime.now().add(const Duration(days: 1)),
      );
      final past = _event(
        eventDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      final cancelled = _event(
        eventDate: DateTime.now().add(const Duration(days: 1)),
        status: 'cancelled',
      );

      expect(future.canBeEdited, isTrue);
      expect(past.canBeEdited, isFalse);
      expect(cancelled.canBeEdited, isFalse);
    });

    test('update payload only contains safe editable event fields', () {
      final input = UpdateEventInput(
        title: 'Updated match',
        description: 'Bring water',
        sportType: 'Futbol',
        city: 'Istanbul',
        district: 'Kadikoy',
        locationText: 'Pitch 1',
        locationLat: 41,
        locationLng: 29,
        eventDate: DateTime(2026, 7, 1, 20),
        capacityTotal: 12,
        capacityMale: 0,
        capacityFemale: 0,
        capacityAny: 12,
        isBusinessEvent: true,
        isPaid: false,
      );

      final payload = input.toUpdateJson();

      expect(payload['title'], 'Updated match');
      expect(payload['location_text'], 'Pitch 1');
      expect(payload['is_paid'], isFalse);
      expect(payload['price_amount'], isNull);
      expect(payload.containsKey('host_id'), isFalse);
      expect(payload.containsKey('approved_count'), isFalse);
      expect(payload.containsKey('status'), isFalse);
      expect(payload.containsKey('organizer_business_id'), isFalse);
    });
  });

  test('chat composer uses icon send action instead of wrapping text', () {
    final source = File(
      'lib/features/chat/event_chat_page.dart',
    ).readAsStringSync();

    expect(source, contains('Icons.send_rounded'));
    expect(source, contains('reverse: false'));
    expect(source, contains('maxScrollExtent'));
    expect(source, contains('Mesaj gönder'));
    expect(source, isNot(contains("label: 'Gönder'")));
  });

  test('chat messages normalize to oldest first and latest last', () {
    final newest = _message(id: '3', createdAt: DateTime(2026, 6, 12, 12, 3));
    final oldest = _message(id: '1', createdAt: DateTime(2026, 6, 12, 12, 1));
    final middle = _message(id: '2', createdAt: DateTime(2026, 6, 12, 12, 2));

    final ordered = EventMessage.chronological([newest, oldest, middle]);

    expect(ordered.map((message) => message.id), ['1', '2', '3']);
    expect(ordered.last.message, 'message-3');
  });

  test('social auth is branded beyond single-letter Google', () {
    final source = File(
      'lib/features/auth/widgets/social_auth_buttons.dart',
    ).readAsStringSync();

    expect(source, contains('Google ile devam et'));
    expect(source, contains('Apple ile devam et'));
    expect(source, contains('assets/auth/google_logo.png'));
    expect(source, contains('assets/auth/apple_logo.png'));
    expect(source, contains('Image.asset'));
    expect(source, contains('SizedBox.square'));
    expect(source, contains('dimension: 52'));
    expect(source, contains('onApplePressed != null'));
    expect(source, isNot(contains("label: 'G'")));
    expect(source, isNot(contains('Text(')));
    expect(source, isNot(contains("Text(\r\n            'G'")));
    expect(source, isNot(contains("Text(\n            'G'")));
  });

  test('social page separates user and event chat search labels', () {
    final source = File(
      'lib/features/social/social_page.dart',
    ).readAsStringSync();

    expect(source, contains('Kullanıcılar'));
    expect(source, contains('Kullanıcı ara'));
    expect(source, contains('Etkinlik sohbetleri'));
    expect(source, contains('Etkinlik sohbetlerinde ara'));
    expect(source, contains('Katıldığın etkinlik sohbetlerini ara'));
  });

  test(
    'new profiles default to private without backfilling existing users',
    () {
      final service = File(
        'lib/features/profile/profile_service.dart',
      ).readAsStringSync();
      final migration = File(
        'supabase/migrations/20260612100000_profiles_private_default.sql',
      ).readAsStringSync();

      expect(service, contains("'is_private': true"));
      expect(migration, contains('alter column is_private set default true'));
      expect(
        migration.toLowerCase(),
        isNot(contains('update public.profiles')),
      );
    },
  );
}

Event _event({required DateTime eventDate, String status = 'active'}) {
  return Event(
    id: 'event-1',
    hostId: 'host-1',
    title: 'Match',
    city: 'Istanbul',
    eventDate: eventDate,
    capacityTotal: 10,
    status: status,
  );
}

EventMessage _message({required String id, required DateTime createdAt}) {
  return EventMessage(
    id: id,
    eventId: 'event-1',
    senderId: 'user-1',
    message: 'message-$id',
    createdAt: createdAt,
  );
}
