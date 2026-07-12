import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_a_man/features/settings/legal_info_page.dart';
import 'package:match_a_man/features/settings/rules_and_agreements_page.dart';

void main() {
  group('legal pages', () {
    testWidgets('terms page exists with professional launch text', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: LegalInfoPage(type: LegalInfoType.termsOfUse)),
      );

      expect(find.text('Akanzi Kullanıcı Sözleşmesi'), findsOneWidget);

      final legalPage = File(
        'lib/features/settings/legal_info_page.dart',
      ).readAsStringSync();

      expect(legalPage, contains('Kullanıcı Sözleşmesi'));
      expect(legalPage, contains('terms_v1_2026_06_10'));
      expect(legalPage, contains('Akanzi'));
      expect(
        legalPage,
        contains('Akanzi bir sosyal spor ve etkinlik platformudur'),
      );
      expect(legalPage, contains('etkinlik'));
      expect(legalPage, contains('platform'));
      expect(legalPage, contains('Topluluk kuralları ve yasak davranışlar'));
      expect(legalPage, contains('Spor ve fiziksel aktivite riskleri'));
      expect(legalPage, contains('Kapalı test ve ödeme durumu'));
      expect(
        legalPage,
        contains('uygulama içi ödeme, cüzdan veya ücretli biletleme'),
      );
      expect(legalPage, contains('flört veya dating uygulaması değildir'));
      expect(legalPage, contains('Önemli değişiklikler'));
      expect(legalPage, contains('değişiklikleri inceleme fırsatı'));
      expect(legalPage, contains('yeniden açık kabul'));
      expect(legalPage, contains('hesap silme talebinde bulunabilir'));
      expect(legalPage, contains('hesabı askıya alabilir'));
      expect(legalPage, isNot(contains('avukat')));
      expect(legalPage, isNot(contains('hukuk görevlisi')));
      expect(legalPage, isNot(contains('legal review pending')));
      expect(legalPage, isNot(contains('hukuki inceleme bekliyor')));
      expect(legalPage, isNot(contains('Dijital Cüzdan')));
      expect(legalPage, isNot(contains('chargeback')));
      expect(legalPage, isNot(contains('premium')));
      expect(legalPage, isNot(contains('hedeflenmiş reklam')));
      expect(legalPage, isNot(contains('targeted ads')));
      expect(legalPage, isNot(contains('veri madenciliği')));
      expect(legalPage, isNot(contains('koşulsuz')));
      expect(legalPage, isNot(contains('geri dönülemez')));
      expect(legalPage, isNot(contains('yayınlandığı anda otomatik kabul')));
      expect(legalPage, isNot(contains('kesinlikle ücret iadesi yapılmaz')));
      expect(legalPage, isNot(contains('kesinlikle iade yapılmaz')));
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
        find.text('Etkinlik Güvenliği ve Sorumluluk Bilgilendirmesi'),
        findsOneWidget,
      );
    });

    testWidgets('privacy and account deletion copy match MVP data flows', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LegalInfoPage(type: LegalInfoType.privacyPolicy),
        ),
      );

      expect(
        find.text('Akanzi Gizlilik Politikası ve KVKK Aydınlatma Metni'),
        findsOneWidget,
      );

      final legalPage = File(
        'lib/features/settings/legal_info_page.dart',
      ).readAsStringSync();

      expect(legalPage, contains('privacy_v1_2026_06_10'));
      expect(legalPage, contains('kişisel veriler'));
      expect(legalPage, contains('Açık rıza gerektiren ayrı bir işlem'));
      expect(legalPage, isNot(contains('SUPPORT_EMAIL')));
      expect(legalPage, isNot(contains('RESMI_ILETISIM')));
      expect(legalPage, isNot(contains('placeholder')));
      expect(legalPage, isNot(contains('taslağıdır')));
      expect(legalPage, isNot(contains('vehesap')));
      expect(legalPage, isNot(contains('yayın öncesinde belirlenecek')));
      expect(legalPage, contains('Firebase Cloud Messaging cihaz tokenı'));
      expect(legalPage, contains('Supabase Auth'));
      expect(legalPage, contains('Google OAuth'));
      expect(legalPage, contains('OpenStreetMap'));
      expect(
        legalPage,
        contains(
          'uygulama içi ödeme, cüzdan, ücretli abonelik veya reklam sistemi',
        ),
      );
      expect(legalPage, isNot(contains('verileri sınırsız işleriz')));
      expect(
        legalPage,
        isNot(contains('verileri istediğimiz kişiyle paylaşırız')),
      );
      expect(legalPage, isNot(contains('hedefli reklam')));
      expect(legalPage, isNot(contains('ticari veri satışı')));

      await tester.pumpWidget(
        const MaterialApp(home: LegalInfoPage(type: LegalInfoType.support)),
      );

      expect(find.text('Akanzi Hesap Silme Bilgilendirmesi'), findsOneWidget);
      expect(legalPage, contains('account_deletion_v1_2026_06_10'));
      expect(legalPage, contains('Ayarlar > Hesabımı sil'));
      expect(legalPage, contains('anlık fiziksel silme'));
      expect(legalPage, contains('sınırlı süreyle saklanabilir'));
    });

    testWidgets('rules and agreements page lists legal documents', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: RulesAndAgreementsPage()),
      );

      expect(find.text('Kurallar ve sözleşmeler'), findsOneWidget);
      expect(find.text('Kullanıcı Sözleşmesi'), findsOneWidget);
      expect(find.text('Gizlilik Politikası'), findsOneWidget);
      expect(find.text('Topluluk Kuralları'), findsOneWidget);
      expect(find.text('Etkinlik Güvenliği'), findsOneWidget);
      expect(find.text('Hesap ve veri talepleri'), findsOneWidget);
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
      expect(settings, contains("title: 'Kurallar ve sözleşmeler'"));
      expect(settings, contains('RouteNames.rulesAndAgreements'));
      expect(settings, isNot(contains("title: 'Kullanım Şartları'")));
      expect(settings, isNot(contains("title: 'Gizlilik Politikası'")));
      expect(settings, isNot(contains("title: 'Topluluk Kuralları'")));
      expect(
        settings,
        isNot(contains("title: 'Etkinlik Güvenliği ve Sorumluluk Reddi'")),
      );
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
