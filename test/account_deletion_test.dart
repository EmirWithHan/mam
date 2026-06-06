import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_a_man/features/settings/settings_page.dart';

void main() {
  group('account deletion confirmation', () {
    test('requires the exact Turkish confirmation word', () {
      expect(AccountDeletionConfirmation.isConfirmed('SİL'), isTrue);
      expect(AccountDeletionConfirmation.isConfirmed('  SİL  '), isTrue);
      expect(AccountDeletionConfirmation.isConfirmed('sil'), isFalse);
      expect(AccountDeletionConfirmation.isConfirmed('DELETE'), isFalse);
      expect(AccountDeletionConfirmation.isConfirmed(''), isFalse);
    });
  });

  group('account deletion migration', () {
    final migration = File(
      'supabase/migrations/20260606130000_account_deletion_request_foundation.sql',
    ).readAsStringSync();

    test('creates request table and RPC without service role exposure', () {
      expect(
        migration,
        contains('create table if not exists public.account_deletion_requests'),
      );
      expect(
        migration,
        contains(
          'create or replace function public.request_my_account_deletion()',
        ),
      );
      expect(migration, contains('security definer'));
      expect(migration, contains("set search_path = ''"));
      expect(
        migration,
        contains(
          'grant execute on function public.request_my_account_deletion() to authenticated',
        ),
      );
      expect(migration.toLowerCase(), isNot(contains('service_role')));
    });

    test('deactivates public identity and blocks new activity', () {
      expect(migration, contains("account_status = 'deletion_requested'"));
      expect(migration, contains('username = null'));
      expect(migration, contains('tag = null'));
      expect(migration, contains('avatar_url = null'));
      expect(
        migration,
        contains(
          'create or replace function public.is_current_profile_active()',
        ),
      );
      expect(migration, contains('and public.is_current_profile_active()'));
    });

    test('keeps deactivated accounts out of username search', () {
      expect(migration, contains('public.search_profiles_by_username'));
      expect(
        migration,
        contains("and coalesce(profile.account_status, 'active') = 'active'"),
      );
    });
  });
}
