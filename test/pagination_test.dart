import 'package:flutter_test/flutter_test.dart';
import 'package:match_a_man/core/utils/pagination.dart';

void main() {
  group('SupabasePageSizes', () {
    test('uses requested default page sizes', () {
      expect(SupabasePageSizes.feed, 20);
      expect(SupabasePageSizes.events, 20);
      expect(SupabasePageSizes.notifications, 30);
      expect(SupabasePageSizes.comments, 20);
      expect(SupabasePageSizes.followList, 30);
      expect(SupabasePageSizes.adminApplications, 20);
      expect(SupabasePageSizes.gallery, 24);
    });
  });

  group('appendUniqueByKey', () {
    test('appends without duplicates', () {
      final merged = appendUniqueByKey(
        ['a', 'b'],
        ['b', 'c', 'a', 'd'],
        (value) => value,
      );

      expect(merged, ['a', 'b', 'c', 'd']);
    });

    test('keeps empty lists as non-error data', () {
      final merged = appendUniqueByKey<String, String>(
        const [],
        const [],
        (value) => value,
      );

      expect(merged, isEmpty);
    });
  });

  group('pageHasMore', () {
    test('detects full pages', () {
      expect(pageHasMore(20, SupabasePageSizes.feed), isTrue);
      expect(pageHasMore(19, SupabasePageSizes.feed), isFalse);
    });

    test('refresh reset can replace accumulated data', () {
      final loaded = appendUniqueByKey(
        ['one', 'two'],
        ['three'],
        (value) => value,
      );
      final refreshed = ['fresh'];

      expect(loaded, ['one', 'two', 'three']);
      expect(refreshed, ['fresh']);
    });
  });
}
