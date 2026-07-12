import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_a_man/features/notifications/notifications_models.dart';

void main() {
  group('push notification MVP', () {
    test('push token registration validates platform and token length', () {
      const valid = PushTokenRegistration(
        token: 'abcdefghijklmnopqrstuvwxyz123456',
        platform: 'android',
      );
      const short = PushTokenRegistration(token: 'short', platform: 'android');
      const wrongPlatform = PushTokenRegistration(
        token: 'abcdefghijklmnopqrstuvwxyz123456',
        platform: 'desktop',
      );

      expect(valid.isValid, isTrue);
      expect(short.isValid, isFalse);
      expect(wrongPlatform.isValid, isFalse);
      expect(valid.toUpsertJson(userId: 'user-1')['user_id'], 'user-1');
      expect(valid.toUpsertJson(userId: 'user-1')['platform'], 'android');
    });

    test('migration keeps push tokens owner-scoped and private', () {
      final migration = File(
        'supabase/migrations/20260610120000_push_notifications_mvp.sql',
      ).readAsStringSync();
      final workerGrants = File(
        'supabase/migrations/20260610123000_push_worker_service_role_grants.sql',
      ).readAsStringSync();

      expect(
        migration,
        contains('create table if not exists public.user_push_tokens'),
      );
      expect(migration, contains('unique (user_id, token)'));
      expect(migration, contains('enable row level security'));
      expect(migration, contains('using (user_id = auth.uid())'));
      expect(migration, contains('with check (user_id = auth.uid())'));
      expect(
        migration,
        contains('revoke all on public.user_push_tokens from anon'),
      );
      expect(
        migration,
        contains('create table if not exists public.push_notification_outbox'),
      );
      expect(
        workerGrants,
        contains('grant usage on schema public to service_role'),
      );
      expect(
        workerGrants,
        contains(
          'grant select, update on table public.push_notification_outbox to service_role',
        ),
      );
      expect(
        workerGrants,
        contains(
          'grant select on table public.user_push_tokens to service_role',
        ),
      );
      expect(workerGrants, isNot(contains('to anon')));
      expect(migration, contains("new.type <> 'event_join_request'"));
      expect(migration, contains('Yeni katılım isteği'));
    });

    test('edge function sends queued push server-side only', () {
      final function = File(
        'supabase/functions/send-push-notifications/index.ts',
      ).readAsStringSync();

      expect(function, contains('FCM_PROJECT_ID'));
      expect(function, contains('FCM_CLIENT_EMAIL'));
      expect(function, contains('FCM_PRIVATE_KEY'));
      expect(function, contains('MAM_SUPABASE_SERVICE_KEY'));
      expect(function, contains('missing_worker_service_key'));
      expect(function, contains('invalid_worker_service_key'));
      expect(function, contains('createWorkerSupabaseClient'));
      expect(function, contains('autoRefreshToken: false'));
      expect(function, contains('detectSessionInUrl: false'));
      expect(function, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
      expect(function, isNot(contains('SUPABASE_SECRET_KEYS')));
      expect(function, isNot(contains('must be a service_role key')));
      expect(function, isNot(contains('isServiceRoleKey')));
      expect(function, isNot(contains('SUPABASE_ANON_KEY')));
      expect(function, contains('firebase.messaging'));
      expect(function, contains('push_notification_outbox'));
      expect(function, contains('user_push_tokens'));
      expect(function, contains('service_claim_push_notification_outbox'));
      expect(function, contains('p_limit'));
      expect(function, contains('.eq("status", "processing")'));
      expect(function, isNot(contains('.eq("status", "pending")')));
      expect(function, isNot(contains('.eq(\'status\', \'pending\')')));
      expect(function, isNot(contains('nextAttempts')));
      expect(function, isNot(contains('attempts: attempts + 1')));
      expect(function, isNot(contains('Firebase Auth')));
      expect(function, isNot(contains('Firebase Firestore')));

      final migrationClaims = File(
        'supabase/migrations/20260712104000_recover_stale_push_claims.sql',
      ).readAsStringSync();
      expect(
        migrationClaims,
        contains('public.service_claim_push_notification_outbox'),
      );
      expect(migrationClaims, contains('attempts = outbox.attempts + 1'));
      expect(migrationClaims, contains("status = 'processing'"));
      expect(migrationClaims, contains('for update skip locked'));
    });

    test('edge function can be protected by optional worker secret', () {
      final function = File(
        'supabase/functions/send-push-notifications/index.ts',
      ).readAsStringSync();

      expect(function, contains('PUSH_WORKER_SECRET'));
      expect(function, contains('x-worker-secret'));
      expect(function, contains('unauthorized_worker'));
    });

    test('edge function has self test mode and no JWT verification', () {
      final function = File(
        'supabase/functions/send-push-notifications/index.ts',
      ).readAsStringSync();
      final config = File('supabase/config.toml').readAsStringSync();

      expect(function, contains('mode === "self_test"'));
      expect(function, contains('dbReadable'));
      expect(function, contains('selectedKeySource'));
      expect(function, contains('MAM_SUPABASE_SERVICE_KEY'));
      expect(function, contains('.select("id")'));
      expect(config, contains('[functions.send-push-notifications]'));
      expect(config, contains('verify_jwt = false'));
    });

    test('push worker runbook documents verification and scheduling', () {
      final doc = File('docs/push_worker_runbook.md').readAsStringSync();

      expect(doc, contains('MAM_SUPABASE_SERVICE_KEY'));
      expect(doc, contains('select user_id, platform'));
      expect(doc, contains('from public.user_push_tokens'));
      expect(doc, contains('from public.push_notification_outbox'));
      expect(doc, contains('send-push-notifications'));
      expect(doc, contains('pending'));
      expect(doc, contains('sent'));
      expect(doc, contains('skipped'));
      expect(doc, contains('failed'));
      expect(doc, contains('No existing Supabase cron'));
    });

    test(
      'Flutter dependencies include only Firebase push transport packages',
      () {
        final pubspec = File('pubspec.yaml').readAsStringSync();

        expect(pubspec, contains('firebase_core:'));
        expect(pubspec, contains('firebase_messaging:'));
        expect(pubspec, isNot(contains('firebase_auth:')));
        expect(pubspec, isNot(contains('cloud_firestore:')));
        expect(pubspec, isNot(contains('firebase_storage:')));
        expect(pubspec, isNot(contains('firebase_database:')));
        expect(pubspec, isNot(contains('firebase_analytics:')));
      },
    );

    test('Android Firebase wiring keeps the existing app identity', () {
      final settingsGradle = File(
        'android/settings.gradle.kts',
      ).readAsStringSync();
      final appGradle = File('android/app/build.gradle.kts').readAsStringSync();
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(settingsGradle, contains('com.google.gms.google-services'));
      expect(appGradle, contains('id("com.google.gms.google-services")'));
      expect(appGradle, contains('applicationId = "com.matchaman.app"'));
      expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    });
  });
}
