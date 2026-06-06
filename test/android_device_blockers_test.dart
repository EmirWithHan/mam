import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_a_man/core/utils/error_messages.dart';
import 'package:match_a_man/features/events/events_models.dart';
import 'package:match_a_man/features/events/widgets/event_card.dart';

void main() {
  group('Android device blocker error mapping', () {
    test('generic database errors stay friendly', () {
      final message = friendlyErrorMessage(
        'PostgrestException code: PGRST202 message: schema cache miss',
      );

      expect(message, isNot(contains('PostgrestException')));
      expect(message, isNot(contains('PGRST202')));
      expect(message, contains('Tekrar dene'));
    });

    test('permission errors map to friendly permission copy', () {
      final message = friendlyErrorMessage(
        'PostgrestException code: 42501 message: permission denied',
      );

      expect(message, contains('yetkin'));
      expect(message, isNot(contains('42501')));
      expect(message, isNot(contains('permission denied')));
    });
  });

  group('Android blocker migration', () {
    test('keeps public authenticated pages independent from admin/business', () {
      final migration = File(
        'supabase/migrations/20260605010000_android_device_blocker_fixes.sql',
      ).readAsStringSync();

      expect(
        migration,
        contains('grant select, insert, update, delete on table public.events'),
      );
      expect(
        migration,
        contains(
          'grant execute on function public.search_profiles_by_username',
        ),
      );
      expect(
        migration,
        contains(
          'grant execute on function public.get_visible_feed_posts_with_stats',
        ),
      );
      expect(
        migration,
        contains('grant execute on function public.get_public_profile_detail'),
      );
      expect(migration, contains('using (user_id = auth.uid())'));
    });

    test('events RLS visibility policy avoids recursive table checks', () {
      final migration = File(
        'supabase/migrations/20260606090000_fix_events_rls_infinite_recursion.sql',
      ).readAsStringSync();
      final selectPolicy = migration.substring(
        migration.indexOf(
          'create policy "Events are visible without recursive participant checks"',
        ),
        migration.indexOf(
          'drop policy if exists "Users can create personal or owned business events"',
        ),
      );

      expect(
        migration,
        contains(
          'drop policy if exists "Events are visible to members or public list"',
        ),
      );
      expect(migration, contains('security definer'));
      expect(migration, contains('set search_path = public'));
      expect(selectPolicy, isNot(contains('event_participants')));
      expect(selectPolicy, isNot(contains('from public.events')));
      expect(selectPolicy, contains("status in ('active', 'completed')"));
      expect(selectPolicy, contains('public.event_business_is_active'));
    });

    test('events page header is part of the scrollable list', () {
      final source = File(
        'lib/features/events/events_page.dart',
      ).readAsStringSync();

      expect(source, contains('return ListView.separated('));
      expect(source, contains('if (index == 0) return header;'));
      expect(source, contains('class _EventsHeader extends StatelessWidget'));
      expect(
        source,
        isNot(contains('Expanded(\n                child: _EventsBody')),
      );
      expect(source, isNot(contains('SliverPersistentHeader')));
    });

    test('remaining blocker sweep keeps realtime logs sanitized', () {
      final sources = [
        File(
          'lib/features/notifications/notifications_provider.dart',
        ).readAsStringSync(),
        File('lib/features/feed/feed_provider.dart').readAsStringSync(),
        File('lib/features/business/business_provider.dart').readAsStringSync(),
        File(
          'lib/features/notifications/notifications_service.dart',
        ).readAsStringSync(),
        File('lib/features/feedback/feedback_service.dart').readAsStringSync(),
        File('lib/features/business/business_service.dart').readAsStringSync(),
      ];
      final combined = sources.join('\n');

      expect(combined, contains('logSupabaseDebug'));
      expect(combined, isNot(contains('realtime subscribe skipped: \$error')));
      expect(
        combined,
        isNot(contains('comments realtime subscribe skipped: \$error')),
      );
      expect(
        combined,
        isNot(contains('application realtime subscribe skipped: \$error')),
      );
    });

    test('android QA doc includes remaining real-device blocker checklist', () {
      final doc = File('docs/android_device_qa.md').readAsStringSync();

      expect(doc, contains('2026-06-06 Remaining Blocker Sweep'));
      expect(doc, contains('flutter build apk --debug'));
      expect(doc, contains('--dart-define=SUPABASE_URL=YOUR_SUPABASE_URL'));
      expect(
        doc,
        contains('--dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY'),
      );
      expect(doc, contains('Logout returns to auth screen'));
      expect(
        doc,
        contains('Events title/search/filter/create area scrolls away'),
      );
      expect(doc, contains('No Firebase or push notifications were added'));
      expect(doc, contains('No product features were added'));
    });

    test('notification mark-read RPCs are owner scoped', () {
      final migration = File(
        'supabase/migrations/20260606120000_notification_mark_read_rpcs.sql',
      ).readAsStringSync();

      expect(
        migration,
        contains('create or replace function public.mark_notification_read'),
      );
      expect(
        migration,
        contains('drop function if exists public.mark_notification_read(uuid)'),
      );
      expect(
        migration,
        contains(
          'create or replace function public.mark_all_notifications_read',
        ),
      );
      expect(
        migration,
        contains(
          'drop function if exists public.mark_all_notifications_read()',
        ),
      );
      expect(migration, contains('security definer'));
      expect(migration, contains("set search_path = ''"));
      expect(migration, contains('notification.recipient_id = v_user_id'));
      expect(
        migration,
        contains(
          'grant execute on function public.mark_notification_read(uuid)',
        ),
      );
      expect(
        migration,
        contains(
          'grant execute on function public.mark_all_notifications_read()',
        ),
      );
      expect(
        migration,
        isNot(
          contains(
            'grant execute on function public.mark_notification_read(uuid)\n  to anon',
          ),
        ),
      );
    });
  });

  group('Android small width layout', () {
    testWidgets('event card fits a 320px wide device', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(8),
                child: EventCard(event: _testEvent),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}

final _testEvent = Event(
  id: '',
  hostId: '',
  title: 'Cok uzun etkinlik adi dar Android ekranda tasmasin diye test',
  description: 'Test event',
  sportType: 'football',
  city: 'Istanbul',
  district: 'Kadikoy',
  locationText: 'Cok uzun tesis ve mahalle konumu',
  eventDate: DateTime(2026, 6, 6, 19),
  capacityTotal: 12,
  approvedCount: 3,
  status: 'active',
);
