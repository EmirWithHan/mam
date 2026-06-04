import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_a_man/core/utils/rate_limits.dart';
import 'package:match_a_man/features/feedback/feedback_models.dart';

void main() {
  group('UserFeedbackRules', () {
    test('validates rating range', () {
      expect(
        const UserFeedbackInput(rating: 0).validationError,
        'Puan 1 ile 5 arasında olmalı.',
      );
      expect(
        const UserFeedbackInput(rating: 6).validationError,
        'Puan 1 ile 5 arasında olmalı.',
      );
      expect(const UserFeedbackInput(rating: 5).validationError, isNull);
    });

    test('allows empty message when rating exists', () {
      const input = UserFeedbackInput(rating: 4, message: '');

      expect(input.validationError, isNull);
      expect(input.toInsertJson(userId: 'user-1')['message'], isNull);
    });

    test('enforces message max length', () {
      final input = UserFeedbackInput(message: 'a' * 1001);

      expect(input.validationError, 'Mesaj en fazla 1000 karakter olabilir.');
    });

    test('requires at least one feedback field', () {
      const input = UserFeedbackInput();

      expect(input.validationError, 'Puan, kategori veya mesaj ekle.');
    });
  });

  group('ReviewPromptRules', () {
    test('does not show too often', () {
      final now = DateTime(2026, 6, 4);
      final canShow = ReviewPromptRules.canShow(
        signal: const ReviewPromptSignal(completedOrJoinedEvent: true),
        isFirstLaunch: false,
        now: now,
        lastPromptAt: now.subtract(const Duration(days: 3)),
      );

      expect(canShow, isFalse);
    });

    test('allows positive signal after cooldown', () {
      final now = DateTime(2026, 6, 4);
      final canShow = ReviewPromptRules.canShow(
        signal: const ReviewPromptSignal(highTrustScore: true),
        isFirstLaunch: false,
        now: now,
        lastPromptAt: now.subtract(const Duration(days: 45)),
      );

      expect(canShow, isTrue);
    });

    test('blocks after reports or errors', () {
      final now = DateTime(2026, 6, 4);

      expect(
        ReviewPromptRules.canShow(
          signal: const ReviewPromptSignal(
            completedOrJoinedEvent: true,
            submittedReport: true,
          ),
          isFirstLaunch: false,
          now: now,
        ),
        isFalse,
      );
      expect(
        ReviewPromptRules.canShow(
          signal: const ReviewPromptSignal(
            positiveBusinessReview: true,
            hadRecentError: true,
          ),
          isFirstLaunch: false,
          now: now,
        ),
        isFalse,
      );
    });
  });

  group('feedback error and rate limit', () {
    test('maps feedback errors to friendly copy', () {
      expect(
        friendlyFeedbackErrorMessage('PostgrestException unknown'),
        'Geri bildirim gönderilemedi. Tekrar dene.',
      );
    });

    test('rate limit is five per day', () {
      expect(RateLimitActions.feedbackSubmit, 'feedback_submit');
      expect(RateLimitRules.feedbackSubmitsPerDay, 5);
    });
  });

  group('feedback migration', () {
    test('adds RLS policies for own feedback and admin read', () {
      final migration = File(
        'supabase/migrations/20260604183000_user_feedback_foundation.sql',
      ).readAsStringSync();

      expect(
        migration,
        contains('create table if not exists public.user_feedback'),
      );
      expect(
        migration,
        contains('user_id uuid not null references auth.users'),
      );
      expect(migration, contains('rating is null or rating between 1 and 5'));
      expect(migration, contains('enable row level security'));
      expect(migration, contains('with check (user_id = auth.uid())'));
      expect(migration, contains('using (user_id = auth.uid())'));
      expect(migration, contains('using (public.is_current_user_admin())'));
    });
  });
}
