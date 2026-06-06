import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_a_man/features/settings/legal_info_page.dart';

void main() {
  group('legal pages', () {
    testWidgets('terms page exists with professional MVP draft text', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: LegalInfoPage(type: LegalInfoType.termsOfUse)),
      );

      expect(find.text('Kullanım Şartları'), findsOneWidget);
      expect(
        find.textContaining('aracılık sağlayan bir platform'),
        findsOneWidget,
      );
      expect(find.textContaining('kendi sorumluluğunda'), findsWidgets);
    });

    testWidgets('privacy community and event safety pages exist', (
      tester,
    ) async {
      for (final type in [
        LegalInfoType.privacyPolicy,
        LegalInfoType.communityGuidelines,
        LegalInfoType.eventSafetyDisclaimer,
      ]) {
        await tester.pumpWidget(MaterialApp(home: LegalInfoPage(type: type)));
        await tester.pump();
      }

      expect(
        find.text('Etkinlik Güvenliği ve Sorumluluk Reddi'),
        findsOneWidget,
      );
    });
  });

  group('Turkish language lock', () {
    test('central visible labels use Turkish vocabulary', () {
      final nav = File(
        'lib/core/widgets/main_navigation_shell.dart',
      ).readAsStringSync();
      final settings = File(
        'lib/features/settings/settings_page.dart',
      ).readAsStringSync();
      final reports = File(
        'lib/features/reports/widgets/report_dialog.dart',
      ).readAsStringSync();

      expect(nav, contains("label: 'Etkinlikler'"));
      expect(nav, contains("label: 'Ana sayfa'"));
      expect(settings, contains("title: 'Güven puanı'"));
      expect(reports, contains("Text('Şikayet et'"));
      expect(nav, isNot(contains("label: 'Events'")));
      expect(nav, isNot(contains("label: 'Home'")));
    });
  });

  group('in-app realtime refresh', () {
    test('notifications use debounced realtime with cleanup', () {
      final provider = File(
        'lib/features/notifications/notifications_provider.dart',
      ).readAsStringSync();

      expect(provider, contains('onPostgresChanges'));
      expect(provider, contains('Timer(const Duration(milliseconds: 500)'));
      expect(provider, contains('removeChannel'));
      expect(provider, contains('dispose()'));
    });

    test('comments and business application refresh use realtime safely', () {
      final feedProvider = File(
        'lib/features/feed/feed_provider.dart',
      ).readAsStringSync();
      final businessProvider = File(
        'lib/features/business/business_provider.dart',
      ).readAsStringSync();

      expect(feedProvider, contains('startCommentsRealtime'));
      expect(feedProvider, contains('post_comments'));
      expect(feedProvider, contains('stopCommentsRealtime'));
      expect(businessProvider, contains('startApplicationRealtime'));
      expect(businessProvider, contains('business_applications'));
      expect(businessProvider, contains('stopRealtime'));
    });
  });
}
