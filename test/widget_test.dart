import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_a_man/bootstrap.dart';
import 'package:match_a_man/core/config/env.dart';
import 'package:match_a_man/core/widgets/app_loader.dart';

void main() {
  testWidgets('Core loader renders', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppLoader()));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Startup failure screen renders friendly copy', (tester) async {
    await tester.pumpWidget(const StartupFailureApp());

    expect(find.text('Uygulama başlatılamadı'), findsOneWidget);
    expect(
      find.text('Yapılandırma eksik. Lütfen geliştiriciyle iletişime geç.'),
      findsOneWidget,
    );
  });

  test('Missing Supabase config fails before startup', () {
    expect(Env.validate, throwsA(isA<StateError>()));
  });
}
