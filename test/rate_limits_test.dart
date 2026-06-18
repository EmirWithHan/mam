import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_a_man/core/utils/error_messages.dart';
import 'package:match_a_man/core/utils/rate_limits.dart';
import 'package:match_a_man/features/business/business_reviews_service.dart';
import 'package:match_a_man/features/business/business_service.dart';

void main() {
  group('RateLimitRules', () {
    test('keeps configured action limits explicit', () {
      expect(RateLimitRules.createPostPerHour, 10);
      expect(RateLimitRules.normalCreateEventPerDay, 3);
      expect(RateLimitRules.businessCreateEventPerDay, 3);
      expect(RateLimitRules.commentsPerHour, 30);
      expect(RateLimitRules.followRequestsPerHour, 30);
      expect(RateLimitRules.reportsPerDay, 10);
      expect(RateLimitRules.eventJoinRequestsPerDay, 20);
      expect(RateLimitRules.businessReviewPerTarget, 1);
    });

    test('create event helper applies normal and business limits', () {
      expect(
        RateLimitRules.createEventLimit(isBusinessEvent: false),
        RateLimitRules.normalCreateEventPerDay,
      );
      expect(
        RateLimitRules.createEventLimit(isBusinessEvent: true),
        RateLimitRules.businessCreateEventPerDay,
      );
    });
  });

  group('friendly rate-limit errors', () {
    test('map raw DB token to shared copy', () {
      expect(
        friendlyErrorMessage('PostgrestException rate_limit_exceeded'),
        'Etkinlik veya işlem limitine ulaştın. Güvenilir sporcular günde 3, yeni sporcular günde 2, standart işletmeler ise ayda 3 etkinlik oluşturabilir. Limiti artırmak için Business Plus\'a geçebilirsin.',
      );
      expect(
        friendlyCreatePostErrorMessage('rate_limit_exceeded'),
        friendlyRateLimitMessage,
      );
      expect(
        friendlyBusinessApplicationErrorMessage('rate_limit_exceeded'),
        friendlyRateLimitMessage,
      );
      expect(
        friendlyBusinessReviewErrorMessage('rate_limit_exceeded'),
        friendlyRateLimitMessage,
      );
    });
  });

  group('rate-limit migration', () {
    test('locks table behind RPC and raises app-readable error', () {
      final migration = File(
        'supabase/migrations/20260604153000_rate_limiting_foundation.sql',
      ).readAsStringSync();

      expect(
        migration,
        contains('create table if not exists public.rate_limit_events'),
      );
      expect(
        migration,
        contains(
          'alter table public.rate_limit_events enable row level security',
        ),
      );
      expect(migration, contains('check_and_record_rate_limit'));
      expect(migration, contains('security definer'));
      expect(migration, contains('rate_limit_exceeded'));
      expect(migration, contains('grant execute'));
      expect(
        migration,
        contains('revoke all on public.rate_limit_events from authenticated'),
      );
    });
  });
}
