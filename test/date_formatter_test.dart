import 'package:flutter_test/flutter_test.dart';
import 'package:match_a_man/core/utils/date_formatter.dart';

void main() {
  test('formats Turkish short date with day month year dots', () {
    final date = DateTime(2026, 7, 24);

    expect(DateFormatter.shortDate(date), '24.07.2026');
  });

  test('formats Turkish long date with day first month name', () {
    final date = DateTime(2026, 7, 24);

    expect(DateFormatter.longDate(date), '24 Temmuz 2026');
  });

  test('formats Turkish date time with day month year order', () {
    final date = DateTime(2026, 7, 24, 18, 30);

    expect(DateFormatter.dateTime(date), '24.07.2026 18:30');
    expect(DateFormatter.formatEventDateTime(date), '24.07.2026 18:30');
  });

  test('parses Turkish text date as day month year', () {
    final parsed = DateFormatter.parseTurkishDate('24.07.2026');

    expect(parsed, isNotNull);
    expect(parsed!.day, 24);
    expect(parsed.month, 7);
    expect(parsed.year, 2026);
    expect(DateFormatter.parseTurkishDate('06/12/2026'), isNull);
    expect(DateFormatter.parseTurkishDate('31.02.2026'), isNull);
  });

  test('formats Turkish relative dates correctly', () {
    final now = DateTime.now();

    expect(
      DateFormatter.relativeTime(now.subtract(const Duration(seconds: 10))),
      contains('sn'),
    );
    expect(
      DateFormatter.relativeTime(now.subtract(const Duration(minutes: 5))),
      '5dk',
    );
    expect(
      DateFormatter.relativeTime(now.subtract(const Duration(hours: 3))),
      '3sa',
    );
    expect(
      DateFormatter.relativeTime(now.subtract(const Duration(days: 2))),
      '2g',
    );
    expect(
      DateFormatter.relativeTime(now.subtract(const Duration(days: 10))),
      '1h',
    );
  });
}
