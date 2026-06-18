import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_a_man/bootstrap.dart';
import 'package:match_a_man/core/config/env.dart';
import 'package:match_a_man/core/widgets/app_loader.dart';
import 'package:match_a_man/core/widgets/app_logo.dart';

void main() {
  testWidgets('Core loader renders', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppLoader()));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('AppLogo fits narrow AppBar title constraints', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: const SizedBox(
              width: 72,
              child: AppLogo(size: 32, showText: true),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(AppLogo), findsOneWidget);
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
