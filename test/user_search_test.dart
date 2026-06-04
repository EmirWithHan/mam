import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_a_man/features/user_search/user_search_models.dart';

void main() {
  group('UserSearchRules', () {
    test('parses username tag handles', () {
      final parsed = UserSearchRules.parse(' EmirHan#1234 ');

      expect(parsed.username, 'emirhan');
      expect(parsed.tag, '1234');
    });

    test('requires at least two characters', () {
      expect(UserSearchRules.canSearch('e'), isFalse);
      expect(UserSearchRules.canSearch('em'), isTrue);
      expect(UserSearchRules.canSearch(' emir '), isTrue);
    });
  });

  group('UserSearchResult action labels', () {
    test('self result disables action', () {
      const result = UserSearchResult(
        userId: 'user-1',
        displayName: 'Emir',
        followState: UserSearchFollowState.self,
      );

      expect(result.actionLabel, 'Sen');
      expect(result.canFollow, isFalse);
    });

    test('public account follow action label is add friend', () {
      const result = UserSearchResult(userId: 'user-2', displayName: 'Selin');

      expect(result.actionLabel, 'Arkadaş ekle');
      expect(result.canFollow, isTrue);
    });

    test('private account request action label is request', () {
      const result = UserSearchResult(
        userId: 'user-2',
        displayName: 'Selin',
        isPrivate: true,
      );

      expect(result.actionLabel, 'İstek gönder');
      expect(result.canFollow, isTrue);
    });

    test('already following label disables action', () {
      const result = UserSearchResult(
        userId: 'user-2',
        displayName: 'Selin',
        followState: UserSearchFollowState.following,
      );

      expect(result.actionLabel, 'Takip ediliyor');
      expect(result.canFollow, isFalse);
    });

    test('pending request label disables action', () {
      const result = UserSearchResult(
        userId: 'user-2',
        displayName: 'Selin',
        followState: UserSearchFollowState.pending,
      );

      expect(result.actionLabel, 'İstek gönderildi');
      expect(result.canFollow, isFalse);
    });
  });

  group('safe search fields', () {
    test('model ignores phone and email fields', () {
      final result = UserSearchResult.fromJson({
        'user_id': 'user-1',
        'display_name': 'Emir',
        'username': 'emirhan',
        'tag': '1234',
        'avatar_url': 'https://example.com/avatar.jpg',
        'account_type': 'user',
        'is_private': false,
        'follow_state': 'none',
        'email': 'private@example.com',
        'phone_number': '+905551234567',
      });

      expect(result.userId, 'user-1');
      expect(UserSearchResult.safeFieldKeys, isNot(contains('email')));
      expect(UserSearchResult.safeFieldKeys, isNot(contains('phone')));
      expect(UserSearchResult.safeFieldKeys, isNot(contains('phone_number')));
    });

    test('RPC does not return private sensitive fields', () {
      final migration = File(
        'supabase/migrations/20260604170000_username_search_profiles.sql',
      ).readAsStringSync();

      expect(migration, contains('search_profiles_by_username'));
      expect(migration, contains('limit v_limit'));
      expect(migration, isNot(contains('email')));
      expect(migration, isNot(contains('phone_number')));
      expect(migration, isNot(contains('auth.users')));
    });
  });
}
