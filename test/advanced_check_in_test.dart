import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_a_man/features/events/events_models.dart';

void main() {
  group('Advanced Check-In & Privacy Verification Tests', () {
    test('EventParticipationStatus countsAsFinalParticipant logic is correct', () {
      // For Business Events: confirmed and checked_in count as final participants
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
          status: EventParticipationStatus.planned,
        ),
        isFalse,
      );

      // For Normal Events: planned, attended, confirmed, checked_in count as final
      expect(
        EventParticipationStatus.countsAsFinalParticipant(
          isBusinessEvent: false,
          status: EventParticipationStatus.planned,
        ),
        isTrue,
      );
      expect(
        EventParticipationStatus.countsAsFinalParticipant(
          isBusinessEvent: false,
          status: EventParticipationStatus.attended,
        ),
        isTrue,
      );
      expect(
        EventParticipationStatus.countsAsFinalParticipant(
          isBusinessEvent: false,
          status: EventParticipationStatus.confirmed,
        ),
        isTrue,
      );
      expect(
        EventParticipationStatus.countsAsFinalParticipant(
          isBusinessEvent: false,
          status: EventParticipationStatus.checkedIn,
        ),
        isTrue,
      );
      expect(
        EventParticipationStatus.countsAsFinalParticipant(
          isBusinessEvent: false,
          status: EventParticipationStatus.pending,
        ),
        isFalse,
      );
    });

    test('isBusinessCheckInStatus logic is correct', () {
      expect(
        EventParticipationStatus.isBusinessCheckInStatus(
          EventParticipationStatus.confirmed,
        ),
        isTrue,
      );
      expect(
        EventParticipationStatus.isBusinessCheckInStatus(
          EventParticipationStatus.checkedIn,
        ),
        isTrue,
      );
      expect(
        EventParticipationStatus.isBusinessCheckInStatus(
          EventParticipationStatus.noShow,
        ),
        isTrue,
      );
      expect(
        EventParticipationStatus.isBusinessCheckInStatus(
          EventParticipationStatus.planned,
        ),
        isFalse,
      );
    });

    test('migration file contains verify_and_check_in_participant RPC', () {
      final migrationFile = File(
        'supabase/migrations/20260616010000_advanced_features_schema.sql',
      );
      expect(migrationFile.existsSync(), isTrue);

      final content = migrationFile.readAsStringSync();
      expect(content, contains('verify_and_check_in_participant'));
      expect(content, contains('p_token text'));
      expect(content, contains('attendance_status = \'checked_in\''));
    });

    test(
      'migration file redefines get_event_public_participants with block filtering',
      () {
        final migrationFile = File(
          'supabase/migrations/20260616010000_advanced_features_schema.sql',
        );
        expect(migrationFile.existsSync(), isTrue);

        final content = migrationFile.readAsStringSync();
        expect(
          content,
          contains(
            'CREATE OR REPLACE FUNCTION public.get_event_public_participants',
          ),
        );
        expect(content, contains('public.blocks block_rows'));
        expect(content, contains('block_rows.blocker_id = auth.uid()'));
        expect(
          content,
          contains('block_rows.blocked_id = participant.user_id'),
        );
      },
    );

    test('migration file contains get_host_event_analytics RPC', () {
      final migrationFile = File(
        'supabase/migrations/20260616010000_advanced_features_schema.sql',
      );
      expect(migrationFile.existsSync(), isTrue);

      final content = migrationFile.readAsStringSync();
      expect(
        content,
        contains('CREATE OR REPLACE FUNCTION public.get_host_event_analytics'),
      );
      expect(content, contains('message_count integer'));
      expect(content, contains('checked_in_at timestamptz'));
    });
  });
}
